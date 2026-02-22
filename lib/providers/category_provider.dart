import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database.dart';
import 'database_provider.dart';
import 'auth_provider.dart';

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final db = ref.watch(databaseProvider);
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);
  return db.watchCategoriesForUser(userId);
});

final categoryNotifierProvider =
    StateNotifierProvider<CategoryNotifier, AsyncValue<void>>((ref) {
  return CategoryNotifier(ref);
});

class CategoryNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  CategoryNotifier(this._ref) : super(const AsyncValue.data(null));

  AppDatabase get _db => _ref.read(databaseProvider);
  String? get _userId => _ref.read(currentUserIdProvider);

  Future<void> addCategory({
    required String name,
    String icon = 'category',
    int colorValue = 0xFF6750A4,
  }) async {
    state = const AsyncValue.loading();
    try {
      final userId = _userId;
      if (userId == null) throw Exception('Not authenticated');

      await _db.insertCategory(CategoriesCompanion(
        name: Value(name),
        icon: Value(icon),
        colorValue: Value(colorValue),
        userId: Value(userId),
      ));
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteCategory(int id) async {
    state = const AsyncValue.loading();
    try {
      await _db.deleteCategory(id);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> seedDefaultCategories() async {
    final userId = _userId;
    if (userId == null) return;

    final existing = await _db.getCategoriesForUser(userId);
    if (existing.isNotEmpty) return;

    final defaults = [
      ('Food & Groceries', 'restaurant', 0xFFE57373),
      ('Transport', 'directions_car', 0xFF64B5F6),
      ('Entertainment', 'movie', 0xFFBA68C8),
      ('Shopping', 'shopping_bag', 0xFFFFB74D),
      ('Health', 'local_hospital', 0xFF81C784),
      ('Housing', 'home', 0xFF4DB6AC),
      ('Education', 'school', 0xFF7986CB),
      ('Subscriptions', 'subscriptions', 0xFFF06292),
      ('Other', 'more_horiz', 0xFF90A4AE),
    ];

    for (final (name, icon, color) in defaults) {
      await _db.insertCategory(CategoriesCompanion(
        name: Value(name),
        icon: Value(icon),
        colorValue: Value(color),
        isDefault: const Value(true),
        userId: Value(userId),
      ));
    }
  }
}
