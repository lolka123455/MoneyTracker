import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import '../database/database.dart';

/// Syncs local Drift database with Firebase Firestore for cross-device sync.
///
/// Strategy: local-first, push changes to Firestore, pull on app start.
/// Each record has a firestoreId to link local ↔ cloud records.
class SyncService {
  final AppDatabase _db;
  final FirebaseFirestore _firestore;

  SyncService(this._db)
      : _firestore = FirebaseFirestore.instance;

  /// Full sync: push local changes, then pull remote changes
  Future<void> fullSync(String userId) async {
    await pushSubscriptions(userId);
    await pushExpenses(userId);
    await pushScopes(userId);
    await pullSubscriptions(userId);
    await pullExpenses(userId);
    await pullScopes(userId);
    await pushCategories(userId);
    await pullCategories(userId);
    await pushPaymentMethods(userId);
    await pullPaymentMethods(userId);
  }

  // ─── Subscriptions Sync ──────────────────────────────────────────────────

  Future<void> pushSubscriptions(String userId) async {
    final localSubs = await _db.getSubscriptionsForUser(userId);
    final collection =
        _firestore.collection('users/$userId/subscriptions');

    for (final sub in localSubs) {
      final data = {
        'name': sub.name,
        'amount': sub.amount,
        'currency': sub.currency,
        'frequency': sub.frequency,
        'startDate': sub.startDate.toIso8601String(),
        'nextPaymentDate': sub.nextPaymentDate?.toIso8601String(),
        'notificationsEnabled': sub.notificationsEnabled,
        'notificationTime': sub.notificationTime,
        'categoryId': sub.categoryId,
        'paymentMethodId': sub.paymentMethodId,
        'isActive': sub.isActive,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (sub.firestoreId != null) {
        await collection.doc(sub.firestoreId).update(data);
      } else {
        final docRef = await collection.add(data);
        // Update local record with Firestore ID
        await _db.updateSubscription(
          sub.copyWith(firestoreId: Value(docRef.id)),
        );
      }
    }
  }

  Future<void> pullSubscriptions(String userId) async {
    final collection =
        _firestore.collection('users/$userId/subscriptions');
    final snapshot = await collection.get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final existingLocal = (await _db.getSubscriptionsForUser(userId))
          .where((s) => s.firestoreId == doc.id)
          .firstOrNull;

      if (existingLocal == null) {
        await _db.insertSubscription(SubscriptionsCompanion(
          name: Value(data['name'] as String? ?? ''),
          amount: Value((data['amount'] as num?)?.toDouble() ?? 0),
          currency: Value(data['currency'] as String? ?? 'RUB'),
          frequency: Value(data['frequency'] as String? ?? 'monthly'),
          startDate: Value(
            DateTime.tryParse(data['startDate'] as String? ?? '') ??
                DateTime.now(),
          ),
          nextPaymentDate: Value(
            DateTime.tryParse(data['nextPaymentDate'] as String? ?? ''),
          ),
          notificationsEnabled:
              Value(data['notificationsEnabled'] as bool? ?? false),
          notificationTime:
              Value(data['notificationTime'] as String?),
          categoryId: Value(data['categoryId'] as int?),
          paymentMethodId: Value(data['paymentMethodId'] as int?),
          isActive: Value(data['isActive'] as bool? ?? true),
          userId: Value(userId),
          firestoreId: Value(doc.id),
        ));
      }
    }
  }

  // ─── Expenses Sync ───────────────────────────────────────────────────────

