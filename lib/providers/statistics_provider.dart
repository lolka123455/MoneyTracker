import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import 'expense_provider.dart';
import 'scope_provider.dart';
import 'tbank_provider.dart';
import 'subscription_provider.dart';
import 'currency_provider.dart';

/// Total spending for current scope period
final currentScopeSpendingProvider = FutureProvider<double>((ref) async {
  final scopeDates = ref.watch(currentScopeDatesProvider);
  final expenses = await ref.watch(
    expensesInRangeProvider(
      (start: scopeDates.start, end: scopeDates.end),
    ).future,
  );

  double total = 0;
  for (final expense in expenses) {
    if (expense.currency == 'RUB') {
      total += expense.amount;
    } else {
      final converted = await ref.read(convertedAmountProvider(
        (amount: expense.amount, from: expense.currency, to: 'RUB'),
      ).future);
      total += converted;
    }
  }
  return total;
});

/// Remaining budget for current scope
final currentScopeRemainingProvider = FutureProvider<double>((ref) async {
  final settings = await ref.watch(scopeSettingsProvider.future);
  final spending = await ref.watch(currentScopeSpendingProvider.future);
  final calc = ref.watch(scopeCalculatorProvider);
  final label = calc.getCurrentScopeLabel();

  final income = label == 'Advance'
      ? (settings?.advanceIncome ?? 0)
      : (settings?.salaryIncome ?? 0);

  return income - spending;
});

/// Spending grouped by category for current scope
final spendingByCategoryProvider =
    FutureProvider<Map<String, double>>((ref) async {
  final scopeDates = ref.watch(currentScopeDatesProvider);
  final expenses = await ref.watch(
    expensesInRangeProvider(
      (start: scopeDates.start, end: scopeDates.end),
    ).future,
  );

  final categoryMap = <String, double>{};
  for (final expense in expenses) {
    // Use category ID as key; we'll resolve names in the UI
    final key = expense.categoryId?.toString() ?? 'uncategorized';
    categoryMap[key] = (categoryMap[key] ?? 0) + expense.amount;
  }
  return categoryMap;
});

/// Monthly spending trend (last 6 months)
final monthlySpendingTrendProvider =
    FutureProvider<List<({String month, double amount})>>((ref) async {
  final expenses = await ref.watch(expensesProvider.future);
  final now = DateTime.now();

  final months = <({String month, double amount})>[];
  for (int i = 5; i >= 0; i--) {
    final monthDate = DateTime(now.year, now.month - i, 1);
    final nextMonth = DateTime(now.year, now.month - i + 1, 1);
    final monthLabel =
        '${monthDate.month.toString().padLeft(2, '0')}/${monthDate.year}';

    double total = 0;
    for (final expense in expenses) {
      if (expense.date.isAfter(monthDate) &&
          expense.date.isBefore(nextMonth)) {
        total += expense.amount;
      }
    }
    months.add((month: monthLabel, amount: total));
  }
  return months;
});

/// Daily spending for current scope (for bar chart)
final dailySpendingProvider =
    FutureProvider<List<({DateTime date, double amount})>>((ref) async {
  final scopeDates = ref.watch(currentScopeDatesProvider);
  final expenses = await ref.watch(
    expensesInRangeProvider(
      (start: scopeDates.start, end: scopeDates.end),
    ).future,
  );

  final dailyMap = <DateTime, double>{};
  for (final expense in expenses) {
    final day = DateTime(expense.date.year, expense.date.month, expense.date.day);
    dailyMap[day] = (dailyMap[day] ?? 0) + expense.amount;
  }

  final days = <({DateTime date, double amount})>[];
  var current = scopeDates.start;
  while (!current.isAfter(scopeDates.end)) {
    final day = DateTime(current.year, current.month, current.day);
    days.add((date: day, amount: dailyMap[day] ?? 0));
    current = current.add(const Duration(days: 1));
  }
  return days;
});

/// Total monthly subscriptions cost
final totalSubscriptionsCostProvider =
    FutureProvider<double>((ref) async {
  final subs = await ref.watch(activeSubscriptionsProvider.future);
  double total = 0;
  for (final sub in subs) {
    switch (sub.frequency) {
      case 'daily':
        total += sub.amount * 30;
        break;
      case 'weekly':
        total += sub.amount * 4.33;
        break;
      case 'monthly':
        total += sub.amount;
        break;
    }
  }
  return total;
});

/// T-Bank spending analysis (non-garbage transactions)
final tBankSpendingAnalysisProvider =
    FutureProvider<TBankAnalysis>((ref) async {
  final transactions =
      await ref.watch(tBankNonGarbageTransactionsProvider.future);

  double totalSpent = 0;
  double totalReceived = 0;
  final categorySpending = <String, double>{};
  final recurringTransactions = <TBankTransaction>[];

  for (final tx in transactions) {
    if (tx.amount < 0) {
      totalSpent += tx.amount.abs();
      final cat = tx.category ?? 'Other';
      categorySpending[cat] =
          (categorySpending[cat] ?? 0) + tx.amount.abs();
    } else {
      totalReceived += tx.amount;
    }

    if (tx.isRecurringDetected) {
      recurringTransactions.add(tx);
    }
  }

  return TBankAnalysis(
    totalSpent: totalSpent,
    totalReceived: totalReceived,
    categorySpending: categorySpending,
    recurringTransactions: recurringTransactions,
    transactionCount: transactions.length,
  );
});

class TBankAnalysis {
  final double totalSpent;
  final double totalReceived;
  final Map<String, double> categorySpending;
  final List<TBankTransaction> recurringTransactions;
  final int transactionCount;

  TBankAnalysis({
    required this.totalSpent,
    required this.totalReceived,
    required this.categorySpending,
    required this.recurringTransactions,
    required this.transactionCount,
  });

  double get netFlow => totalReceived - totalSpent;
}
