import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../models/transaction.dart';
import '../providers/providers.dart';
import '../services/ai_service.dart';
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
    _amountController.text = txn.amount.toStringAsFixed(2);
    _aadhaarController.text = txn.aadhaarNumber ?? '';
    _mobileController.text = txn.mobileNumber ?? '';
    _txnIdController.text = txn.transactionId ?? '';
    _notesController.text = txn.notes ?? '';
    _bankNameController.text = txn.bankName ?? '';
    _commissionController.text = txn.commission.toStringAsFixed(2);
    _selectedAccountId = txn.account ?? txn.phonePeAccount?.name;
    _commissionOverridden = txn.commissionOverridden;
  }

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
    if (_original == null) return null;
    final cfg = _selectedAccountId != null
        ? ref.read(commissionConfigsProvider.notifier).getAccountConfig(_selectedAccountId!)
        : null;
    return ref.read(commissionServiceProvider).calculateCommission(amount, _original!.type,
        cashInRanges: cfg?.cashInRanges,
        cashOutRanges: cfg?.cashOutRanges,
        cashInPerThousand: cfg?.cashInPerThousand,
        cashOutPerThousand: cfg?.cashOutPerThousand);
  }

  bool get _hasDetectedCommission {
    final c = _calculatedCommission;
    return c != null && c > 0;
  }

  Future<void> _processAi() async {
    final aiSettings = ref.read(aiSettingsProvider);
    if (!aiSettings.enabled || aiSettings.apiKey.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI not configured. Enable in Settings > AI Settings')),
      );
      return;
    }

    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    setState(() => _loading = true);
    final aiService = AiService(aiSettings);
    final fields = await aiService.processDocument(file.path);

    if (!mounted) return;
    setState(() => _loading = false);

    if (fields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not extract data from image')),
      );
      return;
    }

    if (fields['customerName'] != null) {
      _customerNameController.text = fields['customerName'] as String;
    }
    if (fields['amount'] != null) {
      _amountController.text = fields['amount'] as String;
    }
    if (fields['mobileNumber'] != null) {
      _mobileController.text = fields['mobileNumber'] as String;
    }
    if (fields['transactionId'] != null) {
      _txnIdController.text = fields['transactionId'] as String;
    }
    if (fields['aadhaarNumber'] != null) {
      _aadhaarController.text = fields['aadhaarNumber'] as String;
    }

    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('AI filled ${fields.length} field(s)')),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_original == null) return;
    if (_loading) return;

    final user = ref.read(authProvider);
    if (user == null) return;

    setState(() => _loading = true);

    final amount = double.parse(_amountController.text.trim());
    final commission = _commissionOverridden
        ? (double.tryParse(_commissionController.text.trim()) ?? 0.0)
        : (_autoCommission ? (_calculatedCommission ?? 0.0) : 0.0);
    final distributorComm = (_original!.type == TransactionType.aeps && !_commissionOverridden)
        ? ref.read(commissionServiceProvider).getDistributorCommission(amount,
            ranges: ref.read(commissionConfigsProvider.notifier).getDistributorRanges())
        : _original!.distributorCommission;

    final updated = _original!.copyWith(
      customerName: _customerNameController.text.trim(),
      amount: amount,
      commission: commission,
      distributorCommission: distributorComm,
      commissionOverridden: _commissionOverridden,
      mobileNumber: _mobileController.text.trim().isEmpty
          ? null
          : _mobileController.text.trim(),
      aadhaarNumber: _aadhaarController.text.trim().isEmpty
          ? null
          : _aadhaarController.text.trim(),
      transactionId: _txnIdController.text.trim().isEmpty
          ? null
          : _txnIdController.text.trim(),
      notes: _notesController.text.trim().isEmpty
          ? null
          : _notesController.text.trim(),
      bankName: _bankNameController.text.trim().isEmpty
          ? null
          : _bankNameController.text.trim(),
      phonePeAccount: null,
      account: _selectedAccountId,
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

    final theme = Theme.of(context);
    final isPhonePe = _original!.type == TransactionType.cashIn ||
        _original!.type == TransactionType.cashOut;
    final isAEPS = _original!.type == TransactionType.aeps;
    final accounts = ref.watch(accountsProvider);
    ref.watch(commissionConfigsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Transaction')),
      floatingActionButton: ref.read(aiSettingsProvider).enabled
          ? FloatingActionButton.small(
              onPressed: _loading ? null : _processAi,
              backgroundColor: Colors.teal,
              child: _loading
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome, color: Colors.white),
            )
          : null,
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
                Text('PhonePe Account *', style: theme.textTheme.labelLarge),
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
