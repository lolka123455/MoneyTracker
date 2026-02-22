import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/subscription_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/payment_method_provider.dart';
import '../../core/constants.dart';

class AddEditSubscriptionScreen extends ConsumerStatefulWidget {
  final int? subscriptionId;
  const AddEditSubscriptionScreen({super.key, this.subscriptionId});

  @override
  ConsumerState<AddEditSubscriptionScreen> createState() =>
      _AddEditSubscriptionScreenState();
}

class _AddEditSubscriptionScreenState
    extends ConsumerState<AddEditSubscriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  String _currency = 'RUB';
  String _frequency = 'monthly';
  DateTime _startDate = DateTime.now();
  bool _notificationsEnabled = false;
  TimeOfDay _notificationTime = const TimeOfDay(hour: 9, minute: 0);
  int? _categoryId;
  int? _paymentMethodId;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    if (widget.subscriptionId != null) {
      _isEditing = true;
      _loadSubscription();
    }
  }

  Future<void> _loadSubscription() async {
    final sub = await ref
        .read(subscriptionByIdProvider(widget.subscriptionId!).future);
    if (sub != null && mounted) {
      setState(() {
        _nameController.text = sub.name;
        _amountController.text = sub.amount.toStringAsFixed(2);
        _currency = sub.currency;
        _frequency = sub.frequency;
        _startDate = sub.startDate;
        _notificationsEnabled = sub.notificationsEnabled;
        if (sub.notificationTime != null) {
          final parts = sub.notificationTime!.split(':');
          _notificationTime = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
        _categoryId = sub.categoryId;
        _paymentMethodId = sub.paymentMethodId;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final notifier = ref.read(subscriptionNotifierProvider.notifier);
    final notifTime = _notificationsEnabled
        ? '${_notificationTime.hour.toString().padLeft(2, '0')}:${_notificationTime.minute.toString().padLeft(2, '0')}'
        : null;

    if (_isEditing) {
      final existing = await ref
          .read(subscriptionByIdProvider(widget.subscriptionId!).future);
      if (existing != null) {
        await notifier.updateSubscription(existing.copyWith(
          name: _nameController.text.trim(),
          amount: double.parse(_amountController.text),
          currency: _currency,
          frequency: _frequency,
          startDate: _startDate,
          notificationsEnabled: _notificationsEnabled,
          notificationTime: Value(notifTime),
          categoryId: Value(_categoryId),
          paymentMethodId: Value(_paymentMethodId),
        ));
      }
    } else {
      await notifier.addSubscription(
        name: _nameController.text.trim(),
        amount: double.parse(_amountController.text),
        currency: _currency,
        frequency: _frequency,
        startDate: _startDate,
        notificationsEnabled: _notificationsEnabled,
        notificationTime: notifTime,
        categoryId: _categoryId,
        paymentMethodId: _paymentMethodId,
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
        title: Text(_isEditing ? 'Edit Subscription' : 'New Subscription'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete subscription?'),
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
                      .read(subscriptionNotifierProvider.notifier)
                      .deleteSubscription(widget.subscriptionId!);
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
            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Netflix, Spotify, Gym',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Amount + Currency
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
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Invalid number';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _currency,
                    decoration: const InputDecoration(labelText: 'Currency'),
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

            // Frequency
            DropdownButtonFormField<String>(
              value: _frequency,
              decoration: const InputDecoration(labelText: 'Frequency'),
              items: PaymentFrequency.values
                  .map((f) => DropdownMenuItem(
                        value: f.name,
                        child: Text(f.label),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _frequency = v!),
            ),
            const SizedBox(height: 16),

            // Start Date
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: const Text('Start Date'),
              subtitle: Text(DateFormat('d MMMM yyyy').format(_startDate)),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (date != null) setState(() => _startDate = date);
              },
            ),
            const Divider(),

            // Category
            categories.when(
              data: (cats) => DropdownButtonFormField<int?>(
                value: _categoryId,
                decoration: const InputDecoration(labelText: 'Category'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('None'),
                  ),
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

            // Payment Method
            paymentMethods.when(
              data: (methods) => DropdownButtonFormField<int?>(
                value: _paymentMethodId,
                decoration:
                    const InputDecoration(labelText: 'Payment Method'),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('None'),
                  ),
                  ...methods.map((m) => DropdownMenuItem(
                        value: m.id,
                        child: Text(m.name),
                      )),
                ],
                onChanged: (v) => setState(() => _paymentMethodId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),

            // Notifications
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Notifications'),
              subtitle: _notificationsEnabled
                  ? Text(
                      'Remind at ${_notificationTime.format(context)}')
                  : const Text('Off'),
              value: _notificationsEnabled,
              onChanged: (v) =>
                  setState(() => _notificationsEnabled = v),
            ),
            if (_notificationsEnabled)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time),
                title: const Text('Notification Time'),
                subtitle: Text(_notificationTime.format(context)),
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: _notificationTime,
                  );
                  if (time != null) {
                    setState(() => _notificationTime = time);
                  }
                },
              ),
            const SizedBox(height: 32),

            // Save button
            FilledButton(
              onPressed: _save,
              child: Text(_isEditing ? 'Save Changes' : 'Add Subscription'),
            ),
          ],
        ),
      ),
    );
  }
}
