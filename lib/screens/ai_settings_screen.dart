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
    _apiKeyCtrl = TextEditingController(text: ref.read(aiSettingsProvider).apiKey);
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

    final key = _apiKeyCtrl.text.trim();
    await ref.read(aiSettingsProvider.notifier).setApiKey(key, user.id);

    if (mounted) {
      context.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI settings saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final aiSettings = ref.watch(aiSettingsProvider);
    final aiEnabled = aiSettings.enabled;
    final userId = ref.watch(authProvider)?.id ?? '';
    final theme = Theme.of(context);

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
                subtitle: const Text('Use AI to auto-fill transaction forms'),
                value: aiEnabled,
                onChanged: (v) {
                  ref.read(aiSettingsProvider.notifier).setEnabled(v, userId);
                },
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.smart_toy, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('Vision Model', style: theme.textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select the AI model for receipt processing',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    ...AiSettings.availableModels.map((m) {
                      return RadioListTile<String>(
                        title: Text(m['name']!),
                        subtitle: Text(m['desc']!, style: theme.textTheme.bodySmall),
                        value: m['id']!,
                        groupValue: aiSettings.model,
                        onChanged: (v) {
                          if (v != null) {
                            ref.read(aiSettingsProvider.notifier).setModel(v, userId);
                          }
                        },
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                      );
                    }),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('NVIDIA NIM API Key',
                            style: theme.textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Free vision model for receipt processing. Get your key at build.nvidia.com',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _apiKeyCtrl,
                      obscureText: _obscureKey,
                      decoration: InputDecoration(
                        labelText: 'NVIDIA NIM API Key',
                        hintText: 'nvapi-...',
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
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('How it works',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Paste your NVIDIA NIM API key above\n'
                      '2. AI will auto-enable when a key is saved\n'
                      '3. On any transaction screen, tap the AI button to process a receipt\n'
                      '4. The receipt image is sent to NVIDIA NIM vision model\n'
                      '5. Fields like name, amount, transaction ID are auto-filled',
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
