class AiSettings {
  final String apiKey;
  final bool enabled;
  final String model;

  static const String defaultModel = 'minimaxai/minimax-m3';

  static const List<Map<String, String>> availableModels = [
    {'id': 'minimaxai/minimax-m3', 'name': 'MiniMax M3', 'desc': 'Slow but accurate'},
    {'id': 'meta/llama-3.2-11b-vision-instruct', 'name': 'Llama 3.2 11B', 'desc': 'Fast but inconsistent'},
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
    return AiSettings(
      apiKey: apiKey,
      enabled: json['enabled'] as bool? ?? apiKey.isNotEmpty,
      model: json['model'] as String? ?? defaultModel,
    );
  }

  static const AiSettings defaults = AiSettings();
}
