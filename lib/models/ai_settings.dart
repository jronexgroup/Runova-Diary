class AiSettings {
  final String apiKey;
  final bool enabled;
  final String model;

  static const String defaultModel = 'google/diffusiongemma-26b-a4b-it';

  static const List<Map<String, String>> availableModels = [
    {'id': 'google/diffusiongemma-26b-a4b-it', 'name': 'DiffusionGemma 26B', 'desc': 'Best accuracy, 15-30s'},
    {'id': 'meta/llama-3.2-11b-vision-instruct', 'name': 'Llama 3.2 11B', 'desc': 'Fast (3-5s), good for quick scans'},
    {'id': 'meta/llama-3.2-90b-vision-instruct', 'name': 'Llama 3.2 90B', 'desc': 'Larger, slower, may timeout'},
    {'id': 'google/gemma-4-31b-it', 'name': 'Gemma 4 31B', 'desc': 'Experimental, may timeout'},
    {'id': 'nvidia/nemotron-3-nano-omni-30b-a3b-reasoning', 'name': 'Nemotron 3 Nano Omni', 'desc': 'Experimental, often overloaded'},
    {'id': 'z-ai/glm-5.3', 'name': 'GLM 5.3', 'desc': 'Experimental, may timeout'},
    {'id': 'moonshotai/kimi-k3', 'name': 'Kimi K3', 'desc': 'Experimental, may timeout'},
    {'id': 'deepseek-ai/deepseek-v4.1-flash', 'name': 'DeepSeek V4.1 Flash', 'desc': 'Experimental, may timeout'},
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
