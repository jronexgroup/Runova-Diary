class AiSettings {
  final String apiKey;
  final bool enabled;
  final String model;

  static const String defaultModel = 'nvidia/nemotron-3.5-super-vl-120b-a12b';

  static const List<Map<String, String>> availableModels = [
    {'id': 'nvidia/nemotron-3.5-super-vl-120b-a12b', 'name': 'Nemotron 3.5 Super VL 120B', 'desc': 'Best accuracy, 10-60s (recommended)'},
    {'id': 'meta/llama-3.2-90b-vision-instruct', 'name': 'Llama 3.2 90B Vision', 'desc': 'Fallback, slower (60s+)'},
  ];

  const AiSettings({
    this.apiKey = '',
    this.enabled = false,
    this.model = defaultModel,
  });

  AiSettings copyWith({String? apiKey, bool? enabled, String? model}) {
    return AiSettings(
      apiKey: apiKey ?? this.apiKey,
      enabled: enabled ?? this.enabled,
      model: model ?? this.model,
    );
  }

  Map<String, dynamic> toJson() => {
    'apiKey': apiKey,
    'enabled': enabled,
    'model': model,
  };

  factory AiSettings.fromJson(Map<String, dynamic> json) {
    final apiKey = json['apiKey'] as String? ?? '';
    final savedModel = json['model'] as String? ?? '';
    final model = availableModels.any((m) => m['id'] == savedModel)
        ? savedModel
        : defaultModel;
    return AiSettings(
      apiKey: apiKey,
      enabled: json['enabled'] as bool? ?? apiKey.isNotEmpty,
      model: model,
    );
  }

  static const AiSettings defaults = AiSettings();
}
