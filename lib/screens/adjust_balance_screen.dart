import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../utils/constants.dart';

class AdjustBalanceScreen extends ConsumerStatefulWidget {
  final bool isAdd;

  const AdjustBalanceScreen({super.key, required this.isAdd});

  @override
  ConsumerState<AdjustBalanceScreen> createState() => _AdjustBalanceScreenState();
}

class _AdjustBalanceScreenState extends ConsumerState<AdjustBalanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _selectedAccountId;
  bool _loading = false;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (_selectedAccountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an account')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authProvider);
    if (user == null) return;

    setState(() => _loading = true);

    final amount = double.parse(_amountCtrl.text.trim());
    final delta = widget.isAdd ? amount : -amount;

    try {
      await ref.read(transactionsProvider.notifier).addTransaction(
        type: TransactionType.balanceAdjustment,
        customerName: widget.isAdd ? 'Balance Added' : 'Balance Decreased',
        amount: delta,
        balanceAfterTransaction: 0,
        userId: user.id,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        account: _selectedAccountId,
        commission: 0,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.isAdd ? 'Balance added' : 'Balance decreased')),
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

    return Scaffold(
      appBar: AppBar(title: Text(widget.isAdd ? 'Add Balance' : 'Decrease Balance')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Select Account *', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _accountChip('AEPS', Icons.account_balance, 'aeps', theme),
                  ...accounts.map((acc) =>
                    _accountChip(acc.name, Icons.phone_android, acc.id, theme)),
                ],
              ),
              if (_selectedAccountId == null) ...[
                const SizedBox(height: 4),
                Text('Please select an account',
                    style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
              ],
              const SizedBox(height: 24),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount *',
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
                validator: (v) {
                  if (v?.trim().isEmpty ?? true) return 'Amount required';
                  final amt = double.tryParse(v!);
                  if (amt == null || amt <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
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
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isAdd ? Colors.green : Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(widget.isAdd ? 'Add Balance' : 'Decrease Balance'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _accountChip(String label, IconData icon, String accountId, ThemeData theme) {
    final selected = _selectedAccountId == accountId;
    return ChoiceChip(
      avatar: Icon(icon, size: 18),
      label: Text(label),
      selected: selected,
      onSelected: (v) => setState(() => _selectedAccountId = v ? accountId : null),
    );
  }
}
