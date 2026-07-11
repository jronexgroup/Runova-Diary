import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/commission_config.dart';
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
    final user = ref.watch(authProvider);

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
              onTap: () => _showAepsCommissionDialog(context, user?.id ?? ''),
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
              onTap: () => _showDistributorCommissionDialog(context, user?.id ?? ''),
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
              onTap: () => _showSettlementChargeDialog(context, user?.id ?? ''),
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
                onTap: () => _showAccountCommissionDialog(context, acc.id, acc.name, user?.id ?? ''),
              ),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _showAepsCommissionDialog(BuildContext ctx, String userId) async {
    final config = ref.read(commissionConfigsProvider.notifier).getAepsConfig();
    final withdrawalCtrl = TextEditingController(text: config.cashWithdrawalPerThousand.toString());
    final enquiryCtrl = TextEditingController(text: config.balanceEnquiry.toString());
    final statementCtrl = TextEditingController(text: config.miniStatement.toString());
    final aadhaarCtrl = TextEditingController(text: config.aadhaarPayPerThousand.toString());
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('AEPS Commission'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _commField(withdrawalCtrl, 'Cash Withdrawal (per ₹1,000)'),
                const SizedBox(height: 12),
                _commField(enquiryCtrl, 'Balance Enquiry (flat)'),
                const SizedBox(height: 12),
                _commField(statementCtrl, 'Mini Statement (flat)'),
                const SizedBox(height: 12),
                _commField(aadhaarCtrl, 'Aadhaar Pay (per ₹1,000)'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final newConfig = AepsCommissionConfig(
                cashWithdrawalPerThousand: double.tryParse(withdrawalCtrl.text) ?? 10,
                balanceEnquiry: double.tryParse(enquiryCtrl.text) ?? 0,
                miniStatement: double.tryParse(statementCtrl.text) ?? 0,
                aadhaarPayPerThousand: double.tryParse(aadhaarCtrl.text) ?? 0,
              );
              await ref.read(commissionConfigsProvider.notifier).setAepsConfig(newConfig, userId);
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDistributorCommissionDialog(BuildContext ctx, String userId) async {
    final ranges = ref.read(commissionConfigsProvider.notifier).getDistributorRanges();
    final rangesNotifier = ValueNotifier<List<DistributorRange>>(List.from(ranges));

    await showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Distributor Commission Ranges'),
        content: SizedBox(
          width: double.maxFinite,
          child: ValueListenableBuilder<List<DistributorRange>>(
            valueListenable: rangesNotifier,
            builder: (context, list, _) {
              if (list.isEmpty) {
                return const Center(child: Text('No ranges configured'));
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final r = list[i];
                        return ListTile(
                          dense: true,
                          title: Text('₹${r.min} – ₹${r.max}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('₹${r.commission.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: () => _editDistributorRange(c, rangesNotifier, i),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                onPressed: () {
                                  final updated = List<DistributorRange>.from(rangesNotifier.value);
                                  updated.removeAt(i);
                                  rangesNotifier.value = updated;
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 4),
                  TextButton.icon(
                    onPressed: () => _addDistributorRange(rangesNotifier),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Range'),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await ref.read(commissionConfigsProvider.notifier)
                  .setDistributorRanges(rangesNotifier.value, userId);
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _addDistributorRange(ValueNotifier<List<DistributorRange>> notifier) {
    final updated = List<DistributorRange>.from(notifier.value);
    updated.add(const DistributorRange(min: 0, max: 0, commission: 0));
    notifier.value = updated;
  }

  Future<void> _editDistributorRange(
      BuildContext dialogCtx, ValueNotifier<List<DistributorRange>> notifier, int index) async {
    final range = notifier.value[index];
    final minCtrl = TextEditingController(text: range.min.toString());
    final maxCtrl = TextEditingController(text: range.max.toString());
    final commCtrl = TextEditingController(text: range.commission.toString());
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: dialogCtx,
      builder: (c) => AlertDialog(
        title: const Text('Edit Range'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: minCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Min (₹)', isDense: true),
                      validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward, size: 16),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: maxCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Max (₹)', isDense: true),
                      validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: commCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Commission (₹)', isDense: true),
                validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final updated = List<DistributorRange>.from(notifier.value);
              updated[index] = DistributorRange(
                min: int.tryParse(minCtrl.text) ?? 0,
                max: int.tryParse(maxCtrl.text) ?? 0,
                commission: double.tryParse(commCtrl.text) ?? 0,
              );
              notifier.value = updated;
              Navigator.pop(c);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAccountCommissionDialog(BuildContext ctx, String accountId, String accountName, String userId) async {
    final config = ref.read(commissionConfigsProvider.notifier).getAccountConfig(accountId);
    final cashInCtrl = TextEditingController(text: config.cashInPerThousand.toString());
    final cashOutCtrl = TextEditingController(text: config.cashOutPerThousand.toString());
    final settlementCtrl = TextEditingController(text: config.settlementCharge.toString());
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        title: Text('$accountName Commission'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _commField(cashInCtrl, 'Cash In Commission (per ₹1,000)'),
              const SizedBox(height: 12),
              _commField(cashOutCtrl, 'Cash Out Commission (per ₹1,000)'),
              const SizedBox(height: 12),
              _commField(settlementCtrl, 'Settlement Charge (flat)'),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              final newConfig = CommissionConfig(
                cashInPerThousand: double.tryParse(cashInCtrl.text) ?? 10,
                cashOutPerThousand: double.tryParse(cashOutCtrl.text) ?? 10,
                settlementCharge: double.tryParse(settlementCtrl.text) ?? 5,
              );
              await ref.read(commissionConfigsProvider.notifier).setAccountConfig(accountId, newConfig, userId);
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSettlementChargeDialog(BuildContext ctx, String userId) async {
    final ranges = ref.read(commissionConfigsProvider.notifier).getSettlementRanges();
    final rangesNotifier = ValueNotifier<List<SettlementRange>>(List.from(ranges));

    await showDialog(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Settlement Charge Ranges'),
        content: SizedBox(
          width: double.maxFinite,
          child: ValueListenableBuilder<List<SettlementRange>>(
            valueListenable: rangesNotifier,
            builder: (context, list, _) {
              if (list.isEmpty) {
                return const Center(child: Text('No ranges configured'));
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final r = list[i];
                        return ListTile(
                          dense: true,
                          title: Text('₹${r.min} – ₹${r.max}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('₹${r.charge.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: () => _editSettlementRange(c, rangesNotifier, i),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                onPressed: () {
                                  final updated = List<SettlementRange>.from(rangesNotifier.value);
                                  updated.removeAt(i);
                                  rangesNotifier.value = updated;
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 4),
                  TextButton.icon(
                    onPressed: () => _addSettlementRange(rangesNotifier),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Range'),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await ref.read(commissionConfigsProvider.notifier)
                  .setSettlementRanges(rangesNotifier.value, userId);
              if (c.mounted) Navigator.pop(c);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _addSettlementRange(ValueNotifier<List<SettlementRange>> notifier) {
    final updated = List<SettlementRange>.from(notifier.value);
    updated.add(const SettlementRange(min: 0, max: 0, charge: 0));
    notifier.value = updated;
  }

  Future<void> _editSettlementRange(
      BuildContext dialogCtx, ValueNotifier<List<SettlementRange>> notifier, int index) async {
    final range = notifier.value[index];
    final minCtrl = TextEditingController(text: range.min.toString());
    final maxCtrl = TextEditingController(text: range.max.toString());
    final chargeCtrl = TextEditingController(text: range.charge.toString());
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: dialogCtx,
      builder: (c) => AlertDialog(
        title: const Text('Edit Range'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: minCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Min (₹)', isDense: true),
                      validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(Icons.arrow_forward, size: 16),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: maxCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Max (₹)', isDense: true),
                      validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: chargeCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Charge (₹)', isDense: true),
                validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              final updated = List<SettlementRange>.from(notifier.value);
              updated[index] = SettlementRange(
                min: int.tryParse(minCtrl.text) ?? 0,
                max: int.tryParse(maxCtrl.text) ?? 0,
                charge: double.tryParse(chargeCtrl.text) ?? 0,
              );
              notifier.value = updated;
              Navigator.pop(c);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _commField(TextEditingController ctrl, String label) {
    return TextFormField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.currency_rupee),
      ),
      validator: (v) {
        if (v?.trim().isEmpty ?? true) return 'Required';
        if (double.tryParse(v!) == null) return 'Enter a valid number';
        return null;
      },
    );
  }
}
