import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

// ─── Tables ─────────────────────────────────────────────────────────────────

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get icon => text().withDefault(const Constant('category'))();
  IntColumn get colorValue =>
      integer().withDefault(const Constant(0xFF6750A4))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  TextColumn get userId => text()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class PaymentMethods extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get icon => text().withDefault(const Constant('payment'))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  TextColumn get userId => text()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class Subscriptions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  RealColumn get amount => real()();
  TextColumn get currency =>
      text().withDefault(const Constant('RUB'))();
  TextColumn get frequency =>
      text().withDefault(const Constant('monthly'))(); // daily, weekly, monthly
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get nextPaymentDate => dateTime().nullable()();
  BoolColumn get notificationsEnabled =>
      boolean().withDefault(const Constant(false))();
  TextColumn get notificationTime => text().nullable()(); // HH:mm format
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  IntColumn get paymentMethodId =>
      integer().nullable().references(PaymentMethods, #id)();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get userId => text()();
  TextColumn get firestoreId => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 200)();
  RealColumn get amount => real()();
  TextColumn get currency =>
      text().withDefault(const Constant('RUB'))();
  DateTimeColumn get date => dateTime()();
  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();
  IntColumn get paymentMethodId =>
      integer().nullable().references(PaymentMethods, #id)();
  TextColumn get note => text().nullable()();
  BoolColumn get isRecurring =>
      boolean().withDefault(const Constant(false))();
  TextColumn get userId => text()();
  TextColumn get firestoreId => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class BudgetScopes extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  RealColumn get income => real().withDefault(const Constant(0))();
  TextColumn get label =>
      text().withDefault(const Constant(''))(); // "Advance" or "Salary"
  TextColumn get currency =>
      text().withDefault(const Constant('RUB'))();
  TextColumn get userId => text()();
  TextColumn get firestoreId => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class ScopeSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get scopeDay1 =>
      integer().withDefault(const Constant(13))();
  IntColumn get scopeDay2 =>
      integer().withDefault(const Constant(27))();
  RealColumn get advanceIncome =>
      real().withDefault(const Constant(0))();
  RealColumn get salaryIncome =>
      real().withDefault(const Constant(0))();
  TextColumn get currency =>
      text().withDefault(const Constant('RUB'))();
  TextColumn get userId => text()();
}

class TBankTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get tbankId => text()(); // original T-Bank transaction ID
  RealColumn get amount => real()();
  TextColumn get currency =>
      text().withDefault(const Constant('RUB'))();
  TextColumn get description => text().nullable()();
  TextColumn get category => text().nullable()(); // T-Bank's own category
  DateTimeColumn get operationDate => dateTime()();
  TextColumn get status => text()(); // OK, HOLD, etc.
  TextColumn get accountId => text()();
  BoolColumn get isGarbage =>
      boolean().withDefault(const Constant(false))();
  TextColumn get garbageReason => text().nullable()();
  BoolColumn get isRecurringDetected =>
      boolean().withDefault(const Constant(false))();
  IntColumn get linkedCategoryId =>
      integer().nullable().references(Categories, #id)();
  TextColumn get userId => text()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class CurrencyRates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get fromCurrency => text()();
  TextColumn get toCurrency => text()();
  RealColumn get rate => real()();
  TextColumn get source =>
      text().withDefault(const Constant('CBR'))();
  DateTimeColumn get fetchedAt =>
      dateTime().withDefault(currentDateAndTime)();
}

// ─── Database ───────────────────────────────────────────────────────────────

