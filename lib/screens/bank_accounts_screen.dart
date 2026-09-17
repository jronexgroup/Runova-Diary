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
    final phonePeAccounts = accounts.where((a) => a.isPhonePe).toList();
    final aepsAccounts = accounts.where((a) => a.isAeps).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          if (accounts.length < 10)
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
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (aepsAccounts.isNotEmpty) ...[
                  Text('AEPS Accounts', style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  )),
                  const SizedBox(height: 8),
                  ...aepsAccounts.asMap().entries.map((entry) {
                    final i = accounts.indexOf(entry.value);
                    final acc = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Icon(Icons.fingerprint, color: theme.colorScheme.primary),
                        ),
                        title: Text(acc.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                        subtitle: Text(acc.bankName),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, size: 20),
                              onPressed: () => _showAccountDialog(context, i, user?.id ?? '', existing: acc),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                              onPressed: () => _confirmDelete(context, i, user?.id ?? ''),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],
                if (phonePeAccounts.isNotEmpty) ...[
                  Text('PhonePe Accounts', style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  )),
                  const SizedBox(height: 8),
                  ...phonePeAccounts.asMap().entries.map((entry) {
                    final i = accounts.indexOf(entry.value);
                    final acc = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.shade100,
                          child: const Icon(Icons.phone_android, color: Colors.blue),
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
                              onPressed: () => _confirmDelete(context, i, user?.id ?? ''),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
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
    AccountType selectedType = existing?.accountType ?? AccountType.phonePe;

    await showDialog(
      context: ctx,
      builder: (c) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing != null ? 'Edit Account' : 'Add Account'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<AccountType>(
                    segments: const [
                      ButtonSegment<AccountType>(
                        value: AccountType.phonePe,
                        label: Text('PhonePe'),
                        icon: Icon(Icons.phone_android),
                      ),
                      ButtonSegment<AccountType>(
                        value: AccountType.aeps,
                        label: Text('AEPS'),
                        icon: Icon(Icons.fingerprint),
                      ),
                    ],
                    selected: {selectedType},
                    onSelectionChanged: (Set<AccountType> selected) {
                      setDialogState(() => selectedType = selected.first);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: 'Account Name *',
                      prefixIcon: const Icon(Icons.label),
                      hintText: selectedType == AccountType.aeps ? 'e.g., AEPS - India Post' : null,
                    ),
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
                    decoration: InputDecoration(
                      labelText: selectedType == AccountType.aeps ? 'Bank Name *' : 'Bank Name *',
                      prefixIcon: const Icon(Icons.account_balance),
                    ),
                    validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                  ),
                  if (selectedType == AccountType.phonePe) ...[
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
                  upiId: selectedType == AccountType.phonePe ? (upiCtrl.text.trim().isEmpty ? null : upiCtrl.text.trim()) : null,
                  accountNumber: selectedType == AccountType.phonePe ? (acctCtrl.text.trim().isEmpty ? null : acctCtrl.text.trim()) : null,
                  lastFourDigits: selectedType == AccountType.phonePe ? (last4Ctrl.text.trim().isEmpty ? null : last4Ctrl.text.trim()) : null,
                  accountType: selectedType,
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
      ),
    );
  }
}
