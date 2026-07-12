import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';

class CommissionSettingsScreen extends ConsumerStatefulWidget {
  const CommissionSettingsScreen({super.key});

  @override
  ConsumerState<CommissionSettingsScreen> createState() => _CommissionSettingsScreenState();
}

class _CommissionSettingsScreenState extends ConsumerState<CommissionSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accounts = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Commission Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.withValues(alpha: 0.2),
                child: const Icon(Icons.account_balance, color: Colors.blue),
              ),
              title: const Text('AEPS Commission'),
              subtitle: const Text('Withdrawal, enquiry, statement, Aadhaar Pay'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/commission-settings/aeps'),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.orange.withValues(alpha: 0.2),
                child: const Icon(Icons.receipt_long, color: Colors.orange),
              ),
              title: const Text('Distributor Commission'),
              subtitle: Text('${ref.watch(commissionConfigsProvider.notifier).getDistributorRanges().length} ranges'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/commission-settings/distributor'),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.teal.withValues(alpha: 0.2),
                child: const Icon(Icons.money_off, color: Colors.teal),
              ),
              title: const Text('Settlement Charge'),
              subtitle: Text('${ref.watch(commissionConfigsProvider.notifier).getSettlementRanges().length} ranges'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/commission-settings/settlement'),
            ),
          ),
          const SizedBox(height: 8),
          ...accounts.asMap().entries.map((entry) {
            final i = entry.key;
            final acc = entry.value;
            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Text('${i + 1}',
                      style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                ),
                title: Text('${acc.name} Commission'),
                subtitle: Text(acc.bankName),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/commission-settings/account/${acc.id}', extra: acc.name),
              ),
            );
          }),
        ],
      ),
    );
  }

}
