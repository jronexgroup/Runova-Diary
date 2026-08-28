import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/ai_log_service.dart';

class AiLogsScreen extends StatelessWidget {
  const AiLogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final logs = AiLogService().entries;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Logs'),
        actions: [
          if (logs.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.copy),
              tooltip: 'Copy logs',
              onPressed: () {
                final text = AiLogService().fullLog;
                Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logs copied to clipboard')),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear logs',
              onPressed: () {
                AiLogService().clear();
                (context as Element).markNeedsBuild();
              },
            ),
          ],
        ],
      ),
      body: logs.isEmpty
          ? const Center(child: Text('No AI logs yet'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final entry = logs[logs.length - 1 - index];
                final color = entry.level == 'ERROR'
                    ? Colors.red.shade700
                    : entry.level == 'WARN'
                        ? Colors.orange.shade700
                        : Colors.grey.shade700;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    entry.toString(),
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: color,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
