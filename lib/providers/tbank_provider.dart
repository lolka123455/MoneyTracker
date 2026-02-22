import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import '../services/tbank_service.dart';
import 'database_provider.dart';
import 'auth_provider.dart';

final tBankServiceProvider = Provider<TBankService>((ref) {
  return TBankService(ref.watch(databaseProvider));
});

final tBankConnectionStatusProvider =
    StateProvider<TBankConnectionStatus>((ref) {
  return TBankConnectionStatus.disconnected;
});

final tBankTransactionsProvider =
    StreamProvider<List<TBankTransaction>>((ref) {
  final db = ref.watch(databaseProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);
  return db.watchTBankTransactionsForUser(userId);
});

final tBankNonGarbageTransactionsProvider =
    StreamProvider<List<TBankTransaction>>((ref) {
  final db = ref.watch(databaseProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);
  return db.watchNonGarbageTBankTransactions(userId);
});

final tBankNotifierProvider =
    StateNotifierProvider<TBankNotifier, AsyncValue<void>>((ref) {
  return TBankNotifier(ref);
});

class TBankNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  TBankNotifier(this._ref) : super(const AsyncValue.data(null));

  TBankService get _service => _ref.read(tBankServiceProvider);
  String? get _userId => _ref.read(currentUserIdProvider);

  Future<void> connect(String accessToken) async {
    state = const AsyncValue.loading();
    try {
      _ref.read(tBankConnectionStatusProvider.notifier).state =
          TBankConnectionStatus.connecting;

      await _service.setAccessToken(accessToken);

      _ref.read(tBankConnectionStatusProvider.notifier).state =
          TBankConnectionStatus.connected;

      state = const AsyncValue.data(null);
    } catch (e, st) {
      _ref.read(tBankConnectionStatusProvider.notifier).state =
          TBankConnectionStatus.error;
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> syncTransactions({
    DateTime? from,
    DateTime? to,
  }) async {
    state = const AsyncValue.loading();
    try {
      final userId = _userId;
      if (userId == null) throw Exception('Not authenticated');

      final now = DateTime.now();
      await _service.syncTransactions(
        userId: userId,
        from: from ?? now.subtract(const Duration(days: 30)),
        to: to ?? now,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markAsGarbage(int transactionId, String reason) async {
    final db = _ref.read(databaseProvider);
    await db.markTransactionAsGarbage(transactionId, reason);
  }

  Future<void> disconnect() async {
    await _service.clearAccessToken();
    _ref.read(tBankConnectionStatusProvider.notifier).state =
        TBankConnectionStatus.disconnected;
  }
}

enum TBankConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}
