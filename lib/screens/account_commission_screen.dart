import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/commission_config.dart';
import '../providers/providers.dart';

class AccountCommissionScreen extends ConsumerStatefulWidget {
  final String accountId;
  final String accountName;

  const AccountCommissionScreen({
    super.key,
    required this.accountId,
    required this.accountName,
  });

  @override
  ConsumerState<AccountCommissionScreen> createState() => _AccountCommissionScreenState();
}

class _AccountCommissionScreenState extends ConsumerState<AccountCommissionScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _cashInPerThousandCtrl;
  late TextEditingController _cashOutPerThousandCtrl;
  late TextEditingController _settlementCtrl;
  late List<CommissionRange> _cashInRanges;
  late List<CommissionRange> _cashOutRanges;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final config = ref.read(commissionConfigsProvider.notifier).getAccountConfig(widget.accountId);
    _cashInPerThousandCtrl = TextEditingController(text: config.cashInPerThousand.toString());
    _cashOutPerThousandCtrl = TextEditingController(text: config.cashOutPerThousand.toString());
    _settlementCtrl = TextEditingController(text: config.settlementCharge.toString());
    _cashInRanges = List.from(config.cashInRanges);
    _cashOutRanges = List.from(config.cashOutRanges);
  }

  @override
  void dispose() {
    _cashInPerThousandCtrl.dispose();
    _cashOutPerThousandCtrl.dispose();
    _settlementCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_saving) return;
    setState(() => _saving = true);

    final user = ref.read(authProvider);
    if (user == null) return;

    final config = CommissionConfig(
      cashInPerThousand: double.tryParse(_cashInPerThousandCtrl.text) ?? 10,
      cashOutPerThousand: double.tryParse(_cashOutPerThousandCtrl.text) ?? 10,
      cashInRanges: _cashInRanges,
      cashOutRanges: _cashOutRanges,
      settlementCharge: double.tryParse(_settlementCtrl.text) ?? 5,
    );
    await ref.read(commissionConfigsProvider.notifier).setAccountConfig(widget.accountId, config, user.id);
    if (mounted) context.pop();
  }

  void _addRange(bool isCashIn) {
    setState(() {
      if (isCashIn) {
        _cashInRanges.add(const CommissionRange(min: 0, max: 0, rate: 0));
      } else {
        _cashOutRanges.add(const CommissionRange(min: 0, max: 0, rate: 0));
      }
    });
  }

  void _deleteRange(bool isCashIn, int index) {
    setState(() {
      if (isCashIn) {
        _cashInRanges.removeAt(index);
      } else {
        _cashOutRanges.removeAt(index);
      }
    });
  }

  Future<void> _editRange(bool isCashIn, int index) async {
    final ranges = isCashIn ? _cashInRanges : _cashOutRanges;
    final range = ranges[index];
    final minCtrl = TextEditingController(text: range.min.toString());
    final maxCtrl = TextEditingController(text: range.max.toString());
    final rateCtrl = TextEditingController(text: range.rate.toString());
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<bool>(
      context: context,
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
                      decoration: const InputDecoration(labelText: 'Min (\u20B9)', isDense: true),
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
                      decoration: const InputDecoration(labelText: 'Max (\u20B9)', isDense: true),
                      validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: rateCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Rate (\u20B9/\u20B91,000)', isDense: true),
                validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              setState(() {
                final updated = CommissionRange(
                  min: int.tryParse(minCtrl.text) ?? 0,
                  max: int.tryParse(maxCtrl.text) ?? 0,
                  rate: double.tryParse(rateCtrl.text) ?? 0,
                );
                if (isCashIn) {
                  _cashInRanges[index] = updated;
                } else {
                  _cashOutRanges[index] = updated;
                }
              });
              Navigator.pop(c, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      minCtrl.dispose();
      maxCtrl.dispose();
      rateCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('${widget.accountName} Commission')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Flat Rates', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cashInPerThousandCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Cash In Commission (per \u20B91,000)',
                prefixIcon: Icon(Icons.arrow_downward),
              ),
              validator: (v) {
                if (v?.trim().isEmpty ?? true) return 'Required';
                if (double.tryParse(v!) == null) return 'Enter a valid number';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cashOutPerThousandCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Cash Out Commission (per \u20B91,000)',
                prefixIcon: Icon(Icons.arrow_upward),
              ),
              validator: (v) {
                if (v?.trim().isEmpty ?? true) return 'Required';
                if (double.tryParse(v!) == null) return 'Enter a valid number';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _settlementCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Settlement Charge (flat)',
                prefixIcon: Icon(Icons.currency_rupee),
              ),
              validator: (v) {
                if (v?.trim().isEmpty ?? true) return 'Required';
                if (double.tryParse(v!) == null) return 'Enter a valid number';
                return null;
              },
            ),
            const Divider(height: 32),
            Text('Cash In Ranges', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            if (_cashInRanges.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No ranges configured \u2014 using flat rate')))
            else
              ..._cashInRanges.asMap().entries.map((e) => _rangeCard(e.key, e.value, true)),
            TextButton.icon(
              onPressed: () => _addRange(true),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Cash In Range'),
            ),
            const Divider(height: 32),
            Text('Cash Out Ranges', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            if (_cashOutRanges.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No ranges configured \u2014 using flat rate')))
            else
              ..._cashOutRanges.asMap().entries.map((e) => _rangeCard(e.key, e.value, false)),
            TextButton.icon(
              onPressed: () => _addRange(false),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Cash Out Range'),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _rangeCard(int index, CommissionRange range, bool isCashIn) {
    return Card(
      child: ListTile(
        dense: true,
        title: Text('\u20B9${range.min} \u2013 \u20B9${range.max}'),
        subtitle: Text('Rate: \u20B9${range.rate.toStringAsFixed(2)}/\u20B91,000'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () => _editRange(isCashIn, index),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              onPressed: () => _deleteRange(isCashIn, index),
            ),
          ],
        ),
      ),
    );
  }
}
