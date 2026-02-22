import 'package:drift/drift.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../database/database.dart';
import '../core/constants.dart';

/// Service for T-Bank Open Banking API integration.
///
/// Uses OAuth 2.0 authorization flow:
/// 1. User authorizes via T-Bank login page
/// 2. App receives access_token
/// 3. Use token to fetch accounts and transactions
///
/// API Reference: https://developer.tbank.ru/
class TBankService {
  final AppDatabase _db;
  final Dio _dio;
  final FlutterSecureStorage _secureStorage;

  String? _accessToken;

  TBankService(this._db)
      : _dio = Dio(BaseOptions(
          baseUrl: AppConstants.tBankBaseUrl,
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        )),
        _secureStorage = const FlutterSecureStorage();

  /// Set access token after OAuth flow
  Future<void> setAccessToken(String token) async {
    _accessToken = token;
    _dio.options.headers['Authorization'] = 'Bearer $token';
    await _secureStorage.write(key: 'tbank_access_token', value: token);
  }

  /// Load saved access token
  Future<bool> loadSavedToken() async {
    final token = await _secureStorage.read(key: 'tbank_access_token');
    if (token != null) {
      _accessToken = token;
      _dio.options.headers['Authorization'] = 'Bearer $token';
      return true;
    }
    return false;
  }

  /// Clear access token (disconnect)
  Future<void> clearAccessToken() async {
    _accessToken = null;
    _dio.options.headers.remove('Authorization');
    await _secureStorage.delete(key: 'tbank_access_token');
  }

  bool get isConnected => _accessToken != null;

  /// Get the OAuth authorization URL for the user to login
  String getAuthorizationUrl({
    required String clientId,
    required String redirectUri,
  }) {
    final params = {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': 'accounts:read transactions:read',
    };
    final uri = Uri.parse(AppConstants.tBankAuthUrl)
        .replace(queryParameters: params);
    return uri.toString();
  }

  /// Exchange authorization code for access token
  Future<String> exchangeCodeForToken({
    required String code,
    required String clientId,
    required String clientSecret,
    required String redirectUri,
  }) async {
    final response = await _dio.post(
      AppConstants.tBankTokenUrl,
      data: {
        'grant_type': 'authorization_code',
        'code': code,
        'client_id': clientId,
        'client_secret': clientSecret,
        'redirect_uri': redirectUri,
      },
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );

    final token = response.data['access_token'] as String;
    await setAccessToken(token);
    return token;
  }

