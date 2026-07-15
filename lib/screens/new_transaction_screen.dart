import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/providers.dart';
import '../services/ai_service.dart';
import '../utils/constants.dart';
import '../utils/date_utils.dart';

class NewTransactionScreen extends ConsumerStatefulWidget {
  final TransactionType type;
  final Map<String, dynamic>? initialFields;
  final String? initialAccountId;

  const NewTransactionScreen({
    super.key,
    required this.type,
    this.initialFields,
    this.initialAccountId,
  });

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

  final _customerNameFocus = FocusNode();
  final _amountFocus = FocusNode();
  final _aadhaarFocus = FocusNode();
  final _mobileFocus = FocusNode();
  final _txnIdFocus = FocusNode();
  final _notesFocus = FocusNode();
  final _bankNameFocus = FocusNode();
  final _commissionFocus = FocusNode();

  String? _selectedAccountId;
  bool _loading = false;
  bool _commissionOverridden = false;
  bool _autoCommission = true;

  @override
  void initState() {
    super.initState();
    final fields = widget.initialFields;
    if (fields != null) {
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
      if (fields['bankName'] != null) {
        _bankNameController.text = fields['bankName'] as String;
      }
      if (widget.initialAccountId != null) {
        _selectedAccountId = widget.initialAccountId;
      }
    }
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
    _customerNameFocus.dispose();
    _amountFocus.dispose();
    _aadhaarFocus.dispose();
    _mobileFocus.dispose();
    _txnIdFocus.dispose();
    _notesFocus.dispose();
    _bankNameFocus.dispose();
    _commissionFocus.dispose();
    super.dispose();
  }

  double? get _calculatedCommission {
    final amount = double.tryParse(_amountController.text);
    if (amount == null || amount <= 0) return null;
    if (!_autoCommission) return null;

    final cfg = widget.type == TransactionType.cashIn || widget.type == TransactionType.cashOut
        ? (_selectedAccountId != null
            ? ref.read(commissionConfigsProvider.notifier).getAccountConfig(_selectedAccountId!)
            : null)
        : null;

    return ref.read(commissionServiceProvider).calculateCommission(amount, widget.type,
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

    final accounts = ref.read(accountsProvider);
    final aiService = AiService(aiSettings);
    final result = await aiService.processDocument(file.path);

    if (!mounted) return;
    setState(() => _loading = false);

    if (!result.isSuccess) {
      if (!mounted) return;
      _showAiError(context, result.error ?? 'Unknown error');
      return;
    }

    final fields = result.fields;
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
    if (fields['bankName'] != null) {
      _bankNameController.text = fields['bankName'] as String;
    }

    final matchedId = aiService.matchAccountId(fields, accounts);
    if (matchedId != null) {
      _selectedAccountId = matchedId;
    }

    setState(() {});
    final msg = result.switched
        ? 'AI filled ${fields.length} field(s) (switched to Sarvam)'
        : 'AI filled ${fields.length} field(s)';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  void _showAiError(BuildContext context, String errorMessage) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI Extraction Failed'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('The AI could not extract transaction details.'),
              const SizedBox(height: 12),
              Text(errorMessage, style: TextStyle(color: Colors.red.shade700)),
              const SizedBox(height: 12),
              const Text('Possible causes:'),
              const SizedBox(height: 8),
              const Text('1. Image is blurry or low quality'),
              const Text('2. Receipt format not recognized'),
              const Text('3. AI service temporarily unavailable'),
              const Text('4. API key has insufficient credits'),
              const SizedBox(height: 12),
              const Text('Try with a clearer screenshot of the payment receipt.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_loading) return;

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
      if (widget.initialFields != null) {
        context.go('/home');
      } else {
        context.pop();
      }
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
    ref.watch(commissionConfigsProvider);
    final projectedBalance = _newBalance;
    final insufficient = widget.type == TransactionType.cashOut &&
        projectedBalance != null && projectedBalance < 0;

    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      resizeToAvoidBottomInset: true,
      floatingActionButton: ref.read(aiSettingsProvider).enabled
          ? FloatingActionButton.small(
              onPressed: _loading ? null : _processAi,
              backgroundColor: Colors.teal,
              child: _loading
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.auto_awesome, color: Colors.white),
            )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Form(
            key: _formKey,
            child: FocusTraversalGroup(
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
                              'Detected: \u20B9${(_calculatedCommission!).toStringAsFixed(2)} commission included',
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
                  focusNode: _customerNameFocus,
                  textInputAction: TextInputAction.next,
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
                            focusNode: _aadhaarFocus,
                            textInputAction: TextInputAction.next,
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
                  focusNode: _bankNameFocus,
                  textInputAction: TextInputAction.next,
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
                  focusNode: _amountFocus,
                  textInputAction: TextInputAction.next,
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
                        '\u20B9${projectedBalance.toStringAsFixed(2)}',
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
                  focusNode: _mobileFocus,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Mobile Number (optional)',
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _txnIdController,
                  focusNode: _txnIdFocus,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Transaction ID (optional)',
                    prefixIcon: Icon(Icons.receipt),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  focusNode: _notesFocus,
                  textInputAction: TextInputAction.next,
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
                                    ? 'Commission: \u20B9${_calculatedCommission!.toStringAsFixed(2)}'
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
                    focusNode: _commissionFocus,
                    textInputAction: TextInputAction.done,
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
      ),
      ),
    );
  }
}
