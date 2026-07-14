import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bank_account.dart';
import '../providers/providers.dart';

class BankAccountsScreen extends ConsumerStatefulWidget {
  const BankAccountsScreen({super.key});

  @override
  ConsumerState<BankAccountsScreen> createState() => _BankAccountsScreenState();
}

class _BankAccountsScreenState extends ConsumerState<BankAccountsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authProvider);
    final accounts = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bank Accounts'),
        actions: [
          if (accounts.length < 5)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showAccountDialog(context, null, user?.id ?? ''),
              tooltip: 'Add Account',
            ),
        ],
      ),
      body: accounts.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.account_balance, size: 64, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(height: 8),
                  Text('No accounts yet', style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showAccountDialog(context, null, user?.id ?? ''),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Account'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: accounts.length,
              itemBuilder: (ctx, i) {
                final acc = accounts[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Text('${i + 1}',
                          style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(acc.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      '${acc.bankName}${acc.holderName.isNotEmpty ? ' • ${acc.holderName}' : ''}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, size: 20),
                          onPressed: () => _showAccountDialog(context, i, user?.id ?? '', existing: acc),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                          onPressed: () => _confirmDelete(ctx, i, user?.id ?? ''),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _confirmDelete(BuildContext ctx, int index, String userId) async {
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text('Transactions for this account will remain, but the account will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(accountsProvider.notifier).deleteAccount(index, userId);
    }
  }

  Future<void> _showAccountDialog(BuildContext ctx, int? index, String userId, {BankAccount? existing}) async {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final holderCtrl = TextEditingController(text: existing?.holderName ?? '');
    final bankCtrl = TextEditingController(text: existing?.bankName ?? '');
    final upiCtrl = TextEditingController(text: existing?.upiId ?? '');
    final acctCtrl = TextEditingController(text: existing?.accountNumber ?? '');
    final last4Ctrl = TextEditingController(text: existing?.lastFourDigits ?? '');
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        title: Text(existing != null ? 'Edit Account' : 'Add Account'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Account Name *', prefixIcon: Icon(Icons.label)),
                  validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: holderCtrl,
                  decoration: const InputDecoration(labelText: 'Account Holder Name', prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: bankCtrl,
                  decoration: const InputDecoration(labelText: 'Bank Name *', prefixIcon: Icon(Icons.account_balance)),
                  validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: upiCtrl,
                  decoration: const InputDecoration(labelText: 'UPI ID (optional)', prefixIcon: Icon(Icons.payment)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: acctCtrl,
                  decoration: const InputDecoration(labelText: 'Account Number (optional)', prefixIcon: Icon(Icons.numbers)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: last4Ctrl,
                  decoration: const InputDecoration(
                    labelText: 'Last 4 Digits (optional)',
                    prefixIcon: Icon(Icons.dialpad),
                    helperText: 'Used by AI to auto-select this account',
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final account = BankAccount.create(
                id: existing?.id,
                name: nameCtrl.text.trim(),
                holderName: holderCtrl.text.trim(),
                bankName: bankCtrl.text.trim(),
                upiId: upiCtrl.text.trim().isEmpty ? null : upiCtrl.text.trim(),
                accountNumber: acctCtrl.text.trim().isEmpty ? null : acctCtrl.text.trim(),
                lastFourDigits: last4Ctrl.text.trim().isEmpty ? null : last4Ctrl.text.trim(),
              );
              if (existing != null && index != null) {
                await ref.read(accountsProvider.notifier).updateAccount(index, account, userId);
              } else {
                await ref.read(accountsProvider.notifier).addAccount(account, userId);
              }
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
