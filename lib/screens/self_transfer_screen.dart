import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../utils/constants.dart';

class SelfTransferScreen extends ConsumerStatefulWidget {
  const SelfTransferScreen({super.key});

  @override
  ConsumerState<SelfTransferScreen> createState() => _SelfTransferScreenState();
}

class _SelfTransferScreenState extends ConsumerState<SelfTransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _fromAccountId;
  String? _toAccountId;
  bool _loading = false;
  bool _isNEFT = true;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _settlementCharge {
    if (_fromAccountId != 'aeps') return 0;
    final amt = double.tryParse(_amountCtrl.text);
    if (amt == null || amt <= 0) return 0;
    return ref.read(commissionServiceProvider).getSettlementCharge(amt,
        ranges: ref.read(commissionConfigsProvider.notifier).getSettlementRanges());
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (_fromAccountId == null || _toAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select both accounts')),
      );
      return;
    }
    if (_fromAccountId == _toAccountId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Accounts must be different')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authProvider);
    if (user == null) return;

    setState(() => _loading = true);

    final amount = double.parse(_amountCtrl.text.trim());
    final charge = _settlementCharge;
    final accounts = ref.watch(accountsProvider);
    final labelMap = <String, String>{'aeps': 'AEPS'};
    for (final acc in accounts) {
      labelMap[acc.id] = acc.name;
    }

    try {
      await ref.read(transactionsProvider.notifier).addTransaction(
        type: TransactionType.selfTransfer,
        customerName: '${labelMap[_fromAccountId]} → ${labelMap[_toAccountId]}',
        amount: amount,
        balanceAfterTransaction: 0,
        userId: user.id,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        fromAccount: _fromAccountId,
        toAccount: _toAccountId,
        commission: charge,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transfer completed')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accounts = ref.watch(accountsProvider);
    final charge = _settlementCharge;
    final amount = double.tryParse(_amountCtrl.text) ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Self Transfer')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('From Account *', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _accountChip('AEPS', Icons.account_balance, 'aeps', _fromAccountId,
                      (v) => setState(() {
                        _fromAccountId = v;
                        if (_toAccountId == v) _toAccountId = null;
                      })),
                  ...accounts.map((acc) =>
                    _accountChip(acc.name, Icons.phone_android, acc.id, _fromAccountId,
                        (v) => setState(() {
                          _fromAccountId = v;
                          if (_toAccountId == v) _toAccountId = null;
                        }))),
                ],
              ),
              const SizedBox(height: 20),
              Text('To Account *', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _accountChip('AEPS', Icons.account_balance, 'aeps', _toAccountId,
                      (v) => setState(() {
                        _toAccountId = v;
                        if (_fromAccountId == v) _fromAccountId = null;
                      })),
                  ...accounts.map((acc) =>
                    _accountChip(acc.name, Icons.phone_android, acc.id, _toAccountId,
                        (v) => setState(() {
                          _toAccountId = v;
                          if (_fromAccountId == v) _fromAccountId = null;
                        }))),
                ],
              ),
              if (_fromAccountId != null && _toAccountId != null && _fromAccountId == _toAccountId)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('From and To accounts must be different',
                      style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
                ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount *',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v?.trim().isEmpty ?? true) return 'Amount required';
                  final amt = double.tryParse(v!);
                  if (amt == null || amt <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              if (_fromAccountId == 'aeps' && charge > 0) ...[
                const SizedBox(height: 16),
                Card(
                  color: theme.colorScheme.tertiaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Settlement Type: '),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('NEFT'),
                              selected: _isNEFT,
                              onSelected: (v) => setState(() => _isNEFT = v),
                            ),
                            const SizedBox(width: 8),
                            ChoiceChip(
                              label: const Text('IMPS'),
                              selected: !_isNEFT,
                              onSelected: (v) => setState(() => _isNEFT = !v),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Settlement charge: ₹${charge.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onTertiaryContainer,
                          ),
                        ),
                        Text(
                          'AEPS will be debited: ₹${(amount + charge).toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onTertiaryContainer,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Transfer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accountChip(String label, IconData icon, String accountId, String? selectedId, ValueChanged<String?> onSelected) {
    final selected = selectedId == accountId;
    return ChoiceChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      selected: selected,
      onSelected: selected ? null : (v) => onSelected(accountId),
    );
  }
}
