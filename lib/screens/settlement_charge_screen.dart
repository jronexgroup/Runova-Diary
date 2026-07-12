import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/commission_config.dart';
import '../providers/providers.dart';

class SettlementChargeScreen extends ConsumerStatefulWidget {
  const SettlementChargeScreen({super.key});

  @override
  ConsumerState<SettlementChargeScreen> createState() => _SettlementChargeScreenState();
}

class _SettlementChargeScreenState extends ConsumerState<SettlementChargeScreen> {
  late List<SettlementRange> _ranges;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ranges = List.from(ref.read(commissionConfigsProvider.notifier).getSettlementRanges());
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final user = ref.read(authProvider);
    if (user == null) return;
    await ref.read(commissionConfigsProvider.notifier).setSettlementRanges(_ranges, user.id);
    if (mounted) context.pop();
  }

  void _add() {
    setState(() => _ranges.add(const SettlementRange(min: 0, max: 0, charge: 0)));
  }

  void _delete(int index) {
    setState(() => _ranges.removeAt(index));
  }

  Future<void> _edit(int index) async {
    final range = _ranges[index];
    final minCtrl = TextEditingController(text: range.min.toString());
    final maxCtrl = TextEditingController(text: range.max.toString());
    final chargeCtrl = TextEditingController(text: range.charge.toString());
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
                controller: chargeCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Charge (\u20B9)', isDense: true),
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
                _ranges[index] = SettlementRange(
                  min: int.tryParse(minCtrl.text) ?? 0,
                  max: int.tryParse(maxCtrl.text) ?? 0,
                  charge: double.tryParse(chargeCtrl.text) ?? 0,
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
      chargeCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settlement Charge Ranges')),
      body: Column(
        children: [
          Expanded(
            child: _ranges.isEmpty
                ? const Center(child: Text('No ranges configured'))
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _ranges.length,
                    itemBuilder: (_, i) {
                      final r = _ranges[i];
                      return Card(
                        child: ListTile(
                          title: Text('\u20B9${r.min} \u2013 \u20B9${r.max}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('\u20B9${r.charge.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold)),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: () => _edit(i),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                                onPressed: () => _delete(i),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _add,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Range'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
