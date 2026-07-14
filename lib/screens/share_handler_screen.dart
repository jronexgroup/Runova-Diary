import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../providers/providers.dart';
import '../services/ai_service.dart';
import '../utils/constants.dart';

class ShareHandlerScreen extends ConsumerStatefulWidget {
  const ShareHandlerScreen({super.key});

  @override
  ConsumerState<ShareHandlerScreen> createState() => _ShareHandlerScreenState();
}

class _ShareHandlerScreenState extends ConsumerState<ShareHandlerScreen> {
  String? _sharedImagePath;
  bool _initialized = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _initShareReceiver();
  }

  Future<void> _initShareReceiver() async {
    final extraPath = GoRouterState.of(context).extra as String?;
    if (extraPath != null) {
      setState(() {
        _sharedImagePath = extraPath;
        _initialized = true;
      });
      return;
    }

    final platformStream = ReceiveSharingIntent.instance.getMediaStream();
    platformStream.listen((List<SharedMediaFile> files) {
      if (files.isNotEmpty) {
        setState(() {
          _sharedImagePath = files.first.path;
          _initialized = true;
        });
      }
    });

    final initialFiles = await ReceiveSharingIntent.instance.getInitialMedia();
    if (initialFiles.isNotEmpty) {
      setState(() {
        _sharedImagePath = initialFiles.first.path;
        _initialized = true;
      });
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

    if (_sharedImagePath == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Runova Diary')),
        body: const Center(child: Text('No image received')),
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(_sharedImagePath!), height: 200, fit: BoxFit.cover),
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
    if (_sharedImagePath == null) return;

    final aiSettings = ref.read(aiSettingsProvider);
    if (!aiSettings.enabled || aiSettings.apiKey.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI not configured. Enable in Settings > AI Settings')),
      );
      return;
    }

    setState(() => _loading = true);

    final accounts = ref.read(accountsProvider);
    final aiService = AiService(aiSettings);
    final fields = await aiService.processDocument(_sharedImagePath!);

    if (!mounted) return;

    if (fields.isEmpty) {
      setState(() => _loading = false);
      if (!mounted) return;
      _showAiError(context);
      return;
    }

    final matchedId = aiService.matchAccountId(fields, accounts);

    if (!mounted) return;
    context.go('/new-transaction/${type.name}', extra: {
      'fields': fields,
      'matchedAccountId': matchedId,
    });
  }

  void _showAiError(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('AI Extraction Failed'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('The AI could not extract transaction details from this image. Possible causes:'),
            SizedBox(height: 12),
            Text('1. Image is blurry or low quality'),
            Text('2. Receipt format not recognized'),
            Text('3. AI service temporarily unavailable'),
            Text('4. API key has insufficient credits'),
            SizedBox(height: 12),
            Text('Try with a clearer screenshot of the payment receipt.'),
          ],
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
}