import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import 'database_provider.dart';
import 'auth_provider.dart';

final scopeSettingsProvider =
    FutureProvider<ScopeSetting?>((ref) {
  final db = ref.watch(databaseProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Future.value(null);
  return db.getScopeSettings(userId);
});

final currentScopeProvider = FutureProvider<BudgetScope?>((ref) {
  final db = ref.watch(databaseProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Future.value(null);
  return db.getCurrentScope(userId);
});

final allScopesProvider = StreamProvider<List<BudgetScope>>((ref) {
  final db = ref.watch(databaseProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);
  return db.watchScopesForUser(userId);
});

/// Calculates current scope boundaries based on user's configured days
class ScopeCalculator {
  final int day1;
  final int day2;

  ScopeCalculator({required this.day1, required this.day2});

  /// Returns (start, end) of the current scope period
  ({DateTime start, DateTime end}) getCurrentScopeDates() {
    final now = DateTime.now();
    final today = now.day;

    final smallDay = day1 < day2 ? day1 : day2;
    final bigDay = day1 < day2 ? day2 : day1;

    DateTime start;
    DateTime end;

    if (today >= smallDay && today < bigDay) {
      // We're in the first scope (smallDay -> bigDay)
      start = DateTime(now.year, now.month, smallDay);
      end = DateTime(now.year, now.month, bigDay)
          .subtract(const Duration(days: 1));
    } else if (today >= bigDay) {
      // We're in the second scope (bigDay -> smallDay of next month)
      start = DateTime(now.year, now.month, bigDay);
      final nextMonth = now.month == 12
          ? DateTime(now.year + 1, 1, smallDay)
          : DateTime(now.year, now.month + 1, smallDay);
      end = nextMonth.subtract(const Duration(days: 1));
    } else {
      // We're before smallDay (in scope from previous month's bigDay)
      final prevMonth = now.month == 1
          ? DateTime(now.year - 1, 12, bigDay)
          : DateTime(now.year, now.month - 1, bigDay);
      start = prevMonth;
      end = DateTime(now.year, now.month, smallDay)
          .subtract(const Duration(days: 1));
    }

    return (start: start, end: end);
  }

  /// Returns label for current scope ("Advance" or "Salary")
  String getCurrentScopeLabel() {
    final now = DateTime.now();
    final today = now.day;
    final smallDay = day1 < day2 ? day1 : day2;
    final bigDay = day1 < day2 ? day2 : day1;

    if (today >= smallDay && today < bigDay) {
      return 'Advance';
    }
    return 'Salary';
  }

  /// Generates scope periods for a given month range
  List<({DateTime start, DateTime end, String label})> generateScopes(
      DateTime from, DateTime to) {
    final scopes = <({DateTime start, DateTime end, String label})>[];
    var current = DateTime(from.year, from.month, 1);

    while (current.isBefore(to)) {
      final smallDay = day1 < day2 ? day1 : day2;
      final bigDay = day1 < day2 ? day2 : day1;

      // First scope of the month
      final scope1Start = DateTime(current.year, current.month, smallDay);
      final scope1End = DateTime(current.year, current.month, bigDay)
          .subtract(const Duration(days: 1));
      if (scope1Start.isBefore(to) && scope1End.isAfter(from)) {
        scopes.add(
            (start: scope1Start, end: scope1End, label: 'Advance'));
      }

      // Second scope spans month boundary
      final scope2Start = DateTime(current.year, current.month, bigDay);
      final nextSmallDay = current.month == 12
          ? DateTime(current.year + 1, 1, smallDay)
          : DateTime(current.year, current.month + 1, smallDay);
      final scope2End = nextSmallDay.subtract(const Duration(days: 1));
      if (scope2Start.isBefore(to) && scope2End.isAfter(from)) {
        scopes.add(
            (start: scope2Start, end: scope2End, label: 'Salary'));
      }

      // Move to next month
      current = current.month == 12
          ? DateTime(current.year + 1, 1, 1)
          : DateTime(current.year, current.month + 1, 1);
    }
    return scopes;
  }
}

final scopeCalculatorProvider = Provider<ScopeCalculator>((ref) {
  final settings = ref.watch(scopeSettingsProvider).valueOrNull;
  return ScopeCalculator(
    day1: settings?.scopeDay1 ?? 13,
    day2: settings?.scopeDay2 ?? 27,
  );
});

final currentScopeDatesProvider =
    Provider<({DateTime start, DateTime end})>((ref) {
  final calc = ref.watch(scopeCalculatorProvider);
  return calc.getCurrentScopeDates();
});

final scopeNotifierProvider =
    StateNotifierProvider<ScopeNotifier, AsyncValue<void>>((ref) {
  return ScopeNotifier(ref);
});

class ScopeNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  ScopeNotifier(this._ref) : super(const AsyncValue.data(null));

  AppDatabase get _db => _ref.read(databaseProvider);
  String? get _userId => _ref.read(currentUserIdProvider);

  Future<void> updateScopeSettings({
    required int day1,
    required int day2,
    required double advanceIncome,
    required double salaryIncome,
    String currency = 'RUB',
  }) async {
    state = const AsyncValue.loading();
    try {
      final userId = _userId;
      if (userId == null) throw Exception('Not authenticated');

      await _db.upsertScopeSettings(ScopeSettingsCompanion(
        scopeDay1: Value(day1),
        scopeDay2: Value(day2),
        advanceIncome: Value(advanceIncome),
        salaryIncome: Value(salaryIncome),
        currency: Value(currency),
        userId: Value(userId),
      ));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createScopeForPeriod({
    required DateTime start,
    required DateTime end,
    required double income,
    required String label,
    String currency = 'RUB',
  }) async {
    final userId = _userId;
    if (userId == null) return;

    await _db.insertScope(BudgetScopesCompanion(
      startDate: Value(start),
      endDate: Value(end),
      income: Value(income),
      label: Value(label),
      currency: Value(currency),
      userId: Value(userId),
    ));
  }
}
