class AiSettings {
  final String apiKey;
  final String geminiApiKey;
  final bool enabled;

  const AiSettings({
    this.apiKey = '',
    this.geminiApiKey = '',
    this.enabled = false,
  });

  AiSettings copyWith({String? apiKey, String? geminiApiKey, bool? enabled}) {
    return AiSettings(
      apiKey: apiKey ?? this.apiKey,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'apiKey': apiKey,
    'geminiApiKey': geminiApiKey,
    'enabled': enabled,
  };

  factory AiSettings.fromJson(Map<String, dynamic> json) {
    final apiKey = json['apiKey'] as String? ?? '';
    final geminiApiKey = json['geminiApiKey'] as String? ?? '';
    return AiSettings(
      apiKey: apiKey,
      geminiApiKey: geminiApiKey,
      enabled: json['enabled'] as bool? ?? (apiKey.isNotEmpty || geminiApiKey.isNotEmpty),
    );
  }

  static const AiSettings defaults = AiSettings();
}
