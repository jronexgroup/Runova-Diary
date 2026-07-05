import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/transaction.dart';
import '../providers/providers.dart';
import '../utils/constants.dart';

class EditTransactionScreen extends ConsumerStatefulWidget {
  final String transactionId;

  const EditTransactionScreen({super.key, required this.transactionId});

  @override
  ConsumerState<EditTransactionScreen> createState() =>
      _EditTransactionScreenState();
}

class _EditTransactionScreenState extends ConsumerState<EditTransactionScreen> {
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
  Transaction? _original;

  @override
  void initState() {
    super.initState();
    _loadTransaction();
  }

  void _loadTransaction() {
    final allTxns = ref.read(transactionsProvider);
    final txn = allTxns.where((t) => t.id == widget.transactionId).firstOrNull;
    if (txn == null) return;

    _original = txn;
    _customerNameController.text = txn.customerName;
    _amountController.text = txn.amount.toStringAsFixed(0);
    _mobileController.text = txn.mobileNumber ?? '';
    _txnIdController.text = txn.transactionId ?? '';
    _notesController.text = txn.notes ?? '';
    _bankNameController.text = txn.bankName ?? '';
    _commissionController.text = txn.commission.toStringAsFixed(0);
    _selectedAccount = txn.phonePeAccount;
    _overrideCommission = txn.commissionOverridden;
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_original == null) return;

    final user = ref.read(authProvider);
    if (user == null) return;

    setState(() => _loading = true);

    final amount = double.parse(_amountController.text.trim());
    final commission = double.parse(_commissionController.text.trim());

    final updated = _original!.copyWith(
      customerName: _customerNameController.text.trim(),
      amount: amount,
      commission: commission,
      commissionOverridden: _overrideCommission,
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
    );

    try {
      await ref.read(transactionsProvider.notifier)
          .updateTransaction(_original!, updated);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transaction updated')),
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

  @override
  Widget build(BuildContext context) {
    if (_original == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Edit Transaction')),
        body: const Center(child: Text('Transaction not found')),
      );
    }

    final isPhonePe = _original!.type == TransactionType.cashIn ||
        _original!.type == TransactionType.cashOut;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Transaction')),
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
              ),
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
              if (_original!.type == TransactionType.aeps) ...[
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Override Commission'),
                  value: _overrideCommission,
                  onChanged: (v) => setState(() => _overrideCommission = v ?? false),
                  controlAffinity: ListTileControlAffinity.trailing,
                ),
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
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Update Transaction'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
