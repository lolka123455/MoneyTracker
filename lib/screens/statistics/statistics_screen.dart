import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../providers/statistics_provider.dart';
import '../../providers/scope_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/tbank_provider.dart';

class StatisticsScreen extends ConsumerWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Statistics'),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ─── Monthly Spending Trend ────────────────────────
                _SectionTitle(title: 'Monthly Spending Trend'),
                const SizedBox(height: 8),
                _MonthlyTrendChart(),
                const SizedBox(height: 24),

                // ─── Category Breakdown (Pie Chart) ────────────────
                _SectionTitle(title: 'Spending by Category'),
                const SizedBox(height: 8),
                _CategoryPieChart(),
                const SizedBox(height: 24),

                // ─── Daily Spending Bar Chart ──────────────────────
                _SectionTitle(title: 'Daily Spending (Current Scope)'),
                const SizedBox(height: 8),
                _DailyBarChart(),
                const SizedBox(height: 24),

                // ─── T-Bank Analysis ───────────────────────────────
                _SectionTitle(title: 'T-Bank Analysis'),
                const SizedBox(height: 8),
                _TBankAnalysisSection(),
                const SizedBox(height: 24),

                // ─── Scope Comparison ──────────────────────────────
                _SectionTitle(title: 'Scope Summary'),
                const SizedBox(height: 8),
                _ScopeSummary(),
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

// ─── Monthly Trend Line Chart ───────────────────────────────────────────────

class _MonthlyTrendChart extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final trendData = ref.watch(monthlySpendingTrendProvider);

    return trendData.when(
      data: (months) {
        if (months.isEmpty || months.every((m) => m.amount == 0)) {
          return _EmptyChart(message: 'No spending data yet');
        }

        final maxY = months.map((m) => m.amount).reduce(
                (a, b) => a > b ? a : b) *
            1.2;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: theme.colorScheme.surfaceContainerHighest,
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) => Text(
                          '${(value / 1000).toStringAsFixed(0)}k',
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 && idx < months.length) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                months[idx].month.split('/')[0],
                                style: theme.textTheme.labelSmall,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: (months.length - 1).toDouble(),
                  minY: 0,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: months
                          .asMap()
                          .entries
                          .map((e) =>
                              FlSpot(e.key.toDouble(), e.value.amount))
                          .toList(),
                      isCurved: true,
                      color: theme.colorScheme.primary,
                      barWidth: 3,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, bar, index) =>
                            FlDotCirclePainter(
                          radius: 4,
                          color: theme.colorScheme.primary,
                          strokeColor: theme.colorScheme.surface,
                          strokeWidth: 2,
                        ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: theme.colorScheme.primary.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const _ChartLoading(),
      error: (e, _) => Card(child: Center(child: Text('Error: $e'))),
    );
  }
}

// ─── Category Pie Chart ─────────────────────────────────────────────────────

