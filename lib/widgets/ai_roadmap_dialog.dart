import 'package:flutter/material.dart';
import '../services/ai_service.dart';

class AiRoadmapDialog extends StatefulWidget {
  final ValueNotifier<AiProgressData> progressNotifier;

  const AiRoadmapDialog({super.key, required this.progressNotifier});

  static Future<void> show(BuildContext context, ValueNotifier<AiProgressData> notifier) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AiRoadmapDialog(progressNotifier: notifier),
    );
  }

  @override
  State<AiRoadmapDialog> createState() => _AiRoadmapDialogState();
}

class AiProgressData {
  final AiProgressStep step;
  final String message;

  const AiProgressData({required this.step, required this.message});
}

class _AiRoadmapDialogState extends State<AiRoadmapDialog> {
  @override
  void initState() {
    super.initState();
    widget.progressNotifier.addListener(_onProgress);
  }

  @override
  void dispose() {
    widget.progressNotifier.removeListener(_onProgress);
    super.dispose();
  }

  void _onProgress() {
    final data = widget.progressNotifier.value;
    if (data.step == AiProgressStep.done) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = widget.progressNotifier.value.step;
    final steps = [
      (AiProgressStep.readingImage, 'Reading image'),
      (AiProgressStep.compressing, 'Compressing'),
      (AiProgressStep.sendingToAi, 'Sending to AI'),
      (AiProgressStep.parsingResponse, 'Parsing response'),
      (AiProgressStep.fillingFields, 'Filling fields'),
    ];

    final currentIndex = steps.indexWhere((s) => s.$1 == currentStep);

    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('AI Processing'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ...List.generate(steps.length, (i) {
              final step = steps[i];
              final isActive = i == currentIndex;
              final isDone = i < currentIndex;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    if (isDone)
                      Icon(Icons.check_circle, color: Colors.green, size: 22)
                    else if (isActive)
                      const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    else
                      Icon(Icons.circle_outlined, color: Colors.grey.shade400, size: 22),
                    const SizedBox(width: 12),
                    Text(
                      step.$2,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                        color: isActive ? null : (isDone ? Colors.green.shade700 : Colors.grey),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (currentIndex >= 0 && currentIndex < steps.length) ...[
              const SizedBox(height: 16),
              Text(
                _currentMessage,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String get _currentMessage {
    switch (widget.progressNotifier.value.step) {
      case AiProgressStep.readingImage: return 'Reading image from device...';
      case AiProgressStep.compressing: return 'Compressing image...';
      case AiProgressStep.sendingToAi: return 'Sending to AI provider...';
      case AiProgressStep.parsingResponse: return 'Parsing AI response...';
      case AiProgressStep.fillingFields: return 'Filling fields...';
      case AiProgressStep.done: return 'Done!';
    }
  }
}
