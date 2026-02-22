import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import 'database_provider.dart';
import 'auth_provider.dart';

final paymentMethodsProvider =
    StreamProvider<List<PaymentMethod>>((ref) {
  final db = ref.watch(databaseProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);
  return db.watchPaymentMethodsForUser(userId);
});

final paymentMethodNotifierProvider =
    StateNotifierProvider<PaymentMethodNotifier, AsyncValue<void>>((ref) {
  return PaymentMethodNotifier(ref);
});

class PaymentMethodNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  PaymentMethodNotifier(this._ref) : super(const AsyncValue.data(null));

  AppDatabase get _db => _ref.read(databaseProvider);
  String? get _userId => _ref.read(currentUserIdProvider);

  Future<void> addPaymentMethod({
    required String name,
    String icon = 'payment',
  }) async {
    state = const AsyncValue.loading();
    try {
      final userId = _userId;
      if (userId == null) throw Exception('Not authenticated');

      await _db.insertPaymentMethod(PaymentMethodsCompanion(
        name: Value(name),
        icon: Value(icon),
        userId: Value(userId),
      ));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deletePaymentMethod(int id) async {
    state = const AsyncValue.loading();
    try {
      await _db.deletePaymentMethod(id);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> seedDefaultPaymentMethods() async {
    final userId = _userId;
    if (userId == null) return;

    final existing = await _db.getPaymentMethodsForUser(userId);
    if (existing.isNotEmpty) return;

    final defaults = [
      ('T-Bank Card', 'credit_card'),
      ('Cash', 'payments'),
      ('Bank Transfer', 'account_balance'),
    ];

    for (final (name, icon) in defaults) {
      await _db.insertPaymentMethod(PaymentMethodsCompanion(
        name: Value(name),
        icon: Value(icon),
        isDefault: const Value(true),
        userId: Value(userId),
      ));
    }
  }
}
