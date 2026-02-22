import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../database/database.dart';
import '../../providers/tbank_provider.dart';

class TBankTransactionsScreen extends ConsumerWidget {
  const TBankTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final transactions = ref.watch(tBankTransactionsProvider);
    final syncState = ref.watch(tBankNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('T-Bank Transactions'),
        actions: [
          IconButton(
            icon: syncState.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: syncState.isLoading
                ? null
                : () => ref
                    .read(tBankNotifierProvider.notifier)
                    .syncTransactions(),
          ),
        ],
      ),
      body: transactions.when(
        data: (txList) {
          if (txList.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_balance_outlined,
                    size: 64,
                    color:
                        theme.colorScheme.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  const Text('No transactions synced yet'),
                  const SizedBox(height: 8),
                  FilledButton.tonalIcon(
                    onPressed: () => ref
                        .read(tBankNotifierProvider.notifier)
                        .syncTransactions(),
                    icon: const Icon(Icons.sync),
                    label: const Text('Sync Now'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: txList.length,
            itemBuilder: (context, index) {
              final tx = txList[index];
              return _TransactionTile(
                transaction: tx,
                onToggleGarbage: () {
                  if (tx.isGarbage) {
                    // Already garbage, no toggle back for now
                  } else {
                    ref
                        .read(tBankNotifierProvider.notifier)
                        .markAsGarbage(tx.id, 'Manually marked');
                  }
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final TBankTransaction transaction;
  final VoidCallback onToggleGarbage;

  const _TransactionTile({
    required this.transaction,
    required this.onToggleGarbage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isExpense = transaction.amount < 0;
    final isGarbage = transaction.isGarbage;
    final isRecurring = transaction.isRecurringDetected;

    return Opacity(
      opacity: isGarbage ? 0.4 : 1.0,
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: isGarbage
                ? Colors.grey.withOpacity(0.2)
                : isExpense
                    ? Colors.red.withOpacity(0.1)
                    : Colors.green.withOpacity(0.1),
            child: Icon(
              isGarbage
                  ? Icons.delete_outline
                  : isRecurring
                      ? Icons.repeat
                      : isExpense
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
              color: isGarbage
                  ? Colors.grey
                  : isExpense
                      ? Colors.red
                      : Colors.green,
              size: 20,
            ),
          ),
          title: Text(
            transaction.description ?? 'Transaction',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: isGarbage
                ? const TextStyle(decoration: TextDecoration.lineThrough)
                : null,
          ),
          subtitle: Row(
            children: [
              Text(
                DateFormat('d MMM HH:mm')
                    .format(transaction.operationDate),
                style: theme.textTheme.bodySmall,
              ),
              if (transaction.category != null) ...[
                const SizedBox(width: 8),
                Chip(
                  label: Text(
                    transaction.category!,
                    style: const TextStyle(fontSize: 10),
                  ),
                  materialTapTargetSize:
                      MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ],
              if (isGarbage) ...[
                const SizedBox(width: 8),
                const Chip(
                  label: Text('Garbage',
                      style: TextStyle(fontSize: 10)),
                  backgroundColor: Colors.grey,
                  materialTapTargetSize:
                      MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ],
              if (isRecurring && !isGarbage) ...[
                const SizedBox(width: 8),
                Chip(
                  label: const Text('Recurring',
                      style: TextStyle(fontSize: 10)),
                  backgroundColor:
                      theme.colorScheme.tertiary.withOpacity(0.3),
                  materialTapTargetSize:
                      MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                ),
              ],
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isExpense ? '-' : '+'}\u20BD ${transaction.amount.abs().toStringAsFixed(2)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isGarbage
                      ? Colors.grey
                      : isExpense
                          ? Colors.red
                          : Colors.green,
                ),
              ),
              Text(
                transaction.status,
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
          onLongPress: isGarbage ? null : onToggleGarbage,
        ),
      ),
    );
  }
}
