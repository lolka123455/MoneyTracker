import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database.dart';
import '../core/constants.dart';

class SubscriptionCard extends StatelessWidget {
  final Subscription subscription;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  const SubscriptionCard({
    super.key,
    required this.subscription,
    this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencySymbol =
        subscription.currency == 'USD' ? '\$' : '\u20BD';
    final isActive = subscription.isActive;

    Widget card = Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icon
              CircleAvatar(
                backgroundColor: isActive
                    ? theme.colorScheme.primaryContainer
                    : theme.colorScheme.surfaceContainerHighest,
                child: Icon(
                  Icons.subscriptions,
                  color: isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface.withOpacity(0.5),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),

              // Name and frequency
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      subscription.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        decoration: isActive
                            ? null
                            : TextDecoration.lineThrough,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _frequencyLabel(subscription.frequency),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),

              // Amount and next payment
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$currencySymbol${subscription.amount.toStringAsFixed(2)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isActive
                          ? theme.colorScheme.error
                          : theme.colorScheme.onSurface
                              .withOpacity(0.5),
                    ),
                  ),
                  if (subscription.nextPaymentDate != null)
                    Text(
                      'Next: ${DateFormat('d MMM').format(subscription.nextPaymentDate!)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withOpacity(0.5),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (onDismiss != null) {
      card = Dismissible(
        key: ValueKey(subscription.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.delete, color: Colors.red),
        ),
        onDismissed: (_) => onDismiss!(),
        child: card,
      );
    }

    return card;
  }

  String _frequencyLabel(String frequency) {
    switch (frequency) {
      case 'daily':
        return 'Every day';
      case 'weekly':
        return 'Every week';
      case 'monthly':
        return 'Every month';
      default:
        return frequency;
    }
  }
}
