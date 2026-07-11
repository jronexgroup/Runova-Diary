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
  final _aadhaarController = TextEditingController();
  final _mobileController = TextEditingController();
  final _txnIdController = TextEditingController();
  final _notesController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _commissionController = TextEditingController();

  String? _selectedAccountId;
  bool _loading = false;
  bool _commissionOverridden = false;
  bool _autoCommission = true;

  @override
  void dispose() {
    _customerNameController.dispose();
    _amountController.dispose();
    _aadhaarController.dispose();
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
    if (!_autoCommission) return null;
    if (widget.type == TransactionType.cashIn || widget.type == TransactionType.cashOut) {
      final (_, commission) = ref.read(commissionServiceProvider).smartDetect(amount);
      return commission;
    }
    return ref.read(commissionServiceProvider).calculateCommission(amount, widget.type);
  }

  bool get _hasDetectedCommission {
    final c = _calculatedCommission;
    return c != null && c > 0;
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
    final distributorComm = widget.type == TransactionType.aeps
        ? ref.read(commissionServiceProvider).getDistributorCommission(amount,
            ranges: ref.read(commissionConfigsProvider.notifier).getDistributorRanges())
        : 0.0;
    if (widget.type == TransactionType.aeps) {
      newBalance = (todayBalance?.aepsOpeningBalance ?? 0) + amount + distributorComm;
    } else if (widget.type == TransactionType.cashIn) {
      final currentBal = todayBalance?.getBalance(_selectedAccountId ?? '') ?? 0;
      newBalance = currentBal + amount;
    } else {
      final currentBal = todayBalance?.getBalance(_selectedAccountId ?? '') ?? 0;
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

    final commission = _commissionOverridden
        ? (double.tryParse(_commissionController.text) ?? 0.0)
        : (_autoCommission ? (_calculatedCommission ?? 0.0) : 0.0);

    try {
      await ref.read(transactionsProvider.notifier).addTransaction(
        type: widget.type,
        customerName: _customerNameController.text.trim(),
        amount: amount,
        balanceAfterTransaction: newBalance,
        userId: user.id,
        mobileNumber: _mobileController.text.trim().isEmpty
            ? null : _mobileController.text.trim(),
        aadhaarNumber: _aadhaarController.text.trim().isEmpty
            ? null : _aadhaarController.text.trim(),
        transactionId: _txnIdController.text.trim().isEmpty
            ? null : _txnIdController.text.trim(),
        notes: _notesController.text.trim().isEmpty
            ? null : _notesController.text.trim(),
        bankName: _bankNameController.text.trim().isEmpty
            ? null : _bankNameController.text.trim(),
        phonePeAccount: null,
        account: _selectedAccountId,
        commission: commission,
        commissionOverridden: _commissionOverridden,
        distributorCommission: distributorComm,
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
      case TransactionType.balanceAdjustment:
        return 'Balance Adjustment';
      case TransactionType.selfTransfer:
        return 'Self Transfer';
    }
  }

  double? get _newBalance {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return null;

    final todayKey = DateTime.now().dateKey;
    final todayBalance = ref.read(balancesProvider)[todayKey];

    if (widget.type == TransactionType.aeps) {
      final distributorComm = ref.read(commissionServiceProvider).getDistributorCommission(amount,
          ranges: ref.read(commissionConfigsProvider.notifier).getDistributorRanges());
      return (todayBalance?.aepsClosingBalance ?? todayBalance?.aepsOpeningBalance ?? 0) + amount + distributorComm;
    } else if (widget.type == TransactionType.cashIn) {
      if (_selectedAccountId == null) return null;
      final currentBal = todayBalance?.getBalance(_selectedAccountId!) ?? 0;
      return currentBal + amount;
    } else {
      if (_selectedAccountId == null) return null;
      final currentBal = todayBalance?.getBalance(_selectedAccountId!) ?? 0;
      return currentBal - amount;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPhonePe = widget.type == TransactionType.cashIn ||
        widget.type == TransactionType.cashOut;
    final isAEPS = widget.type == TransactionType.aeps;
    final accounts = ref.watch(accountsProvider);
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
              if (_hasDetectedCommission) ...[
                Card(
                  color: theme.colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb, color: theme.colorScheme.onPrimaryContainer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Detected: ₹${(_calculatedCommission!).toStringAsFixed(2)} commission included',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
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
                Text('Select Account *', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: accounts.map((acc) {
                    final selected = _selectedAccountId == acc.id;
                    return ChoiceChip(
                      label: Text(acc.name),
                      selected: selected,
                      onSelected: (v) => setState(() => _selectedAccountId = v ? acc.id : null),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
              ],
              if (isAEPS) ...[
                Card(
                  color: theme.colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.fingerprint, color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Text('AEPS Transaction', style: theme.textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            )),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _aadhaarController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Aadhaar Number *',
                            prefixIcon: Icon(Icons.credit_card),
                          ),
                          validator: (v) {
                            if (v?.trim().isEmpty ?? true) return 'Aadhaar number required';
                            if (v!.trim().length < 12) return 'Aadhaar must be 12 digits';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _bankNameController,
                decoration: const InputDecoration(
                  labelText: 'Bank Name *',
                  prefixIcon: Icon(Icons.account_balance),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) =>
                    v?.trim().isEmpty ?? true ? 'Bank name required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount *',
                  prefixIcon: Icon(Icons.currency_rupee),
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
                      '₹${projectedBalance.toStringAsFixed(2)}',
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
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Icon(Icons.monetization_on, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _autoCommission
                              ? (_calculatedCommission != null
                                  ? 'Commission: ₹${_calculatedCommission!.toStringAsFixed(2)}'
                                  : 'Auto Commission ON')
                              : 'Auto Commission OFF',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() => _autoCommission = !_autoCommission),
                        icon: Icon(
                          _autoCommission ? Icons.toggle_on : Icons.toggle_off_outlined,
                          color: _autoCommission ? Colors.green : Colors.grey,
                          size: 28,
                        ),
                        label: Text(_autoCommission ? 'ON' : 'OFF'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                title: const Text('Override Commission'),
                value: _commissionOverridden,
                onChanged: (v) => setState(() => _commissionOverridden = v ?? false),
                controlAffinity: ListTileControlAffinity.trailing,
              ),
              if (_commissionOverridden) ...[
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
            ],
          ),
        ),
      ),
    );
  }
}
