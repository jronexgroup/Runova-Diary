class AiSettings {
  final String apiKey;
  final String model;
  final bool enabled;

  const AiSettings({
    this.apiKey = '',
    this.model = 'sarvam-1',
    this.enabled = false,
  });

  AiSettings copyWith({String? apiKey, String? model, bool? enabled}) {
    return AiSettings(
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
    'apiKey': apiKey,
    'model': model,
    'enabled': enabled,
  };

  factory AiSettings.fromJson(Map<String, dynamic> json) {
    return AiSettings(
      apiKey: json['apiKey'] as String? ?? '',
      model: json['model'] as String? ?? 'sarvam-1',
      enabled: json['enabled'] as bool? ?? false,
    );
  }

  static const AiSettings defaults = AiSettings();
}
