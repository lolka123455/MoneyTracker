import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ScopeCard extends StatelessWidget {
  final String label;
  final DateTime startDate;
  final DateTime endDate;
  final double spent;
  final double remaining;
  final VoidCallback? onTap;

  const ScopeCard({
    super.key,
    required this.label,
    required this.startDate,
    required this.endDate,
    required this.spent,
    required this.remaining,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalBudget = spent + remaining;
    final progress = totalBudget > 0 ? (spent / totalBudget).clamp(0.0, 1.0) : 0.0;
    final daysLeft = endDate.difference(DateTime.now()).inDays;

    return Card(
      color: theme.colorScheme.primaryContainer.withOpacity(0.2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_view_week,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Chip(
                    label: Text(
                      '$daysLeft days left',
                      style: const TextStyle(fontSize: 11),
                    ),
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${DateFormat('d MMM').format(startDate)} — ${DateFormat('d MMM').format(endDate)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Spent',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withOpacity(0.6),
                          ),
                        ),
                        Text(
                          '\u20BD ${spent.toStringAsFixed(0)}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade300,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Remaining',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withOpacity(0.6),
                          ),
                        ),
                        Text(
                          '\u20BD ${remaining.toStringAsFixed(0)}',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: remaining >= 0
                                ? Colors.green.shade300
                                : Colors.red.shade300,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor:
                      theme.colorScheme.surfaceContainerHighest,
                  color: progress > 0.9
                      ? Colors.red
                      : progress > 0.7
                          ? Colors.orange
                          : theme.colorScheme.primary,
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
