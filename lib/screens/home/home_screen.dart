import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../providers/scope_provider.dart';
import '../../providers/statistics_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/tbank_provider.dart';
import '../../providers/currency_provider.dart';
import '../../widgets/scope_card.dart';
import '../../widgets/subscription_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authStateProvider).valueOrNull;
    final scopeDates = ref.watch(currentScopeDatesProvider);
    final scopeCalc = ref.watch(scopeCalculatorProvider);
    final scopeRemaining = ref.watch(currentScopeRemainingProvider);
    final scopeSpending = ref.watch(currentScopeSpendingProvider);
    final activeSubs = ref.watch(activeSubscriptionsProvider);
    final tBankStatus = ref.watch(tBankConnectionStatusProvider);
    final usdRate = ref.watch(usdToRubRateProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hi, ${user?.displayName?.split(' ').first ?? 'there'}',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  DateFormat('d MMMM yyyy').format(DateTime.now()),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ─── Current Scope Card ────────────────────────────
                ScopeCard(
                  label: scopeCalc.getCurrentScopeLabel(),
                  startDate: scopeDates.start,
                  endDate: scopeDates.end,
                  spent: scopeSpending.valueOrNull ?? 0,
                  remaining: scopeRemaining.valueOrNull ?? 0,
                  onTap: () => context.push('/scope'),
                ),
                const SizedBox(height: 16),

                // ─── Quick Actions ─────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.add_circle_outline,
                        label: 'Add Expense',
                        onTap: () => context.push('/expenses/add'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.subscriptions_outlined,
                        label: 'Add Sub',
                        onTap: () => context.push('/subscriptions/add'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickActionCard(
                        icon: Icons.account_balance,
                        label: tBankStatus == TBankConnectionStatus.connected
                            ? 'T-Bank'
                            : 'Connect T-Bank',
                        color: tBankStatus == TBankConnectionStatus.connected
                            ? Colors.green
                            : null,
                        onTap: () => tBankStatus ==
                                TBankConnectionStatus.connected
                            ? context.push('/tbank/transactions')
                            : context.push('/tbank/connect'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ─── USD Rate ──────────────────────────────────────
                usdRate.when(
                  data: (rate) => Card(
                    child: ListTile(
                      leading: Icon(Icons.currency_exchange,
                          color: theme.colorScheme.tertiary),
                      title: const Text('USD/RUB (CBR)'),
                      trailing: Text(
                        '\u20BD ${rate.toStringAsFixed(2)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  loading: () => const Card(
                    child: ListTile(
                      leading: Icon(Icons.currency_exchange),
                      title: Text('Loading exchange rate...'),
                    ),
                  ),
                  error: (e, _) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.error_outline,
                          color: Colors.red),
                      title: const Text('Exchange rate unavailable'),
                      subtitle: Text('$e'),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ─── Active Subscriptions ──────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Active Subscriptions',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/subscriptions'),
                      child: const Text('See all'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                activeSubs.when(
                  data: (subs) {
                    if (subs.isEmpty) {
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Icon(Icons.subscriptions_outlined,
                                  size: 48,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.3)),
                              const SizedBox(height: 8),
                              const Text('No active subscriptions'),
                            ],
                          ),
                        ),
                      );
                    }
                    return Column(
                      children: subs
                          .take(3)
                          .map((sub) => Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 8),
                                child: SubscriptionCard(
                                  subscription: sub,
                                  onTap: () => context.push(
                                      '/subscriptions/edit/${sub.id}'),
                                ),
                              ))
                          .toList(),
                    );
                  },
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error: $e'),
                ),
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon, color: color ?? theme.colorScheme.primary),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
