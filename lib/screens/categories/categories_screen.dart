import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/category_provider.dart';
import '../../providers/payment_method_provider.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() =>
      _CategoriesScreenState();
}

class _CategoriesScreenState
    extends ConsumerState<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories & Payment Methods'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Categories'),
            Tab(text: 'Payment Methods'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _CategoriesTab(),
          _PaymentMethodsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 0) {
            _showAddCategoryDialog(context);
          } else {
            _showAddPaymentMethodDialog(context);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    final nameController = TextEditingController();
    int selectedColor = 0xFF6750A4;

    final colors = [
      0xFFE57373,
      0xFF64B5F6,
      0xFFBA68C8,
      0xFFFFB74D,
      0xFF81C784,
      0xFF4DB6AC,
      0xFF7986CB,
      0xFFF06292,
      0xFF90A4AE,
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('New Category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  hintText: 'e.g. Restaurants',
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: colors.map((color) {
                  return GestureDetector(
                    onTap: () =>
                        setDialogState(() => selectedColor = color),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: selectedColor == color
                            ? Border.all(
                                color: Colors.white, width: 3)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  ref
                      .read(categoryNotifierProvider.notifier)
                      .addCategory(
                        name: nameController.text.trim(),
                        colorValue: selectedColor,
                      );
                  Navigator.pop(ctx);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPaymentMethodDialog(BuildContext context) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Payment Method'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'e.g. Sber Card',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                ref
                    .read(paymentMethodNotifierProvider.notifier)
                    .addPaymentMethod(
                      name: nameController.text.trim(),
                    );
                Navigator.pop(ctx);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _CategoriesTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(categoriesProvider);

    return categories.when(
      data: (cats) {
        if (cats.isEmpty) {
          return const Center(child: Text('No categories'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: cats.length,
          itemBuilder: (context, index) {
            final cat = cats[index];
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Color(cat.colorValue),
                  child: const Icon(Icons.category,
                      color: Colors.white, size: 18),
                ),
                title: Text(cat.name),
                subtitle: cat.isDefault
                    ? const Text('Default')
                    : null,
                trailing: cat.isDefault
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red),
                        onPressed: () => ref
                            .read(categoryNotifierProvider.notifier)
                            .deleteCategory(cat.id),
                      ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _PaymentMethodsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methods = ref.watch(paymentMethodsProvider);

    return methods.when(
      data: (list) {
        if (list.isEmpty) {
          return const Center(child: Text('No payment methods'));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: list.length,
          itemBuilder: (context, index) {
            final method = list[index];
            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.payment),
                ),
                title: Text(method.name),
                subtitle: method.isDefault
                    ? const Text('Default')
                    : null,
                trailing: method.isDefault
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.red),
                        onPressed: () => ref
                            .read(
                                paymentMethodNotifierProvider.notifier)
                            .deletePaymentMethod(method.id),
                      ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}
