import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/ai_settings.dart';
import '../providers/providers.dart';

class AiSettingsScreen extends ConsumerStatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  ConsumerState<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends ConsumerState<AiSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _apiKeyCtrl;
  bool _saving = false;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    final s = ref.read(aiSettingsProvider);
    _apiKeyCtrl = TextEditingController(text: s.apiKey);
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final user = ref.read(authProvider);
    if (user == null) return;
    setState(() => _saving = true);

    final updated = AiSettings(
      apiKey: _apiKeyCtrl.text.trim(),
      enabled: _apiKeyCtrl.text.trim().isNotEmpty,
    );

    await ref.read(aiSettingsProvider.notifier).update(updated, user.id);
    if (mounted) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI settings saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final aiEnabled = ref.watch(aiSettingsProvider).enabled;
    final userId = ref.watch(authProvider)?.id ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('AI Settings')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: SwitchListTile(
                title: const Text('Enable AI Processing'),
                subtitle: const Text('Use Sarvam AI to auto-fill transaction forms'),
                value: aiEnabled,
                onChanged: (v) {
                  ref.read(aiSettingsProvider.notifier).setEnabled(v, userId);
                },
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _apiKeyCtrl,
              obscureText: _obscureKey,
              decoration: InputDecoration(
                labelText: 'Sarvam AI API Key',
                prefixIcon: const Icon(Icons.key),
                suffixIcon: IconButton(
                  icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureKey = !_obscureKey),
                ),
              ),
              validator: (v) {
                if (aiEnabled && (v?.trim().isEmpty ?? true)) {
                  return 'API key required when AI is enabled';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('How it works',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Enter your Sarvam AI API key above\n'
                      '2. AI will auto-enable when a key is saved\n'
                      '3. On any New Transaction screen, tap the AI button\n'
                      '4. Upload an image or document\n'
                      '5. AI will auto-fill the form fields',
                      style: TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
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
}
