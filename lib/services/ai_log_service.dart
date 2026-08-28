import 'dart:collection';

class AiLogEntry {
  final DateTime timestamp;
  final String level;
  final String message;

  const AiLogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
  });

  @override
  String toString() => '[${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}] [$level] $message';
}

class AiLogService {
  static final AiLogService _instance = AiLogService._();
  factory AiLogService() => _instance;
  AiLogService._();

  static const int _maxEntries = 200;
  final List<AiLogEntry> _entries = [];

  UnmodifiableListView<AiLogEntry> get entries => UnmodifiableListView(_entries);

  void log(String level, String message) {
    _entries.add(AiLogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
    ));
    if (_entries.length > _maxEntries) {
      _entries.removeRange(0, _entries.length - _maxEntries);
    }
  }

  void info(String message) => log('INFO', message);
  void warn(String message) => log('WARN', message);
  void error(String message) => log('ERROR', message);

  void clear() => _entries.clear();

  String get fullLog => _entries.map((e) => e.toString()).join('\n');
}
