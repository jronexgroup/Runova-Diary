class AiSettings {
  final String apiKey;
  final List<String> geminiApiKeys;
  final bool enabled;

  const AiSettings({
    this.apiKey = '',
    this.geminiApiKeys = const [],
    this.enabled = false,
  });

  String get primaryGeminiKey => geminiApiKeys.isNotEmpty ? geminiApiKeys.first : '';
  bool get hasGeminiKeys => geminiApiKeys.isNotEmpty;

  AiSettings copyWith({String? apiKey, List<String>? geminiApiKeys, bool? enabled}) {
    return AiSettings(
      apiKey: apiKey ?? this.apiKey,
      geminiApiKeys: geminiApiKeys ?? this.geminiApiKeys,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'apiKey': apiKey,
    'geminiApiKeys': geminiApiKeys,
    'enabled': enabled,
  };

  factory AiSettings.fromJson(Map<String, dynamic> json) {
    final apiKey = json['apiKey'] as String? ?? '';
    List<String> geminiKeys;
    final raw = json['geminiApiKeys'];
    if (raw is List) {
      geminiKeys = raw.cast<String>();
    } else {
      final old = json['geminiApiKey'] as String? ?? '';
      geminiKeys = old.isNotEmpty ? [old] : [];
    }
    return AiSettings(
      apiKey: apiKey,
      geminiApiKeys: geminiKeys,
      enabled: json['enabled'] as bool? ?? (apiKey.isNotEmpty || geminiKeys.isNotEmpty),
    );
  }

  static const AiSettings defaults = AiSettings();
}
