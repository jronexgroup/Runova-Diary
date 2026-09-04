import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../providers/providers.dart';
import '../services/ai_service.dart';
import '../services/text_parser_service.dart';
import '../utils/constants.dart';
import '../widgets/ai_roadmap_dialog.dart';

class ShareHandlerScreen extends ConsumerStatefulWidget {
  const ShareHandlerScreen({super.key});

  @override
  ConsumerState<ShareHandlerScreen> createState() => _ShareHandlerScreenState();
}

class _ShareHandlerScreenState extends ConsumerState<ShareHandlerScreen> {
  String? _sharedFilePath;
  String? _sharedText;
  bool _initialized = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _initShareReceiver();
  }

  bool get _isImage => _sharedFilePath != null && _isImageFile(_sharedFilePath!);
  bool get _isText => _sharedText != null && _sharedText!.isNotEmpty;
  bool get _hasContent => _sharedFilePath != null || _isText;

  bool _isImageFile(String path) {
    final ext = path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'webp', 'gif', 'bmp', 'heic', 'heif'].contains(ext);
  }

  Future<void> _initShareReceiver() async {
    final extra = GoRouterState.of(context).extra;
    if (extra != null) {
      if (extra is String) {
        if (extra.contains('\n') || extra.contains('Amount') || extra.contains('UPI')) {
          setState(() {
            _sharedText = extra;
            _initialized = true;
          });
        } else {
          setState(() {
            _sharedFilePath = extra;
            _initialized = true;
          });
        }
        return;
      }
    }

    final platformStream = ReceiveSharingIntent.instance.getMediaStream();
    platformStream.listen((List<SharedMediaFile> files) {
      if (files.isNotEmpty) {
        final file = files.first;
        if (file.type == SharedMediaType.text) {
          setState(() {
            _sharedText = file.path;
            _initialized = true;
          });
        } else {
          setState(() {
            _sharedFilePath = file.path;
            _initialized = true;
          });
        }
      }
    });

    final initialFiles = await ReceiveSharingIntent.instance.getInitialMedia();
    if (initialFiles.isNotEmpty) {
      final file = initialFiles.first;
      if (file.type == SharedMediaType.text) {
        setState(() {
          _sharedText = file.path;
          _initialized = true;
        });
      } else {
        setState(() {
          _sharedFilePath = file.path;
          _initialized = true;
        });
      }
      ReceiveSharingIntent.instance.reset();
    } else {
      setState(() => _initialized = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!_initialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Runova Diary')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasContent) {
      return Scaffold(
        appBar: AppBar(title: const Text('Runova Diary')),
        body: const Center(child: Text('No content received')),
      );
    }

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('New Transaction')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('New Transaction')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isImage)
              Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(File(_sharedFilePath!), height: 200, fit: BoxFit.cover),
                ),
              )
            else if (_isText)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.text_snippet, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text('Shared Text', style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          )),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(_sharedText!, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text('Select transaction type', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            _typeButton(context, 'PhonePe Cash In', Icons.add_circle, Colors.green, TransactionType.cashIn),
            const SizedBox(height: 12),
            _typeButton(context, 'PhonePe Cash Out', Icons.remove_circle, Colors.orange, TransactionType.cashOut),
            const SizedBox(height: 12),
            _typeButton(context, 'AEPS Transaction', Icons.fingerprint, Colors.purple, TransactionType.aeps),
          ],
        ),
      ),
    );
  }

  Widget _typeButton(BuildContext context, String label, IconData icon, Color color, TransactionType type) {
    return SizedBox(
      width: 280,
      child: ElevatedButton.icon(
        onPressed: () => _processWithType(type),
        icon: Icon(icon, color: color),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Future<void> _processWithType(TransactionType type) async {
    if (_isText) {
      _processText(type);
    } else if (_sharedFilePath != null) {
      _processImage(type);
    }
  }

  void _processText(TransactionType type) {
    final parser = TextParserService();
    final result = parser.parse(_sharedText!);

    if (!result.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Could not parse text')),
      );
      return;
    }

    final accounts = ref.read(accountsProvider);
    String? matchedId;
    final lastFour = result.fields['lastFourDigits'];
    if (lastFour != null) {
      for (final acc in accounts) {
        if (acc.id.length >= 4 && acc.id.endsWith(lastFour)) {
          matchedId = acc.id;
          break;
        }
      }
    }

    context.push('/new-transaction/${type.name}', extra: {
      'fields': result.fields,
      'matchedAccountId': matchedId,
    });
  }

  Future<void> _processImage(TransactionType type) async {
    if (_sharedFilePath == null) return;

    final aiSettings = ref.read(aiSettingsProvider);
    if (!aiSettings.enabled || aiSettings.apiKey.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI not configured. Enable in Settings > AI Settings')),
      );
      return;
    }

    if (!mounted) return;
    final progressNotifier = ValueNotifier<AiProgressData>(
      const AiProgressData(step: AiProgressStep.readingImage, message: 'Reading image...'),
    );
    final monitorNotifier = ValueNotifier<AiMonitorInfo>(const AiMonitorInfo());
    AiRoadmapDialog.show(context, progressNotifier, monitorNotifier);

    setState(() => _loading = true);
    final accounts = ref.read(accountsProvider);
    final aiService = AiService(aiSettings, onMonitor: (info) {
      monitorNotifier.value = info;
    });
    final result = await aiService.processDocument(
      _sharedFilePath!,
      onProgress: (step, msg) {
        progressNotifier.value = AiProgressData(step: step, message: msg);
      },
    );

    if (!mounted) return;

    if (!result.isSuccess) {
      setState(() => _loading = false);
      progressNotifier.value = const AiProgressData(step: AiProgressStep.done, message: 'Done!');
      if (!mounted) return;
      _showAiError(context, result.error ?? 'Unknown error');
      return;
    }

    progressNotifier.value = const AiProgressData(step: AiProgressStep.fillingFields, message: 'Filling fields...');
    final matchedId = aiService.matchAccountId(result.fields, accounts);
    progressNotifier.value = const AiProgressData(step: AiProgressStep.done, message: 'Done!');

    if (!mounted) return;
    await context.push('/new-transaction/${type.name}', extra: {
      'fields': result.fields,
      'matchedAccountId': matchedId,
    });
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
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
            onPressed: () {
              Navigator.of(context).pop();
              context.push('/ai-logs');
            },
            child: const Text('View Logs'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
