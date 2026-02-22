import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/expense_provider.dart';
import '../../providers/scope_provider.dart';
import '../../widgets/expense_card.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scopeDates = ref.watch(currentScopeDatesProvider);
    final expenses = ref.watch(
      expensesInRangeProvider(
        (start: scopeDates.start, end: scopeDates.end),
      ),
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Expenses'),
                Text(
                  '${DateFormat('d MMM').format(scopeDates.start)} — ${DateFormat('d MMM').format(scopeDates.end)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          expenses.when(
            data: (expenseList) {
              if (expenseList.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: theme.colorScheme.onSurface
                              .withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No expenses in this scope',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.tonalIcon(
                          onPressed: () => context.push('/expenses/add'),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Expense'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Group by date
              final grouped = <String, List<dynamic>>{};
              for (final expense in expenseList) {
                final key = DateFormat('d MMMM yyyy').format(expense.date);
                grouped.putIfAbsent(key, () => []).add(expense);
              }

              final sortedKeys = grouped.keys.toList();

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final dateKey = sortedKeys[index];
                      final dayExpenses = grouped[dateKey]!;
                      final dayTotal = dayExpenses.fold<double>(
                          0, (sum, e) => sum + e.amount);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  dateKey,
                                  style: theme.textTheme.titleSmall
                                      ?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.6),
                                  ),
                                ),
                                Text(
                                  '\u20BD ${dayTotal.toStringAsFixed(0)}',
                                  style: theme.textTheme.titleSmall
                                      ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...dayExpenses.map((expense) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: ExpenseCard(
                                  expense: expense,
                                  onTap: () => context
                                      .push('/expenses/edit/${expense.id}'),
                                ),
                              )),
                        ],
                      );
                    },
                    childCount: sortedKeys.length,
                  ),
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(child: Text('Error: $e')),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/expenses/add'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
