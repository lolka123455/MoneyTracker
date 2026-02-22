import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../providers/scope_provider.dart';
import '../../providers/statistics_provider.dart';

class ScopeScreen extends ConsumerStatefulWidget {
  const ScopeScreen({super.key});

  @override
  ConsumerState<ScopeScreen> createState() => _ScopeScreenState();
}

class _ScopeScreenState extends ConsumerState<ScopeScreen> {
  final _day1Controller = TextEditingController();
  final _day2Controller = TextEditingController();
  final _advanceController = TextEditingController();
  final _salaryController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await ref.read(scopeSettingsProvider.future);
    if (settings != null && mounted) {
      setState(() {
        _day1Controller.text = settings.scopeDay1.toString();
        _day2Controller.text = settings.scopeDay2.toString();
        _advanceController.text = settings.advanceIncome.toStringAsFixed(0);
        _salaryController.text = settings.salaryIncome.toStringAsFixed(0);
      });
    } else {
      _day1Controller.text = '13';
      _day2Controller.text = '27';
    }
  }

  @override
  void dispose() {
    _day1Controller.dispose();
    _day2Controller.dispose();
    _advanceController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final day1 = int.tryParse(_day1Controller.text) ?? 13;
    final day2 = int.tryParse(_day2Controller.text) ?? 27;
    final advance = double.tryParse(_advanceController.text) ?? 0;
    final salary = double.tryParse(_salaryController.text) ?? 0;

    await ref.read(scopeNotifierProvider.notifier).updateScopeSettings(
          day1: day1,
          day2: day2,
          advanceIncome: advance,
          salaryIncome: salary,
        );

    if (mounted) {
      setState(() => _isEditing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Scope settings saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scopeDates = ref.watch(currentScopeDatesProvider);
    final scopeCalc = ref.watch(scopeCalculatorProvider);
    final currentLabel = scopeCalc.getCurrentScopeLabel();
    final remaining = ref.watch(currentScopeRemainingProvider);
    final spending = ref.watch(currentScopeSpendingProvider);
    final settings = ref.watch(scopeSettingsProvider);
    final dailySpending = ref.watch(dailySpendingProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Scopes'),
        actions: [
          IconButton(
            icon: Icon(_isEditing ? Icons.close : Icons.edit),
            onPressed: () => setState(() => _isEditing = !_isEditing),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Current scope info
          Card(
            color: theme.colorScheme.primaryContainer.withOpacity(0.3),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Current Scope: $currentLabel',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Chip(
                        label: Text(
                          '${DateFormat('d MMM').format(scopeDates.start)} — ${DateFormat('d MMM').format(scopeDates.end)}',
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _StatColumn(
                          label: 'Income',
                          value: settings.when(
                            data: (s) {
                              if (s == null) return '\u20BD 0';
                              final income = currentLabel == 'Advance'
                                  ? s.advanceIncome
                                  : s.salaryIncome;
                              return '\u20BD ${income.toStringAsFixed(0)}';
                            },
                            loading: () => '...',
                            error: (_, __) => '-',
                          ),
                          color: Colors.green,
                        ),
                      ),
                      Expanded(
                        child: _StatColumn(
                          label: 'Spent',
                          value: spending.when(
                            data: (s) =>
                                '\u20BD ${s.toStringAsFixed(0)}',
                            loading: () => '...',
                            error: (_, __) => '-',
                          ),
                          color: Colors.red,
                        ),
                      ),
                      Expanded(
                        child: _StatColumn(
                          label: 'Remaining',
                          value: remaining.when(
                            data: (r) =>
                                '\u20BD ${r.toStringAsFixed(0)}',
                            loading: () => '...',
                            error: (_, __) => '-',
                          ),
                          color: (remaining.valueOrNull ?? 0) >= 0
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Progress bar
                  settings.when(
                    data: (s) {
                      if (s == null) return const SizedBox.shrink();
                      final income = currentLabel == 'Advance'
                          ? s.advanceIncome
                          : s.salaryIncome;
                      final spent = spending.valueOrNull ?? 0;
                      final progress =
                          income > 0 ? (spent / income).clamp(0, 1) : 0.0;
                      return Column(
                        children: [
                          LinearProgressIndicator(
                            value: progress.toDouble(),
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                            color: progress > 0.9
                                ? Colors.red
                                : progress > 0.7
                                    ? Colors.orange
                                    : theme.colorScheme.primary,
                            minHeight: 8,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(progress * 100).toStringAsFixed(0)}% of budget used',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      );
                    },
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Daily spending breakdown
          Text(
            'Daily Spending',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          dailySpending.when(
            data: (days) {
              if (days.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No data for this scope'),
                  ),
                );
              }
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: days.where((d) => d.amount > 0).map((d) {
                      final maxAmount = days
                          .map((e) => e.amount)
                          .reduce((a, b) => a > b ? a : b);
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 48,
                              child: Text(
                                DateFormat('d MMM').format(d.date),
                                style: theme.textTheme.labelSmall,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: LinearProgressIndicator(
                                value: maxAmount > 0
                                    ? d.amount / maxAmount
                                    : 0,
                                backgroundColor: theme.colorScheme
                                    .surfaceContainerHighest,
                                minHeight: 12,
                                borderRadius:
                                    BorderRadius.circular(6),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 70,
                              child: Text(
                                '\u20BD ${d.amount.toStringAsFixed(0)}',
                                style: theme.textTheme.labelSmall
                                    ?.copyWith(
                                        fontWeight: FontWeight.bold),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 24),

          // Settings section
          if (_isEditing) ...[
            Text(
              'Scope Settings',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _day1Controller,
                            decoration: const InputDecoration(
                              labelText: 'Scope Day 1',
                              hintText: 'e.g. 13',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _day2Controller,
                            decoration: const InputDecoration(
                              labelText: 'Scope Day 2',
                              hintText: 'e.g. 27',
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _advanceController,
                      decoration: const InputDecoration(
                        labelText: 'Advance Income (\u20BD)',
                        hintText: 'Income for first scope',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _salaryController,
                      decoration: const InputDecoration(
                        labelText: 'Salary Income (\u20BD)',
                        hintText: 'Income for second scope',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _saveSettings,
                        child: const Text('Save Settings'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