@DriftDatabase(tables: [
  Categories,
  PaymentMethods,
  Subscriptions,
  Expenses,
  BudgetScopes,
  ScopeSettings,
  TBankTransactions,
  CurrencyRates,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'money_tracker');
  }

  // ─── Categories DAO ──────────────────────────────────────────────────────

  Future<List<Category>> getCategoriesForUser(String userId) =>
      (select(categories)..where((c) => c.userId.equals(userId))).get();

  Stream<List<Category>> watchCategoriesForUser(String userId) =>
      (select(categories)..where((c) => c.userId.equals(userId))).watch();

  Future<int> insertCategory(CategoriesCompanion entry) =>
      into(categories).insert(entry);

  Future<bool> updateCategory(Category entry) =>
      update(categories).replace(entry);

  Future<int> deleteCategory(int id) =>
      (delete(categories)..where((c) => c.id.equals(id))).go();

  // ─── Payment Methods DAO ─────────────────────────────────────────────────

  Future<List<PaymentMethod>> getPaymentMethodsForUser(String userId) =>
      (select(paymentMethods)..where((p) => p.userId.equals(userId))).get();

  Stream<List<PaymentMethod>> watchPaymentMethodsForUser(String userId) =>
      (select(paymentMethods)..where((p) => p.userId.equals(userId))).watch();

  Future<int> insertPaymentMethod(PaymentMethodsCompanion entry) =>
      into(paymentMethods).insert(entry);

  Future<bool> updatePaymentMethod(PaymentMethod entry) =>
      update(paymentMethods).replace(entry);

  Future<int> deletePaymentMethod(int id) =>
      (delete(paymentMethods)..where((p) => p.id.equals(id))).go();

  // ─── Subscriptions DAO ───────────────────────────────────────────────────

  Future<List<Subscription>> getSubscriptionsForUser(String userId) =>
      (select(subscriptions)..where((s) => s.userId.equals(userId))).get();

  Stream<List<Subscription>> watchSubscriptionsForUser(String userId) =>
      (select(subscriptions)..where((s) => s.userId.equals(userId))).watch();

  Stream<List<Subscription>> watchActiveSubscriptionsForUser(
          String userId) =>
      (select(subscriptions)
            ..where(
                (s) => s.userId.equals(userId) & s.isActive.equals(true)))
          .watch();

  Future<Subscription?> getSubscriptionById(int id) =>
      (select(subscriptions)..where((s) => s.id.equals(id)))
          .getSingleOrNull();

  Future<int> insertSubscription(SubscriptionsCompanion entry) =>
      into(subscriptions).insert(entry);

  Future<bool> updateSubscription(Subscription entry) =>
      update(subscriptions).replace(entry);

  Future<int> deleteSubscription(int id) =>
      (delete(subscriptions)..where((s) => s.id.equals(id))).go();

  // ─── Expenses DAO ────────────────────────────────────────────────────────

  Future<List<Expense>> getExpensesForUser(String userId) =>
      (select(expenses)
            ..where((e) => e.userId.equals(userId))
            ..orderBy([(e) => OrderingTerm.desc(e.date)]))
          .get();

  Stream<List<Expense>> watchExpensesForUser(String userId) =>
      (select(expenses)
            ..where((e) => e.userId.equals(userId))
            ..orderBy([(e) => OrderingTerm.desc(e.date)]))
          .watch();

  Future<List<Expense>> getExpensesInRange(
      String userId, DateTime start, DateTime end) =>
      (select(expenses)
            ..where((e) =>
                e.userId.equals(userId) &
                e.date.isBiggerOrEqualValue(start) &
                e.date.isSmallerOrEqualValue(end))
            ..orderBy([(e) => OrderingTerm.desc(e.date)]))
          .get();

  Stream<List<Expense>> watchExpensesInRange(
      String userId, DateTime start, DateTime end) =>
      (select(expenses)
            ..where((e) =>
                e.userId.equals(userId) &
                e.date.isBiggerOrEqualValue(start) &
                e.date.isSmallerOrEqualValue(end))
            ..orderBy([(e) => OrderingTerm.desc(e.date)]))
          .watch();

  Future<Expense?> getExpenseById(int id) =>
      (select(expenses)..where((e) => e.id.equals(id))).getSingleOrNull();

  Future<int> insertExpense(ExpensesCompanion entry) =>
      into(expenses).insert(entry);

  Future<bool> updateExpense(Expense entry) =>
      update(expenses).replace(entry);

  Future<int> deleteExpense(int id) =>
      (delete(expenses)..where((e) => e.id.equals(id))).go();

  // ─── Budget Scopes DAO ───────────────────────────────────────────────────

  Future<List<BudgetScope>> getScopesForUser(String userId) =>
      (select(budgetScopes)
            ..where((s) => s.userId.equals(userId))
            ..orderBy([(s) => OrderingTerm.desc(s.startDate)]))
          .get();

  Stream<List<BudgetScope>> watchScopesForUser(String userId) =>
      (select(budgetScopes)
            ..where((s) => s.userId.equals(userId))
            ..orderBy([(s) => OrderingTerm.desc(s.startDate)]))
          .watch();

  Future<BudgetScope?> getCurrentScope(String userId) {
    final now = DateTime.now();
    return (select(budgetScopes)
          ..where((s) =>
              s.userId.equals(userId) &
              s.startDate.isSmallerOrEqualValue(now) &
              s.endDate.isBiggerOrEqualValue(now)))
        .getSingleOrNull();
  }

  Future<int> insertScope(BudgetScopesCompanion entry) =>
      into(budgetScopes).insert(entry);

  Future<bool> updateScope(BudgetScope entry) =>
      update(budgetScopes).replace(entry);

  // ─── Scope Settings DAO ──────────────────────────────────────────────────

  Future<ScopeSetting?> getScopeSettings(String userId) =>
      (select(scopeSettings)..where((s) => s.userId.equals(userId)))
          .getSingleOrNull();

  Future<int> upsertScopeSettings(ScopeSettingsCompanion entry) =>
      into(scopeSettings).insertOnConflictUpdate(entry);

  // ─── T-Bank Transactions DAO ─────────────────────────────────────────────

  Future<List<TBankTransaction>> getTBankTransactionsForUser(
          String userId) =>
      (select(tBankTransactions)
            ..where((t) => t.userId.equals(userId))
            ..orderBy([(t) => OrderingTerm.desc(t.operationDate)]))
          .get();

  Stream<List<TBankTransaction>> watchTBankTransactionsForUser(
          String userId) =>
      (select(tBankTransactions)
            ..where((t) => t.userId.equals(userId))
            ..orderBy([(t) => OrderingTerm.desc(t.operationDate)]))
          .watch();

  Stream<List<TBankTransaction>> watchNonGarbageTBankTransactions(
          String userId) =>
      (select(tBankTransactions)
            ..where((t) =>
                t.userId.equals(userId) & t.isGarbage.equals(false))
            ..orderBy([(t) => OrderingTerm.desc(t.operationDate)]))
          .watch();

  Future<int> insertTBankTransaction(TBankTransactionsCompanion entry) =>
      into(tBankTransactions).insert(entry,
          mode: InsertMode.insertOrReplace);

  Future<void> markTransactionAsGarbage(
      int id, String reason) async {
    await (update(tBankTransactions)..where((t) => t.id.equals(id)))
        .write(TBankTransactionsCompanion(
      isGarbage: const Value(true),
      garbageReason: Value(reason),
    ));
  }

  // ─── Currency Rates DAO ──────────────────────────────────────────────────

  Future<CurrencyRate?> getLatestRate(
          String from, String to) =>
      (select(currencyRates)
            ..where((r) =>
                r.fromCurrency.equals(from) & r.toCurrency.equals(to))
            ..orderBy([(r) => OrderingTerm.desc(r.fetchedAt)])
            ..limit(1))
          .getSingleOrNull();

  Future<int> insertCurrencyRate(CurrencyRatesCompanion entry) =>
      into(currencyRates).insert(entry);
}