class _CategoryPieChart extends ConsumerWidget {
  static const _colors = [
    Color(0xFFE57373),
    Color(0xFF64B5F6),
    Color(0xFFBA68C8),
    Color(0xFFFFB74D),
    Color(0xFF81C784),
    Color(0xFF4DB6AC),
    Color(0xFF7986CB),
    Color(0xFFF06292),
    Color(0xFF90A4AE),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final categorySpending = ref.watch(spendingByCategoryProvider);
    final categories = ref.watch(categoriesProvider);

    return categorySpending.when(
      data: (spending) {
        if (spending.isEmpty) {
          return _EmptyChart(message: 'No expenses in this scope');
        }

        final total = spending.values.reduce((a, b) => a + b);
        final entries = spending.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  height: 200,
                  child: PieChart(
                    PieChartData(
                      centerSpaceRadius: 48,
                      sectionsSpace: 2,
                      sections: entries
                          .asMap()
                          .entries
                          .map((e) => PieChartSectionData(
                                value: e.value.value,
                                title:
                                    '${(e.value.value / total * 100).toStringAsFixed(0)}%',
                                color: _colors[
                                    e.key % _colors.length],
                                radius: 50,
                                titleStyle: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Legend
                ...entries.asMap().entries.map((e) {
                  final catName = categories.when(
                    data: (cats) {
                      final id = int.tryParse(e.value.key);
                      if (id != null) {
                        return cats
                                .where((c) => c.id == id)
                                .firstOrNull
                                ?.name ??
                            'Unknown';
                      }
                      return 'Uncategorized';
                    },
                    loading: () => 'Loading...',
                    error: (_, __) => e.value.key,
                  );
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color:
                                _colors[e.key % _colors.length],
                            borderRadius:
                                BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(catName)),
                        Text(
                          '\u20BD ${e.value.value.toStringAsFixed(0)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
      loading: () => const _ChartLoading(),
      error: (e, _) => Card(child: Center(child: Text('Error: $e'))),
    );
  }
}

// ─── Daily Bar Chart ────────────────────────────────────────────────────────

class _DailyBarChart extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dailyData = ref.watch(dailySpendingProvider);

    return dailyData.when(
      data: (days) {
        final nonZeroDays = days.where((d) => d.amount > 0).toList();
        if (nonZeroDays.isEmpty) {
          return _EmptyChart(message: 'No daily spending data');
        }

        final maxY = days.map((d) => d.amount).reduce(
                (a, b) => a > b ? a : b) *
            1.2;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 44,
                        getTitlesWidget: (value, meta) => Text(
                          '${(value / 1000).toStringAsFixed(1)}k',
                          style: theme.textTheme.labelSmall,
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx >= 0 &&
                              idx < days.length &&
                              idx % 2 == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                DateFormat('d')
                                    .format(days[idx].date),
                                style: theme.textTheme.labelSmall,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  maxY: maxY,
                  barGroups: days
                      .asMap()
                      .entries
                      .map((e) => BarChartGroupData(
                            x: e.key,
                            barRods: [
                              BarChartRodData(
                                toY: e.value.amount,
                                color: theme.colorScheme.primary,
                                width: days.length > 14 ? 6 : 12,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ],
                          ))
                      .toList(),
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const _ChartLoading(),
      error: (e, _) => Card(child: Center(child: Text('Error: $e'))),
    );
  }
}

// ─── T-Bank Analysis Section ────────────────────────────────────────────────

class _TBankAnalysisSection extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tBankStatus = ref.watch(tBankConnectionStatusProvider);
    final analysis = ref.watch(tBankSpendingAnalysisProvider);

    if (tBankStatus != TBankConnectionStatus.connected) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.account_balance_outlined,
                  size: 40,
                  color: theme.colorScheme.onSurface.withOpacity(0.3)),
              const SizedBox(height: 8),
              const Text('Connect T-Bank to see transaction analytics'),
            ],
          ),
        ),
      );
    }

    return analysis.when(
      data: (data) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _AnalyticsTile(
                    label: 'Total Spent',
                    value: '\u20BD ${data.totalSpent.toStringAsFixed(0)}',
                    color: Colors.red,
                  ),
                  const SizedBox(width: 16),
                  _AnalyticsTile(
                    label: 'Total Received',
                    value:
                        '\u20BD ${data.totalReceived.toStringAsFixed(0)}',
                    color: Colors.green,
                  ),
                ],
              ),
              const Divider(height: 24),
              Text(
                'T-Bank Categories',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...data.categorySpending.entries
                  .toList()
                  .take(5)
                  .map((e) => Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Text(e.key,
                                style: theme.textTheme.bodySmall),
                            Text(
                              '\u20BD ${e.value.toStringAsFixed(0)}',
                              style:
                                  theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )),
              if (data.recurringTransactions.isNotEmpty) ...[
                const Divider(height: 24),
                Text(
                  'Detected Recurring (${data.recurringTransactions.length})',
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ],
          ),
        ),
      ),
      loading: () => const _ChartLoading(),
      error: (e, _) => Card(child: Center(child: Text('Error: $e'))),
    );
  }
}

class _AnalyticsTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _AnalyticsTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  )),
          Text(value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  )),
        ],
      ),
    );
  }
}

// ─── Scope Summary ──────────────────────────────────────────────────────────

class _ScopeSummary extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final remaining = ref.watch(currentScopeRemainingProvider);
    final spending = ref.watch(currentScopeSpendingProvider);
    final subsCost = ref.watch(totalSubscriptionsCostProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _SummaryRow(
              label: 'Current scope spending',
              value: spending.when(
                data: (s) => '\u20BD ${s.toStringAsFixed(0)}',
                loading: () => '...',
                error: (_, __) => '-',
              ),
            ),
            _SummaryRow(
              label: 'Remaining budget',
              value: remaining.when(
                data: (r) => '\u20BD ${r.toStringAsFixed(0)}',
                loading: () => '...',
                error: (_, __) => '-',
              ),
              valueColor: (remaining.valueOrNull ?? 0) >= 0
                  ? Colors.green
                  : Colors.red,
            ),
            _SummaryRow(
              label: 'Monthly subscriptions',
              value: subsCost.when(
                data: (c) => '\u20BD ${c.toStringAsFixed(0)}',
                loading: () => '...',
                error: (_, __) => '-',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Helpers ────────────────────────────────────────────────────────────────

class _EmptyChart extends StatelessWidget {
  final String message;
  const _EmptyChart({required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        height: 150,
        child: Center(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.5),
                ),
          ),
        ),
      ),
    );
  }
}

class _ChartLoading extends StatelessWidget {
  const _ChartLoading();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
