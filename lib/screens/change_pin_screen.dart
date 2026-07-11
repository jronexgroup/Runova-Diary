import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';
import '../utils/constants.dart';

class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  final _formKey = GlobalKey<FormState>();
  final _oldPinCtrl = TextEditingController();
  final _newPinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _oldPinCtrl.dispose();
    _newPinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authProvider.notifier).changePin(
        _oldPinCtrl.text,
        _newPinCtrl.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN changed successfully')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change PIN')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _oldPinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: AppConstants.maxPinLength,
                decoration: const InputDecoration(
                  labelText: 'Current PIN',
                  counterText: '',
                  prefixIcon: Icon(Icons.lock),
                ),
                validator: (v) =>
                    v?.isEmpty ?? true ? 'Enter current PIN' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: AppConstants.maxPinLength,
                decoration: const InputDecoration(
                  labelText: 'New PIN',
                  counterText: '',
                  prefixIcon: Icon(Icons.lock_reset),
                ),
                validator: (v) {
                  if (v?.isEmpty ?? true) return 'Enter new PIN';
                  if ((v?.length ?? 0) < AppConstants.minPinLength) {
                    return 'PIN must be ${AppConstants.minPinLength}-${AppConstants.maxPinLength} digits';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPinCtrl,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: AppConstants.maxPinLength,
                decoration: const InputDecoration(
                  labelText: 'Confirm New PIN',
                  counterText: '',
                  prefixIcon: Icon(Icons.lock),
                ),
                validator: (v) =>
                    v != _newPinCtrl.text ? 'PINs do not match' : null,
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
                    : const Text('Change PIN'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
