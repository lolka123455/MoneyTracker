import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/statistics_provider.dart';
import '../../widgets/subscription_card.dart';

class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subscriptions = ref.watch(subscriptionsProvider);
    final totalCost = ref.watch(totalSubscriptionsCostProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Subscriptions'),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Monthly total card
                totalCost.when(
                  data: (cost) => Card(
                    color: theme.colorScheme.primaryContainer
                        .withOpacity(0.3),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Monthly Total',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '\u20BD ${cost.toStringAsFixed(0)}',
                                style:
                                    theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Icon(
                            Icons.trending_up,
                            size: 32,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 16),
              ]),
            ),
          ),
          subscriptions.when(
            data: (subs) {
              if (subs.isEmpty) {
                return SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.subscriptions_outlined,
                          size: 64,
                          color: theme.colorScheme.onSurface
                              .withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No subscriptions yet',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.tonalIcon(
                          onPressed: () =>
                              context.push('/subscriptions/add'),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Subscription'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final sub = subs[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SubscriptionCard(
                          subscription: sub,
                          onTap: () => context
                              .push('/subscriptions/edit/${sub.id}'),
                          onDismiss: () => ref
                              .read(subscriptionNotifierProvider.notifier)
                              .deleteSubscription(sub.id),
                        ),
                      );
                    },
                    childCount: subs.length,
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
          // Bottom padding for FAB
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/subscriptions/add'),
        child: const Icon(Icons.add),
      ),
    );
  }
}
