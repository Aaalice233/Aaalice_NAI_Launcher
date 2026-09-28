import 'package:flutter/material.dart';

import '../../prompt_assistant/models/prompt_assistant_models.dart';
import 'ai_brand_icon.dart';

/// Provider identity is independent of the models exposed through its API.
String? providerIconAsset({ProviderConfig? provider, ProviderPreset? preset}) {
  if (provider != null) {
    final host = Uri.tryParse(provider.baseUrl)?.host.toLowerCase() ?? '';
    for (final entry in _providerDomains.entries) {
      if (host == entry.key || host.endsWith('.${entry.key}')) {
        return entry.value;
      }
    }
  }
  final asset = switch (preset ?? provider?.preset) {
    ProviderPreset.openaiChat || ProviderPreset.openaiResponses => 'openai',
    ProviderPreset.anthropic => 'anthropic',
    ProviderPreset.gemini => 'gemini-color',
    ProviderPreset.deepseek => 'deepseek-color',
    ProviderPreset.openRouter => 'openrouter-color',
    ProviderPreset.xai => 'xai',
    ProviderPreset.mistral => 'mistral-color',
    ProviderPreset.groq => 'groq',
    ProviderPreset.cerebras => 'cerebras-color',
    ProviderPreset.minimax || ProviderPreset.minimaxCn => 'minimax-color',
    ProviderPreset.kimiCoding => 'kimi',
    ProviderPreset.moonshot || ProviderPreset.moonshotCn => 'moonshot',
    ProviderPreset.qwenTokenPlan ||
    ProviderPreset.qwenTokenPlanCn ||
    ProviderPreset.qwenTokenPlanIndividual => 'qwen-color',
    ProviderPreset.lmStudioChat ||
    ProviderPreset.lmStudioResponses => 'lmstudio',
    ProviderPreset.ollama => 'ollama',
    ProviderPreset.pollinations => 'pollinations',
    ProviderPreset.openaiCompatibleChat ||
    ProviderPreset.openaiCompatibleResponses ||
    null => null,
  };
  if (asset != null || provider == null) return asset;
  // Custom relay URLs may hide the upstream host, but a recognized user-facing
  // brand name still supplies identity. The OpenAI-compatible protocol does not.
  final name = provider.name.trim().toLowerCase();
  for (final entry in _providerNames.entries) {
    if (name == entry.key || name.startsWith('${entry.key} ')) {
      return entry.value;
    }
  }
  return null;
}

const _providerDomains = <String, String>{
  'openai.azure.com': 'azure-color',
  'services.ai.azure.com': 'azure-color',
  'cognitiveservices.azure.com': 'azure-color',
  'openai.com': 'openai',
  'anthropic.com': 'anthropic',
  'generativelanguage.googleapis.com': 'gemini-color',
  'aiplatform.googleapis.com': 'vertexai-color',
  'deepseek.com': 'deepseek-color',
  'openrouter.ai': 'openrouter-color',
  'x.ai': 'xai',
  'mistral.ai': 'mistral-color',
  'groq.com': 'groq',
  'cerebras.ai': 'cerebras-color',
  'minimax.io': 'minimax-color',
  'minimaxi.com': 'minimax-color',
  'minimaxi.chat': 'minimax-color',
  'moonshot.ai': 'moonshot',
  'moonshot.cn': 'moonshot',
  'kimi.com': 'kimi',
  'siliconflow.cn': 'siliconcloud-color',
  'siliconflow.com': 'siliconcloud-color',
  'dashscope.aliyuncs.com': 'alibabacloud-color',
  'dashscope-intl.aliyuncs.com': 'alibabacloud-color',
  'volces.com': 'volcengine-color',
  'bigmodel.cn': 'zai',
  'z.ai': 'zai',
  'ollama.com': 'ollama',
  'pollinations.ai': 'pollinations',
  'together.xyz': 'together-color',
  'together.ai': 'together-color',
  'fireworks.ai': 'fireworks-color',
  'deepinfra.com': 'deepinfra-color',
  'huggingface.co': 'huggingface-color',
};

const _providerNames = <String, String>{
  'openai': 'openai',
  'anthropic': 'anthropic',
  'gemini': 'gemini-color',
  'google': 'google-color',
  'deepseek': 'deepseek-color',
  'openrouter': 'openrouter-color',
  'xai': 'xai',
  'x.ai': 'xai',
  'mistral': 'mistral-color',
  'groq': 'groq',
  'cerebras': 'cerebras-color',
  'minimax': 'minimax-color',
  'moonshot': 'moonshot',
  'kimi': 'kimi',
  'qwen': 'qwen-color',
  'lm studio': 'lmstudio',
  'lmstudio': 'lmstudio',
  'ollama': 'ollama',
  'pollinations': 'pollinations',
  'siliconflow': 'siliconcloud-color',
  '硅基流动': 'siliconcloud-color',
  '矽基流動': 'siliconcloud-color',
  '阿里云': 'alibabacloud-color',
  '阿里雲': 'alibabacloud-color',
  '百炼': 'alibabacloud-color',
  '百煉': 'alibabacloud-color',
  '火山引擎': 'volcengine-color',
  'volcengine': 'volcengine-color',
  'azure': 'azure-color',
  'bedrock': 'bedrock-color',
  'amazon bedrock': 'bedrock-color',
  'vertex ai': 'vertexai-color',
  '智谱': 'zai',
  '智譜': 'zai',
  'z.ai': 'zai',
  'together': 'together-color',
  'fireworks': 'fireworks-color',
  'deepinfra': 'deepinfra-color',
  'hugging face': 'huggingface-color',
};

class ProviderIcon extends StatelessWidget {
  const ProviderIcon({super.key, this.provider, this.preset, this.size = 18});

  final ProviderConfig? provider;
  final ProviderPreset? preset;
  final double size;

  @override
  Widget build(BuildContext context) => AiBrandIcon(
    assetName: providerIconAsset(provider: provider, preset: preset),
    size: size,
    fallback: Icons.hub_outlined,
  );
}

class ProviderNameLabel extends StatelessWidget {
  const ProviderNameLabel({
    super.key,
    this.provider,
    this.preset,
    this.displayName,
    this.style,
    this.iconSize = 18,
  });

  final ProviderConfig? provider;
  final ProviderPreset? preset;
  final String? displayName;
  final TextStyle? style;
  final double iconSize;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ProviderIcon(provider: provider, preset: preset, size: iconSize),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          displayName ?? provider?.name ?? preset?.label ?? '',
          style: style,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}
