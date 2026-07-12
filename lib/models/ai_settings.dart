class AiSettings {
  final String apiKey;
  final bool enabled;

  const AiSettings({
    this.apiKey = '',
    this.enabled = false,
  });

  AiSettings copyWith({String? apiKey, bool? enabled}) {
    return AiSettings(
      apiKey: apiKey ?? this.apiKey,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'apiKey': apiKey,
    'enabled': enabled,
  };

  factory AiSettings.fromJson(Map<String, dynamic> json) {
    final apiKey = json['apiKey'] as String? ?? '';
    return AiSettings(
      apiKey: apiKey,
      enabled: json['enabled'] as bool? ?? (apiKey.isNotEmpty),
    );
  }

  static const AiSettings defaults = AiSettings();
}
