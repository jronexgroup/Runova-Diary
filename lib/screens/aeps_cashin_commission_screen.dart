import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/commission_config.dart';
import '../providers/providers.dart';

class AepsCashInCommissionScreen extends ConsumerStatefulWidget {
  const AepsCashInCommissionScreen({super.key});

  @override
  ConsumerState<AepsCashInCommissionScreen> createState() => _AepsCashInCommissionScreenState();
}

class _AepsCashInCommissionScreenState extends ConsumerState<AepsCashInCommissionScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _perThousandCtrl;
  late List<CommissionRange> _ranges;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final config = ref.read(commissionConfigsProvider.notifier).getAepsCashInConfig();
    _perThousandCtrl = TextEditingController(text: config.cashInPerThousand.toString());
    _ranges = List.from(config.cashInRanges);
  }

  @override
  void dispose() {
    _perThousandCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_saving) return;
    setState(() => _saving = true);

    final user = ref.read(authProvider);
    if (user == null) return;

    final config = CommissionConfig(
      cashInPerThousand: double.tryParse(_perThousandCtrl.text) ?? 10,
      cashInRanges: _ranges,
    );
    await ref.read(commissionConfigsProvider.notifier).setAepsCashInConfig(config, user.id);
    if (mounted) context.pop();
  }

  void _addRange() {
    setState(() {
      _ranges.add(const CommissionRange(min: 0, max: 0, rate: 0));
    });
  }

  void _deleteRange(int index) {
    setState(() {
      _ranges.removeAt(index);
    });
  }

  Future<void> _editRange(int index) async {
    final range = _ranges[index];
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
                decoration: const InputDecoration(labelText: 'Commission (flat \u20B9)', isDense: true),
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
                _ranges[index] = CommissionRange(
                  min: int.tryParse(minCtrl.text) ?? 0,
                  max: int.tryParse(maxCtrl.text) ?? 0,
                  rate: double.tryParse(rateCtrl.text) ?? 0,
                );
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
      appBar: AppBar(title: const Text('AEPS Cash In Commission')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: theme.colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.fingerprint, color: theme.colorScheme.onPrimaryContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Commission for AEPS Cash In transactions',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Flat Rate', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: _perThousandCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Commission (per \u20B91,000)',
                prefixIcon: Icon(Icons.monetization_on),
              ),
              validator: (v) {
                if (v?.trim().isEmpty ?? true) return 'Required';
                if (double.tryParse(v!) == null) return 'Enter a valid number';
                return null;
              },
            ),
            const Divider(height: 32),
            Text('Range-based Commission', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            if (_ranges.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No ranges configured \u2014 using flat rate'),
                ),
              )
            else
              ..._ranges.asMap().entries.map((e) => _rangeCard(e.key, e.value)),
            TextButton.icon(
              onPressed: _addRange,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Range'),
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

  Widget _rangeCard(int index, CommissionRange range) {
    return Card(
      child: ListTile(
        dense: true,
        title: Text('\u20B9${range.min} \u2013 \u20B9${range.max}'),
        subtitle: Text('Commission: \u20B9${range.rate.toStringAsFixed(2)} flat'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, size: 18),
              onPressed: () => _editRange(index),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              onPressed: () => _deleteRange(index),
            ),
          ],
        ),
      ),
    );
  }
}
