import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/tbank_provider.dart';

class TBankConnectScreen extends ConsumerStatefulWidget {
  const TBankConnectScreen({super.key});

  @override
  ConsumerState<TBankConnectScreen> createState() =>
      _TBankConnectScreenState();
}

class _TBankConnectScreenState
    extends ConsumerState<TBankConnectScreen> {
  final _tokenController = TextEditingController();
  bool _isConnecting = false;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) return;

    setState(() => _isConnecting = true);
    try {
      await ref.read(tBankNotifierProvider.notifier).connect(token);

      // Start initial sync
      await ref
          .read(tBankNotifierProvider.notifier)
          .syncTransactions();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('T-Bank connected successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Connection failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = ref.watch(tBankConnectionStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Connect T-Bank')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info card
          Card(
            color: theme.colorScheme.primaryContainer.withOpacity(0.3),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.account_balance,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'T-Bank Integration',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connect your T-Bank account to automatically sync transactions, '
                    'detect recurring payments, and analyze spending patterns.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // How it works
          Text(
            'How it works',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _StepTile(
            number: '1',
            title: 'Get API Token',
            subtitle:
                'Log into developer.tbank.ru and create an access token with accounts:read and transactions:read scopes.',
          ),
          _StepTile(
            number: '2',
            title: 'Enter Token',
            subtitle: 'Paste your access token below.',
          ),
          _StepTile(
            number: '3',
            title: 'Auto Sync',
            subtitle:
                'Transactions will be synced automatically. Garbage transactions (send/receive pairs) are detected and excluded from totals.',
          ),
          const SizedBox(height: 24),

          // Token input
          TextField(
            controller: _tokenController,
            decoration: InputDecoration(
              labelText: 'T-Bank Access Token',
              hintText: 'Paste your token here',
              suffixIcon: IconButton(
                icon: const Icon(Icons.paste),
                onPressed: () {
                  // Clipboard paste would go here
                },
              ),
            ),
            obscureText: true,
            maxLines: 1,
          ),
          const SizedBox(height: 16),

          // Status indicator
          if (status == TBankConnectionStatus.connected)
            Card(
              color: Colors.green.withOpacity(0.1),
              child: const ListTile(
                leading:
                    Icon(Icons.check_circle, color: Colors.green),
                title: Text('Connected'),
                subtitle: Text('T-Bank account is linked'),
              ),
            ),
          if (status == TBankConnectionStatus.error)
            Card(
              color: Colors.red.withOpacity(0.1),
              child: const ListTile(
                leading:
                    Icon(Icons.error_outline, color: Colors.red),
                title: Text('Connection Error'),
                subtitle: Text('Check your token and try again'),
              ),
            ),
          const SizedBox(height: 24),

          // Connect button
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isConnecting ? null : _connect,
              child: _isConnecting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Connect T-Bank'),
            ),
          ),

          if (status == TBankConnectionStatus.connected) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () async {
                await ref
                    .read(tBankNotifierProvider.notifier)
                    .disconnect();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('T-Bank disconnected')),
                  );
                }
              },
              child: const Text('Disconnect'),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final String number;
  final String title;
  final String subtitle;

  const _StepTile({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: theme.colorScheme.primary,
            child: Text(
              number,
              style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface
                          .withOpacity(0.7),
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
