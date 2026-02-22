import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tbank_provider.dart';
import '../../providers/currency_provider.dart';
import '../../providers/scope_provider.dart';
import '../../services/sync_service.dart';
import '../../providers/database_provider.dart';

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref.watch(databaseProvider));
});

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(authStateProvider).valueOrNull;
    final tBankStatus = ref.watch(tBankConnectionStatusProvider);
    final usdRate = ref.watch(usdToRubRateProvider);
    final scopeSettings = ref.watch(scopeSettingsProvider);
    final customRate = ref.watch(customRateProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Settings'),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ─── Account ────────────────────────────────────────
                _SectionHeader(title: 'Account'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundImage: user?.photoURL != null
                              ? NetworkImage(user!.photoURL!)
                              : null,
                          child: user?.photoURL == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(user?.displayName ?? 'User'),
                        subtitle: Text(user?.email ?? ''),
                      ),
                      ListTile(
                        leading: const Icon(Icons.sync),
                        title: const Text('Sync Data'),
                        subtitle: const Text(
                            'Sync with cloud across devices'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          final userId =
                              ref.read(currentUserIdProvider);
                          if (userId == null) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Syncing...')),
                          );

                          try {
                            await ref
                                .read(syncServiceProvider)
                                .fullSync(userId);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                const SnackBar(
                                  content:
                                      Text('Sync completed!'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(
                                SnackBar(
                                  content:
                                      Text('Sync failed: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.logout,
                            color: Colors.red),
                        title: const Text('Sign Out'),
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Sign out?'),
                              content: const Text(
                                  'You can sign in again later.'),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(ctx, true),
                                  child: const Text('Sign Out',
                                      style: TextStyle(
                                          color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await ref
                                .read(authServiceProvider)
                                .signOut();
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ─── Budget Scopes ──────────────────────────────────
                _SectionHeader(title: 'Budget Scopes'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.date_range),
                        title: const Text('Scope Settings'),
                        subtitle: scopeSettings.when(
                          data: (s) => Text(s != null
                              ? 'Days: ${s.scopeDay1} and ${s.scopeDay2}'
                              : 'Default: 13 and 27'),
                          loading: () => const Text('Loading...'),
                          error: (_, __) =>
                              const Text('Not configured'),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/scope'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ─── Currency ───────────────────────────────────────
                _SectionHeader(title: 'Currency'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.currency_exchange),
                        title: const Text('USD/RUB Rate (CBR)'),
                        subtitle: usdRate.when(
                          data: (rate) => Text(
                              '\u20BD ${rate.toStringAsFixed(2)}'),
                          loading: () =>
                              const Text('Loading...'),
                          error: (_, __) =>
                              const Text('Unavailable'),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.refresh),
                          onPressed: () =>
                              ref.invalidate(usdToRubRateProvider),
                        ),
                      ),
                      ListTile(
                        leading: const Icon(Icons.edit),
                        title: const Text('Custom Rate Override'),
                        subtitle: Text(customRate != null
                            ? '\u20BD ${customRate.toStringAsFixed(2)}'
                            : 'Using CBR rate'),
                        onTap: () => _showCustomRateDialog(
                            context, ref),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ─── T-Bank ─────────────────────────────────────────
                _SectionHeader(title: 'T-Bank'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.account_balance,
                          color: tBankStatus ==
                                  TBankConnectionStatus.connected
                              ? Colors.green
                              : null,
                        ),
                        title: const Text('T-Bank Integration'),
                        subtitle: Text(_statusLabel(tBankStatus)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/tbank/connect'),
                      ),
                      if (tBankStatus ==
                          TBankConnectionStatus.connected)
                        ListTile(
                          leading: const Icon(Icons.receipt_long),
                          title: const Text('View Transactions'),
                          trailing:
                              const Icon(Icons.chevron_right),
                          onTap: () =>
                              context.push('/tbank/transactions'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ─── Data ───────────────────────────────────────────
                _SectionHeader(title: 'Data'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.category),
                        title: const Text('Manage Categories'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/categories'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // ─── About ──────────────────────────────────────────
                _SectionHeader(title: 'About'),
                Card(
                  child: const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('MoneyTracker v1.0.0'),
                    subtitle: Text(
                        'Expense tracker with T-Bank integration'),
                  ),
                ),
                const SizedBox(height: 80),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabel(TBankConnectionStatus status) {
    switch (status) {
      case TBankConnectionStatus.connected:
        return 'Connected';
      case TBankConnectionStatus.connecting:
        return 'Connecting...';
      case TBankConnectionStatus.error:
        return 'Error - tap to reconnect';
      case TBankConnectionStatus.disconnected:
        return 'Not connected';
    }
  }

  void _showCustomRateDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController(
      text: ref.read(customRateProvider)?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom USD/RUB Rate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Set a custom exchange rate. Leave empty to use CBR rate.'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Rate (\u20BD per \$1)',
                hintText: 'e.g. 92.50',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(customRateProvider.notifier).state = null;
              Navigator.pop(ctx);
            },
            child: const Text('Use CBR Rate'),
          ),
          FilledButton(
            onPressed: () {
              final rate = double.tryParse(controller.text);
              ref.read(customRateProvider.notifier).state = rate;
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withOpacity(0.6),
            ),
      ),
    );
  }
}
