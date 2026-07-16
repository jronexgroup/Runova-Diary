import 'package:flutter/material.dart';
import '../services/ai_service.dart';

class AiRoadmapDialog extends StatefulWidget {
  final ValueNotifier<AiProgressData> progressNotifier;
  final ValueNotifier<AiMonitorInfo> monitorNotifier;

  const AiRoadmapDialog({
    super.key,
    required this.progressNotifier,
    required this.monitorNotifier,
  });

  static Future<void> show(
    BuildContext context,
    ValueNotifier<AiProgressData> progressNotifier,
    ValueNotifier<AiMonitorInfo> monitorNotifier,
  ) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AiRoadmapDialog(
        progressNotifier: progressNotifier,
        monitorNotifier: monitorNotifier,
      ),
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
    widget.monitorNotifier.addListener(_onMonitor);
  }

  @override
  void dispose() {
    widget.progressNotifier.removeListener(_onProgress);
    widget.monitorNotifier.removeListener(_onMonitor);
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

  void _onMonitor() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = widget.progressNotifier.value.step;
    final monitorInfo = widget.monitorNotifier.value;
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
            if (currentStep != AiProgressStep.readingImage &&
                currentStep != AiProgressStep.done) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: monitorInfo.provider == 'gemini'
                      ? Colors.blue.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: monitorInfo.provider == 'gemini'
                        ? Colors.blue.shade200
                        : Colors.orange.shade200,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      monitorInfo.provider == 'gemini'
                          ? Icons.auto_awesome
                          : Icons.cloud,
                      size: 16,
                      color: monitorInfo.provider == 'gemini'
                          ? Colors.blue
                          : Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      monitorInfo.displayLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: monitorInfo.provider == 'gemini'
                            ? Colors.blue.shade700
                            : Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              if (monitorInfo.switchReason != null) ...[
                const SizedBox(height: 4),
                Text(
                  monitorInfo.switchReason!,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ],
              const SizedBox(height: 12),
            ],
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