  /// Fetch user's bank accounts
  Future<List<TBankAccount>> getAccounts() async {
    try {
      final response = await _dio.get('/api/v1/accounts');
      final accounts = (response.data['accounts'] as List?)
              ?.map((a) => TBankAccount.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [];
      return accounts;
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch transactions for a specific account
  Future<List<TBankTransactionData>> getTransactions({
    required String accountId,
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final response = await _dio.get(
        '/api/v1/accounts/$accountId/transactions',
        queryParameters: {
          'from': from.toIso8601String(),
          'to': to.toIso8601String(),
        },
      );

      final transactions = (response.data['transactions'] as List?)
              ?.map((t) =>
                  TBankTransactionData.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [];
      return transactions;
    } catch (e) {
      rethrow;
    }
  }

  /// Sync all transactions from T-Bank to local database
  Future<void> syncTransactions({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async {
    final accounts = await getAccounts();

    for (final account in accounts) {
      final transactions = await getTransactions(
        accountId: account.id,
        from: from,
        to: to,
      );

      for (final tx in transactions) {
        await _db.insertTBankTransaction(TBankTransactionsCompanion(
          tbankId: Value(tx.id),
          amount: Value(tx.amount),
          currency: Value(tx.currency),
          description: Value(tx.description),
          category: Value(tx.category),
          operationDate: Value(tx.date),
          status: Value(tx.status),
          accountId: Value(account.id),
          userId: Value(userId),
        ));
      }

      // After inserting, detect garbage and recurring transactions
      await _detectGarbageTransactions(userId);
      await _detectRecurringTransactions(userId);
    }
  }

  /// Detect "garbage" transactions (e.g., sent 100, received 100 back)
  /// These are shown but not counted in totals
  Future<void> _detectGarbageTransactions(String userId) async {
    final transactions =
        await _db.getTBankTransactionsForUser(userId);

    // Group transactions by date
    final byDate = <String, List<TBankTransaction>>{};
    for (final tx in transactions) {
      final dateKey =
          '${tx.operationDate.year}-${tx.operationDate.month}-${tx.operationDate.day}';
      byDate.putIfAbsent(dateKey, () => []).add(tx);
    }

    // Find matching pairs (same amount, opposite signs, same day)
    for (final dayTransactions in byDate.values) {
      for (int i = 0; i < dayTransactions.length; i++) {
        for (int j = i + 1; j < dayTransactions.length; j++) {
          final tx1 = dayTransactions[i];
          final tx2 = dayTransactions[j];

          // Check if they cancel each other out
          if ((tx1.amount + tx2.amount).abs() < 0.01 &&
              tx1.currency == tx2.currency &&
              !tx1.isGarbage &&
              !tx2.isGarbage) {
            await _db.markTransactionAsGarbage(
              tx1.id,
              'Reversed by transaction ${tx2.tbankId}',
            );
            await _db.markTransactionAsGarbage(
              tx2.id,
              'Reversal of transaction ${tx1.tbankId}',
            );
          }
        }
      }
    }
  }

  /// Detect recurring transactions (same amount, same description, on similar dates)
  Future<void> _detectRecurringTransactions(String userId) async {
    final transactions =
        await _db.getTBankTransactionsForUser(userId);

    // Group by description + amount
    final groups = <String, List<TBankTransaction>>{};
    for (final tx in transactions) {
      if (tx.isGarbage) continue;
      final key =
          '${tx.description ?? ""}|${tx.amount.toStringAsFixed(2)}';
      groups.putIfAbsent(key, () => []).add(tx);
    }

    // If a group has 2+ transactions, mark as recurring
    for (final group in groups.values) {
      if (group.length >= 2) {
        for (final tx in group) {
          if (!tx.isRecurringDetected) {
            await (_db.update(_db.tBankTransactions)
                  ..where((t) => t.id.equals(tx.id)))
                .write(const TBankTransactionsCompanion(
              isRecurringDetected: Value(true),
            ));
          }
        }
      }
    }
  }
}

/// Data class for T-Bank account info
class TBankAccount {
  final String id;
  final String name;
  final String currency;
  final double balance;

  TBankAccount({
    required this.id,
    required this.name,
    required this.currency,
    required this.balance,
  });

  factory TBankAccount.fromJson(Map<String, dynamic> json) {
    return TBankAccount(
      id: json['accountId'] as String? ?? '',
      name: json['name'] as String? ?? '',
      currency: json['currency'] as String? ?? 'RUB',
      balance: (json['balance'] as num?)?.toDouble() ?? 0,
    );
  }
}

/// Data class for T-Bank transaction from API
class TBankTransactionData {
  final String id;
  final double amount;
  final String currency;
  final String? description;
  final String? category;
  final DateTime date;
  final String status;

  TBankTransactionData({
    required this.id,
    required this.amount,
    required this.currency,
    this.description,
    this.category,
    required this.date,
    required this.status,
  });

  factory TBankTransactionData.fromJson(Map<String, dynamic> json) {
    return TBankTransactionData(
      id: json['operationId'] as String? ??
          json['id'] as String? ??
          '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'RUB',
      description: json['description'] as String?,
      category: json['category'] as String? ??
          json['mcc']?.toString(),
      date: DateTime.tryParse(json['operationTime'] as String? ?? '') ??
          DateTime.now(),
      status: json['status'] as String? ?? 'OK',
    );
  }
}
