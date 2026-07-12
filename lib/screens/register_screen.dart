import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/ai_settings.dart';
import '../providers/providers.dart';
import '../utils/constants.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _phoneController = TextEditingController();
  final _shopController = TextEditingController();
  final _ownerController = TextEditingController();
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  final _aiApiKeyController = TextEditingController();
  final _aiModelController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePin = true;
  bool _loading = false;
  bool _showAiSettings = false;
  bool _aiEnabled = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _shopController.dispose();
    _ownerController.dispose();
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);

    try {
      await ref.read(authProvider.notifier).register(
        phoneNumber: _phoneController.text.trim(),
        shopName: _shopController.text.trim(),
        ownerName: _ownerController.text.trim(),
        pin: _pinController.text.trim(),
      );

      final userId = ref.read(authProvider)?.id;
      if (_aiEnabled && userId != null) {
        final aiSettings = AiSettings(
          apiKey: _aiApiKeyController.text.trim(),
          model: _aiModelController.text.trim().isEmpty ? 'sarvam-1' : _aiModelController.text.trim(),
          enabled: true,
        );
        await ref.read(aiSettingsProvider.notifier).update(aiSettings, userId);
      }

      if (!mounted) return;
      context.go('/dashboard');
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    prefixIcon: Icon(Icons.phone),
                  ),
                  validator: (v) =>
                      v?.trim().isEmpty ?? true ? 'Phone number required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _shopController,
                  decoration: const InputDecoration(
                    labelText: 'Shop Name',
                    prefixIcon: Icon(Icons.store),
                  ),
                  validator: (v) =>
                      v?.trim().isEmpty ?? true ? 'Shop name required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _ownerController,
                  decoration: const InputDecoration(
                    labelText: 'Owner Name',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) =>
                      v?.trim().isEmpty ?? true ? 'Owner name required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _pinController,
                  obscureText: _obscurePin,
                  keyboardType: TextInputType.number,
                  maxLength: AppConstants.maxPinLength,
                  decoration: InputDecoration(
                    labelText: 'PIN (4-6 digits)',
                    prefixIcon: const Icon(Icons.lock),
                    counterText: '',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePin ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => _obscurePin = !_obscurePin),
                    ),
                  ),
                  validator: (v) {
                    if (v?.trim().isEmpty ?? true) return 'PIN required';
                    if ((v?.length ?? 0) < AppConstants.minPinLength) {
                      return 'PIN must be ${AppConstants.minPinLength}-${AppConstants.maxPinLength} digits';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: AppConstants.maxPinLength,
                  decoration: const InputDecoration(
                    labelText: 'Confirm PIN',
                    prefixIcon: Icon(Icons.lock_outline),
                    counterText: '',
                  ),
                  validator: (v) {
                    if (v != _pinController.text) return 'PINs do not match';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                InkWell(
                  onTap: () => setState(() => _showAiSettings = !_showAiSettings),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(_showAiSettings ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
                        const SizedBox(width: 8),
                        const Icon(Icons.auto_awesome, color: Colors.teal, size: 20),
                        const SizedBox(width: 8),
                        Text('AI Settings (optional)', style: Theme.of(context).textTheme.titleSmall),
                      ],
                    ),
                  ),
                ),
                if (_showAiSettings) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Enable AI Processing'),
                    value: _aiEnabled,
                    onChanged: (v) => setState(() => _aiEnabled = v),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _aiApiKeyController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Sarvam AI API Key',
                      prefixIcon: Icon(Icons.key),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _aiModelController,
                    decoration: const InputDecoration(
                      labelText: 'AI Model',
                      prefixIcon: Icon(Icons.smart_toy),
                      hintText: 'sarvam-1',
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loading ? null : _register,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Register'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Already have an account? Sign In'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
