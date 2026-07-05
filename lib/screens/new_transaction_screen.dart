import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../utils/constants.dart';
import '../utils/date_utils.dart';

class NewTransactionScreen extends ConsumerStatefulWidget {
  final TransactionType type;

  const NewTransactionScreen({super.key, required this.type});

  @override
  ConsumerState<NewTransactionScreen> createState() => _NewTransactionScreenState();
}

class _NewTransactionScreenState extends ConsumerState<NewTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _amountController = TextEditingController();
  final _mobileController = TextEditingController();
  final _txnIdController = TextEditingController();
  final _notesController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _commissionController = TextEditingController();

  PhonePeAccount? _selectedAccount;
  bool _loading = false;
  bool _overrideCommission = false;

  @override
  void initState() {
    super.initState();
    if (widget.type == TransactionType.aeps) {
      _overrideCommission = false;
    }
  }

  @override
  void dispose() {
    _customerNameController.dispose();
    _amountController.dispose();
    _mobileController.dispose();
    _txnIdController.dispose();
    _notesController.dispose();
    _bankNameController.dispose();
    _commissionController.dispose();
    super.dispose();
  }

  double? get _calculatedCommission {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return null;
    return ref.read(commissionServiceProvider).calculateCommission(amount, widget.type);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(authProvider);
    if (user == null) return;

    setState(() => _loading = true);

    final amount = double.parse(_amountController.text.trim());
    final todayKey = DateTime.now().dateKey;
    final todayBalance = ref.read(balancesProvider)[todayKey];

    double newBalance;
    if (widget.type == TransactionType.aeps) {
      newBalance = (todayBalance?.aepsOpeningBalance ?? 0) + amount;
    } else if (widget.type == TransactionType.cashIn) {
      final currentBal = _selectedAccount == PhonePeAccount.hasibul
          ? (todayBalance?.hasibulClosingBalance ?? todayBalance?.hasibulOpeningBalance ?? 0)
          : (todayBalance?.runaLailaClosingBalance ?? todayBalance?.runaLailaOpeningBalance ?? 0);
      newBalance = currentBal + amount;
    } else {
      final currentBal = _selectedAccount == PhonePeAccount.hasibul
          ? (todayBalance?.hasibulClosingBalance ?? todayBalance?.hasibulOpeningBalance ?? 0)
          : (todayBalance?.runaLailaClosingBalance ?? todayBalance?.runaLailaOpeningBalance ?? 0);
      if (currentBal < amount) {
        if (!mounted) return;
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Insufficient balance')),
        );
        return;
      }
      newBalance = currentBal - amount;
    }

    final commission = _overrideCommission
        ? double.tryParse(_commissionController.text) ?? 0
        : (_calculatedCommission ?? 0);

    try {
      await ref.read(transactionsProvider.notifier).addTransaction(
        type: widget.type,
        customerName: _customerNameController.text.trim(),
        amount: amount,
        balanceAfterTransaction: newBalance,
        userId: user.id,
        mobileNumber: _mobileController.text.trim().isEmpty
            ? null
            : _mobileController.text.trim(),
        transactionId: _txnIdController.text.trim().isEmpty
            ? null
            : _txnIdController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        bankName: _bankNameController.text.trim().isEmpty
            ? null
            : _bankNameController.text.trim(),
        phonePeAccount: _selectedAccount,
        commission: commission,
        commissionOverridden: _overrideCommission,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction recorded')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  String get _title {
    switch (widget.type) {
      case TransactionType.aeps:
        return 'New AEPS Transaction';
      case TransactionType.cashIn:
        return 'Cash In';
      case TransactionType.cashOut:
        return 'Cash Out';
    }
  }

  double? get _newBalance {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return null;

    final todayKey = DateTime.now().dateKey;
    final todayBalance = ref.read(balancesProvider)[todayKey];

    if (widget.type == TransactionType.aeps) {
      return (todayBalance?.aepsClosingBalance ?? todayBalance?.aepsOpeningBalance ?? 0) + amount;
    } else if (widget.type == TransactionType.cashIn) {
      if (_selectedAccount == null) return null;
      final currentBal = _selectedAccount == PhonePeAccount.hasibul
          ? (todayBalance?.hasibulClosingBalance ?? todayBalance?.hasibulOpeningBalance ?? 0)
          : (todayBalance?.runaLailaClosingBalance ?? todayBalance?.runaLailaOpeningBalance ?? 0);
      return currentBal + amount;
    } else {
      if (_selectedAccount == null) return null;
      final currentBal = _selectedAccount == PhonePeAccount.hasibul
          ? (todayBalance?.hasibulClosingBalance ?? todayBalance?.hasibulOpeningBalance ?? 0)
          : (todayBalance?.runaLailaClosingBalance ?? todayBalance?.runaLailaOpeningBalance ?? 0);
      return currentBal - amount;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPhonePe = widget.type == TransactionType.cashIn ||
        widget.type == TransactionType.cashOut;
    final isAEPS = widget.type == TransactionType.aeps;
    final projectedBalance = _newBalance;
    final insufficient = widget.type == TransactionType.cashOut &&
        projectedBalance != null && projectedBalance < 0;

    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _customerNameController,
                decoration: const InputDecoration(
                  labelText: 'Customer Name *',
                  prefixIcon: Icon(Icons.person),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    v?.trim().isEmpty ?? true ? 'Customer name required' : null,
              ),
              const SizedBox(height: 16),
              if (isPhonePe) ...[
                DropdownButtonFormField<PhonePeAccount>(
                  value: _selectedAccount,
                  decoration: const InputDecoration(
                    labelText: 'PhonePe Account *',
                    prefixIcon: Icon(Icons.phone_android),
                  ),
                  items: PhonePeAccount.values.map((a) {
                    return DropdownMenuItem(
                      value: a,
                      child: Text(a.displayName),
                    );
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedAccount = v),
                  validator: (v) => v == null ? 'Select an account' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _bankNameController,
                  decoration: const InputDecoration(
                    labelText: 'Bank Name *',
                    prefixIcon: Icon(Icons.account_balance),
                  ),
                  validator: (v) =>
                      v?.trim().isEmpty ?? true ? 'Bank name required' : null,
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount *',
                  prefixIcon: const Icon(Icons.currency_rupee),
                ),
                validator: (v) {
                  if (v?.trim().isEmpty ?? true) return 'Amount required';
                  final amt = double.tryParse(v!);
                  if (amt == null || amt <= 0) return 'Amount must be greater than 0';
                  return null;
                },
                onChanged: (_) => setState(() {}),
              ),
              if (projectedBalance != null) ...[
                const SizedBox(height: 12),
                Card(
                  color: insufficient ? Colors.red.shade50 : theme.colorScheme.primaryContainer,
                  child: ListTile(
                    leading: Icon(
                      insufficient ? Icons.warning_amber : Icons.account_balance_wallet,
                      color: insufficient ? Colors.red : theme.colorScheme.onPrimaryContainer,
                    ),
                    title: Text(
                      'Balance After Transaction',
                      style: theme.textTheme.bodyMedium,
                    ),
                    trailing: Text(
                      '₹${projectedBalance.toStringAsFixed(0)}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: insufficient ? Colors.red : null,
                      ),
                    ),
                  ),
                ),
              ],
              if (insufficient) ...[
                const SizedBox(height: 4),
                Text(
                  'Insufficient balance!',
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.red),
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Mobile Number (optional)',
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _txnIdController,
                decoration: const InputDecoration(
                  labelText: 'Transaction ID (optional)',
                  prefixIcon: Icon(Icons.receipt),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
              if (isAEPS) ...[
                const SizedBox(height: 16),
                if (_calculatedCommission != null) ...[
                  Card(
                    child: ListTile(
                      leading: Icon(Icons.monetization_on, color: theme.colorScheme.primary),
                      title: const Text('Auto Commission'),
                      trailing: Text(
                        '₹${_calculatedCommission!.toStringAsFixed(0)}',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    title: const Text('Override Commission'),
                    value: _overrideCommission,
                    onChanged: (v) => setState(() => _overrideCommission = v ?? false),
                    controlAffinity: ListTileControlAffinity.trailing,
                  ),
                  if (_overrideCommission) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _commissionController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Commission Amount',
                        prefixIcon: Icon(Icons.monetization_on),
                      ),
                    ),
                  ],
                ],
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: (_loading || insufficient) ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('Save ${widget.type.displayName}'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
