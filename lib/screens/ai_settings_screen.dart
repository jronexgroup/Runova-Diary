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
  final List<TextEditingController> _geminiKeyCtrls = [];
  final List<bool> _obscureGeminiKeys = [];
  bool _saving = false;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    final s = ref.read(aiSettingsProvider);
    _apiKeyCtrl = TextEditingController(text: s.apiKey);
    for (final key in s.geminiApiKeys) {
      _geminiKeyCtrls.add(TextEditingController(text: key));
      _obscureGeminiKeys.add(true);
    }
    if (_geminiKeyCtrls.isEmpty) {
      _geminiKeyCtrls.add(TextEditingController());
      _obscureGeminiKeys.add(true);
    }
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    for (final c in _geminiKeyCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addKey() {
    setState(() {
      _geminiKeyCtrls.add(TextEditingController());
      _obscureGeminiKeys.add(true);
    });
  }

  void _removeKey(int index) {
    if (_geminiKeyCtrls.length <= 1) return;
    setState(() {
      _geminiKeyCtrls[index].dispose();
      _geminiKeyCtrls.removeAt(index);
      _obscureGeminiKeys.removeAt(index);
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final user = ref.read(authProvider);
    if (user == null) return;
    setState(() => _saving = true);

    final geminiKeys = _geminiKeyCtrls
        .map((c) => c.text.trim())
        .where((k) => k.isNotEmpty)
        .toList();

    final updated = AiSettings(
      apiKey: _apiKeyCtrl.text.trim(),
      geminiApiKeys: geminiKeys,
      enabled: _apiKeyCtrl.text.trim().isNotEmpty || geminiKeys.isNotEmpty,
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
                        Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Text('Gemini API Keys (Primary)',
                            style: theme.textTheme.titleMedium),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Keys are tried in order. If one hits a quota limit, the next is used automatically.',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(_geminiKeyCtrls.length, (i) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _geminiKeyCtrls[i],
                                obscureText: _obscureGeminiKeys[i],
                                decoration: InputDecoration(
                                  labelText: 'Gemini Key ${i + 1}',
                                  prefixIcon: const Icon(Icons.key, size: 20),
                                  suffixIcon: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(
                                          _obscureGeminiKeys[i]
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                          size: 20,
                                        ),
                                        onPressed: () => setState(() =>
                                            _obscureGeminiKeys[i] = !_obscureGeminiKeys[i]),
                                      ),
                                      if (_geminiKeyCtrls.length > 1)
                                        IconButton(
                                          icon: const Icon(Icons.remove_circle_outline,
                                              color: Colors.red, size: 20),
                                          onPressed: () => _removeKey(i),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    TextButton.icon(
                      onPressed: _addKey,
                      icon: const Icon(Icons.add_circle_outline, size: 20),
                      label: const Text('Add another Gemini key'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _apiKeyCtrl,
              obscureText: _obscureKey,
              decoration: InputDecoration(
                labelText: 'Sarvam AI API Key (fallback)',
                hintText: 'Only used when all Gemini keys are exhausted',
                prefixIcon: const Icon(Icons.key),
                suffixIcon: IconButton(
                  icon: Icon(_obscureKey ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscureKey = !_obscureKey),
                ),
              ),
              validator: (v) {
                final hasGemini = _geminiKeyCtrls.any((c) => c.text.trim().isNotEmpty);
                if (aiEnabled && !hasGemini && (v?.trim().isEmpty ?? true)) {
                  return 'At least one API key required when AI is enabled';
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
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text(
                      '1. Add your Gemini API keys (primary providers)\n'
                      '2. Gemini Key 1 is used first\n'
                      '3. If Key 1 hits quota, Key 2 is used automatically\n'
                      '4. Continues through all keys until one works\n'
                      '5. If all Gemini keys are exhausted, Sarvam AI is used as fallback\n'
                      '6. AI will auto-enable when a key is saved\n'
                      '7. On any transaction screen, tap the AI button to process an image\n'
                      '\n'
                      'The active provider and key are shown during processing.',
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
