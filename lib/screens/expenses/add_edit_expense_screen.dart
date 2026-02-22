import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/expense_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/payment_method_provider.dart';
import '../../core/constants.dart';

class AddEditExpenseScreen extends ConsumerStatefulWidget {
  final int? expenseId;
  const AddEditExpenseScreen({super.key, this.expenseId});

  @override
  ConsumerState<AddEditExpenseScreen> createState() =>
      _AddEditExpenseScreenState();
}

class _AddEditExpenseScreenState
    extends ConsumerState<AddEditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String _currency = 'RUB';
  DateTime _date = DateTime.now();
  int? _categoryId;
  int? _paymentMethodId;
  bool _isRecurring = false;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    if (widget.expenseId != null) {
      _isEditing = true;
      _loadExpense();
    }
  }

  Future<void> _loadExpense() async {
    final expense =
        await ref.read(expenseByIdProvider(widget.expenseId!).future);
    if (expense != null && mounted) {
      setState(() {
        _nameController.text = expense.name;
        _amountController.text = expense.amount.toStringAsFixed(2);
        _noteController.text = expense.note ?? '';
        _currency = expense.currency;
        _date = expense.date;
        _categoryId = expense.categoryId;
        _paymentMethodId = expense.paymentMethodId;
        _isRecurring = expense.isRecurring;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(expenseNotifierProvider.notifier);

    if (_isEditing) {
      final existing =
          await ref.read(expenseByIdProvider(widget.expenseId!).future);
      if (existing != null) {
        await notifier.updateExpense(existing.copyWith(
          name: _nameController.text.trim(),
          amount: double.parse(_amountController.text),
          currency: _currency,
          date: _date,
          categoryId: Value(_categoryId),
          paymentMethodId: Value(_paymentMethodId),
          note: Value(_noteController.text.isNotEmpty
              ? _noteController.text
              : null),
          isRecurring: _isRecurring,
        ));
      }
    } else {
      await notifier.addExpense(
        name: _nameController.text.trim(),
        amount: double.parse(_amountController.text),
        currency: _currency,
        date: _date,
        categoryId: _categoryId,
        paymentMethodId: _paymentMethodId,
        note: _noteController.text.isNotEmpty
            ? _noteController.text
            : null,
        isRecurring: _isRecurring,
      );
    }

    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(categoriesProvider);
    final paymentMethods = ref.watch(paymentMethodsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Expense' : 'New Expense'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete expense?'),
                    content: const Text('This action cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Delete',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
                if (confirm == true && mounted) {
                  await ref
                      .read(expenseNotifierProvider.notifier)
                      .deleteExpense(widget.expenseId!);
                  if (mounted) context.pop();
                }
              },
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Lunch, Coffee, Taxi',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      hintText: '0.00',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) {
                        return 'Invalid number';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _currency,
                    decoration:
                        const InputDecoration(labelText: 'Currency'),
                    items: AppCurrency.values
                        .map((c) => DropdownMenuItem(
                              value: c.code,
                              child: Text(c.code),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _currency = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Date'),
              subtitle: Text(DateFormat('d MMMM yyyy').format(_date)),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (date != null) setState(() => _date = date);
              },
            ),
            const Divider(),
            categories.when(
              data: (cats) => DropdownButtonFormField<int?>(
                value: _categoryId,
                decoration:
                    const InputDecoration(labelText: 'Category'),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('None')),
                  ...cats.map((c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.name),
                      )),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            paymentMethods.when(
              data: (methods) => DropdownButtonFormField<int?>(
                value: _paymentMethodId,
                decoration:
                    const InputDecoration(labelText: 'Payment Method'),
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('None')),
                  ...methods.map((m) => DropdownMenuItem(
                        value: m.id,
                        child: Text(m.name),
                      )),
                ],
                onChanged: (v) =>
                    setState(() => _paymentMethodId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'Add a note...',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Recurring expense'),
              subtitle: const Text('Marks as a regular payment'),
              value: _isRecurring,
              onChanged: (v) => setState(() => _isRecurring = v),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _save,
              child: Text(_isEditing ? 'Save Changes' : 'Add Expense'),
            ),
          ],
        ),
      ),
    );
  }
}
