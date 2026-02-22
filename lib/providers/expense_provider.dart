import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import 'database_provider.dart';
import 'auth_provider.dart';

final expensesProvider = StreamProvider<List<Expense>>((ref) {
  final db = ref.watch(databaseProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);
  return db.watchExpensesForUser(userId);
});

final expensesInRangeProvider =
    StreamProvider.family<List<Expense>, ({DateTime start, DateTime end})>(
        (ref, range) {
  final db = ref.watch(databaseProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);
  return db.watchExpensesInRange(userId, range.start, range.end);
});

final expenseByIdProvider =
    FutureProvider.family<Expense?, int>((ref, id) {
  final db = ref.watch(databaseProvider);
  return db.getExpenseById(id);
});

final expenseNotifierProvider =
    StateNotifierProvider<ExpenseNotifier, AsyncValue<void>>((ref) {
  return ExpenseNotifier(ref);
});

class ExpenseNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  ExpenseNotifier(this._ref) : super(const AsyncValue.data(null));

  AppDatabase get _db => _ref.read(databaseProvider);
  String? get _userId => _ref.read(currentUserIdProvider);

  Future<void> addExpense({
    required String name,
    required double amount,
    required String currency,
    required DateTime date,
    int? categoryId,
    int? paymentMethodId,
    String? note,
    bool isRecurring = false,
  }) async {
    state = const AsyncValue.loading();
    try {
      final userId = _userId;
      if (userId == null) throw Exception('Not authenticated');

      await _db.insertExpense(ExpensesCompanion(
        name: Value(name),
        amount: Value(amount),
        currency: Value(currency),
        date: Value(date),
        categoryId: Value(categoryId),
        paymentMethodId: Value(paymentMethodId),
        note: Value(note),
        isRecurring: Value(isRecurring),
        userId: Value(userId),
      ));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateExpense(Expense expense) async {
    state = const AsyncValue.loading();
    try {
      await _db.updateExpense(expense);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteExpense(int id) async {
    state = const AsyncValue.loading();
    try {
      await _db.deleteExpense(id);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}