  Future<void> pushExpenses(String userId) async {
    final localExpenses = await _db.getExpensesForUser(userId);
    final collection =
        _firestore.collection('users/$userId/expenses');

    for (final expense in localExpenses) {
      final data = {
        'name': expense.name,
        'amount': expense.amount,
        'currency': expense.currency,
        'date': expense.date.toIso8601String(),
        'categoryId': expense.categoryId,
        'paymentMethodId': expense.paymentMethodId,
        'note': expense.note,
        'isRecurring': expense.isRecurring,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (expense.firestoreId != null) {
        await collection.doc(expense.firestoreId).update(data);
      } else {
        final docRef = await collection.add(data);
        await _db.updateExpense(
          expense.copyWith(firestoreId: Value(docRef.id)),
        );
      }
    }
  }

  Future<void> pullExpenses(String userId) async {
    final collection =
        _firestore.collection('users/$userId/expenses');
    final snapshot = await collection.get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final existingLocal = (await _db.getExpensesForUser(userId))
          .where((e) => e.firestoreId == doc.id)
          .firstOrNull;

      if (existingLocal == null) {
        await _db.insertExpense(ExpensesCompanion(
          name: Value(data['name'] as String? ?? ''),
          amount: Value((data['amount'] as num?)?.toDouble() ?? 0),
          currency: Value(data['currency'] as String? ?? 'RUB'),
          date: Value(
            DateTime.tryParse(data['date'] as String? ?? '') ??
                DateTime.now(),
          ),
          categoryId: Value(data['categoryId'] as int?),
          paymentMethodId: Value(data['paymentMethodId'] as int?),
          note: Value(data['note'] as String?),
          isRecurring: Value(data['isRecurring'] as bool? ?? false),
          userId: Value(userId),
          firestoreId: Value(doc.id),
        ));
      }
    }
  }

  // ─── Budget Scopes Sync ──────────────────────────────────────────────────

  Future<void> pushScopes(String userId) async {
    final localScopes = await _db.getScopesForUser(userId);
    final collection =
        _firestore.collection('users/$userId/scopes');

    for (final scope in localScopes) {
      final data = {
        'startDate': scope.startDate.toIso8601String(),
        'endDate': scope.endDate.toIso8601String(),
        'income': scope.income,
        'label': scope.label,
        'currency': scope.currency,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (scope.firestoreId != null) {
        await collection.doc(scope.firestoreId).update(data);
      } else {
        final docRef = await collection.add(data);
        await _db.updateScope(
          scope.copyWith(firestoreId: Value(docRef.id)),
        );
      }
    }
  }

  Future<void> pullScopes(String userId) async {
    final collection =
        _firestore.collection('users/$userId/scopes');
    final snapshot = await collection.get();

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final existingLocal = (await _db.getScopesForUser(userId))
          .where((s) => s.firestoreId == doc.id)
          .firstOrNull;

      if (existingLocal == null) {
        await _db.insertScope(BudgetScopesCompanion(
          startDate: Value(
            DateTime.tryParse(data['startDate'] as String? ?? '') ??
                DateTime.now(),
          ),
          endDate: Value(
            DateTime.tryParse(data['endDate'] as String? ?? '') ??
                DateTime.now(),
          ),
          income: Value((data['income'] as num?)?.toDouble() ?? 0),
          label: Value(data['label'] as String? ?? ''),
          currency: Value(data['currency'] as String? ?? 'RUB'),
          userId: Value(userId),
          firestoreId: Value(doc.id),
        ));
      }
    }
  }

  // ─── Categories Sync ─────────────────────────────────────────────────────

  Future<void> pushCategories(String userId) async {
    final categories = await _db.getCategoriesForUser(userId);
    final collection =
        _firestore.collection('users/$userId/categories');

    for (final cat in categories) {
      await collection.doc('cat_${cat.id}').set({
        'name': cat.name,
        'icon': cat.icon,
        'colorValue': cat.colorValue,
        'isDefault': cat.isDefault,
      }, SetOptions(merge: true));
    }
  }

  Future<void> pullCategories(String userId) async {
    // Categories are synced by push — pull is handled on first setup
  }

  // ─── Payment Methods Sync ────────────────────────────────────────────────

  Future<void> pushPaymentMethods(String userId) async {
    final methods = await _db.getPaymentMethodsForUser(userId);
    final collection =
        _firestore.collection('users/$userId/payment_methods');

    for (final method in methods) {
      await collection.doc('pm_${method.id}').set({
        'name': method.name,
        'icon': method.icon,
        'isDefault': method.isDefault,
      }, SetOptions(merge: true));
    }
  }

  Future<void> pullPaymentMethods(String userId) async {
    // Payment methods are synced by push
  }
}
