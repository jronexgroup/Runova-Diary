import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/commission_config.dart';
import '../providers/providers.dart';

class AepsCommissionScreen extends ConsumerStatefulWidget {
  const AepsCommissionScreen({super.key});

  @override
  ConsumerState<AepsCommissionScreen> createState() => _AepsCommissionScreenState();
}

class _AepsCommissionScreenState extends ConsumerState<AepsCommissionScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _withdrawalCtrl;
  late TextEditingController _enquiryCtrl;
  late TextEditingController _statementCtrl;
  late TextEditingController _aadhaarCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final config = ref.read(commissionConfigsProvider.notifier).getAepsConfig();
    _withdrawalCtrl = TextEditingController(text: config.cashWithdrawalPerThousand.toString());
    _enquiryCtrl = TextEditingController(text: config.balanceEnquiry.toString());
    _statementCtrl = TextEditingController(text: config.miniStatement.toString());
    _aadhaarCtrl = TextEditingController(text: config.aadhaarPayPerThousand.toString());
  }

  @override
  void dispose() {
    _withdrawalCtrl.dispose();
    _enquiryCtrl.dispose();
    _statementCtrl.dispose();
    _aadhaarCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_saving) return;
    setState(() => _saving = true);

    final user = ref.read(authProvider);
    if (user == null) return;

    final config = AepsCommissionConfig(
      cashWithdrawalPerThousand: double.tryParse(_withdrawalCtrl.text) ?? 10,
      balanceEnquiry: double.tryParse(_enquiryCtrl.text) ?? 0,
      miniStatement: double.tryParse(_statementCtrl.text) ?? 0,
      aadhaarPayPerThousand: double.tryParse(_aadhaarCtrl.text) ?? 0,
    );
    await ref.read(commissionConfigsProvider.notifier).setAepsConfig(config, user.id);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AEPS Commission')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _commField(_withdrawalCtrl, 'Cash Withdrawal (per \u20B91,000)'),
            const SizedBox(height: 12),
            _commField(_enquiryCtrl, 'Balance Enquiry (flat)'),
            const SizedBox(height: 12),
            _commField(_statementCtrl, 'Mini Statement (flat)'),
            const SizedBox(height: 12),
            _commField(_aadhaarCtrl, 'Aadhaar Pay (per \u20B91,000)'),
            const SizedBox(height: 24),
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
