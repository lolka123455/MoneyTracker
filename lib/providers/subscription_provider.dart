import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import 'database_provider.dart';
import 'auth_provider.dart';

final subscriptionsProvider = StreamProvider<List<Subscription>>((ref) {
  final db = ref.watch(databaseProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);
  return db.watchSubscriptionsForUser(userId);
});

final activeSubscriptionsProvider =
    StreamProvider<List<Subscription>>((ref) {
  final db = ref.watch(databaseProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);
  return db.watchActiveSubscriptionsForUser(userId);
});

final subscriptionByIdProvider =
    FutureProvider.family<Subscription?, int>((ref, id) {
  final db = ref.watch(databaseProvider);
  return db.getSubscriptionById(id);
});

final subscriptionNotifierProvider =
    StateNotifierProvider<SubscriptionNotifier, AsyncValue<void>>((ref) {
  return SubscriptionNotifier(ref);
});

class SubscriptionNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  SubscriptionNotifier(this._ref) : super(const AsyncValue.data(null));

  AppDatabase get _db => _ref.read(databaseProvider);
  String? get _userId => _ref.read(currentUserIdProvider);

  Future<void> addSubscription({
    required String name,
    required double amount,
    required String currency,
    required String frequency,
    required DateTime startDate,
    bool notificationsEnabled = false,
    String? notificationTime,
    int? categoryId,
    int? paymentMethodId,
  }) async {
    state = const AsyncValue.loading();
    try {
      final userId = _userId;
      if (userId == null) throw Exception('Not authenticated');

      final nextPayment = _calculateNextPayment(startDate, frequency);

      await _db.insertSubscription(SubscriptionsCompanion(
        name: Value(name),
        amount: Value(amount),
        currency: Value(currency),
        frequency: Value(frequency),
        startDate: Value(startDate),
        nextPaymentDate: Value(nextPayment),
        notificationsEnabled: Value(notificationsEnabled),
        notificationTime: Value(notificationTime),
        categoryId: Value(categoryId),
        paymentMethodId: Value(paymentMethodId),
        userId: Value(userId),
      ));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateSubscription(Subscription subscription) async {
    state = const AsyncValue.loading();
    try {
      await _db.updateSubscription(subscription);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteSubscription(int id) async {
    state = const AsyncValue.loading();
    try {
      await _db.deleteSubscription(id);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleActive(Subscription subscription) async {
    await _db.updateSubscription(
      subscription.copyWith(isActive: !subscription.isActive),
    );
  }

  DateTime _calculateNextPayment(DateTime startDate, String frequency) {
    final now = DateTime.now();
    var next = startDate;
    while (next.isBefore(now)) {
      switch (frequency) {
        case 'daily':
          next = next.add(const Duration(days: 1));
          break;
        case 'weekly':
          next = next.add(const Duration(days: 7));
          break;
        case 'monthly':
          next = DateTime(next.year, next.month + 1, next.day);
          break;
      }
    }
    return next;
  }
}
