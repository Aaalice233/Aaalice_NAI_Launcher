import 'package:flutter/material.dart';
import 'ai_brand_icon.dart';

enum ModelFamily {
  gemini('gemini-color'),
  deepseek('deepseek-color'),
  grok('grok'),
  openai('openai'),
  claude('claude-color'),
  qwen('qwen-color'),
  glm('zai'),
  kimi('kimi'),
  minimax('minimax-color'),
  mistral('mistral-color'),
  llama('meta-color'),
  novelai('novelai'),
  gemma('gemma-color'),
  doubao('doubao-color'),
  hunyuan('hunyuan-color'),
  cohere('cohere-color'),
  wenxin('wenxin-color'),
  stepfun('stepfun-color'),
  bytedance('bytedance-color'),
  nvidia('nvidia-color'),
  microsoft('microsoft-color'),
  perplexity('perplexity-color'),
  nova('nova-color'),
  xiaomimimo('xiaomimimo'),
  flux('flux'),
  stability('stability-color'),
  midjourney('midjourney'),
  dalle('dalle-color'),
  sora('sora-color'),
  google('google-color'),
  kling('kling-color'),
  jimeng('jimeng-color'),
  hailuo('hailuo-color'),
  runway('runway');

  const ModelFamily(this.assetName);

  final String assetName;

  String get assetPath => 'assets/icons/ai_brands/$assetName.png';

  /// A gateway's provider name and API protocol do not identify the model.
  /// Prefer the actual model ID over a user-editable display alias.
  static ModelFamily? resolve(String modelId, {String? displayName}) =>
      _match(modelId) ?? _match(displayName ?? '');

  static ModelFamily? _match(String value) {
    final name = value.trim().toLowerCase().split('/').last;
    for (final (pattern, family) in _rules) {
      if (pattern.hasMatch(name)) return family;
    }
    return null;
  }

  static RegExp _prefix(String pattern) =>
      RegExp(r'^(?:' + pattern + r')(?:$|[\s\d_.:/-])');

  static final _rules = <(RegExp, ModelFamily)>[
    (_prefix(r'gemini|金鱼奶|雙子座|双子座'), gemini),
    (_prefix(r'deepseek|deep-seek|深度求索'), deepseek),
    (_prefix(r'grok'), grok),
    (_prefix(r'gpt|chatgpt|codex|openai|o[134]'), openai),
    (_prefix(r'claude|anthropic'), claude),
    (_prefix(r'qwen|qwq|qvq|通义千问|通義千問'), qwen),
    (_prefix(r'glm|chatglm|zai|智谱|智譜'), glm),
    (_prefix(r'kimi|moonshot'), kimi),
    (_prefix(r'minimax|abab'), minimax),
    (
      _prefix(
        r'mistral|mixtral|magistral|codestral|ministral|devstral|pixtral',
      ),
      mistral,
    ),
    (_prefix(r'llama|meta-llama'), llama),
    (_prefix(r'nai|novelai|novel ai'), novelai),
    (_prefix(r'gemma'), gemma),
    (_prefix(r'doubao|豆包'), doubao),
    (_prefix(r'hunyuan|混元'), hunyuan),

    (
      _prefix(
        r'cohere|command|c4ai|aya|embed-english|embed-multilingual|rerank-english|rerank-multilingual',
      ),
      cohere,
    ),

    (_prefix(r'ernie|wenxin|文心'), wenxin),
    (_prefix(r'step|stepfun|阶跃|階躍'), stepfun),
    (_prefix(r'seed|seedream|seedance|bytedance'), bytedance),
    (_prefix(r'nemotron|nvidia-nemotron|nvidia'), nvidia),
    (_prefix(r'phi|phi-msft|mai'), microsoft),

    (_prefix(r'sonar|perplexity|pplx'), perplexity),

    (_prefix(r'nova|amazon\.nova|amazon-nova'), nova),
    (_prefix(r'mimo|xiaomi-mimo'), xiaomimimo),

    (_prefix(r'flux'), flux),
    (
      _prefix(
        r'stable-diffusion|stable_diffusion|stable-image|stable-video|sdxl|sd3|sd-3',
      ),
      stability,
    ),

    (_prefix(r'midjourney|niji'), midjourney),
    (_prefix(r'dall-e|dalle'), dalle),
    (_prefix(r'sora'), sora),
    (_prefix(r'imagen|veo|palm|text-bison|chat-bison'), google),
    (_prefix(r'kling|可灵|可靈'), kling),
    (_prefix(r'jimeng|即梦|即夢'), jimeng),

    (_prefix(r'hailuo|海螺'), hailuo),
    (_prefix(r'runway|gen-3|gen-4'), runway),
  ];
}

/// Decorative identity next to the accessible model name; never a network load.
class ModelFamilyIcon extends StatelessWidget {
  const ModelFamilyIcon({
    super.key,
    required this.modelId,
    this.displayName,
    this.size = 18,
    this.color,
  });

  final String modelId;
  final String? displayName;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final family = ModelFamily.resolve(modelId, displayName: displayName);
    return AiBrandIcon(assetName: family?.assetName, size: size, color: color);
  }
}

/// Shared model label for compact buttons, dropdowns and metadata values.
class ModelNameLabel extends StatelessWidget {
  const ModelNameLabel({
    super.key,
    required this.modelId,
    this.displayName,
    this.style,
    this.iconSize = 18,
    this.maxLines = 1,
  });

  final String modelId;
  final String? displayName;
  final TextStyle? style;
  final double iconSize;
  final int maxLines;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ModelFamilyIcon(
        modelId: modelId,
        displayName: displayName,
        size: iconSize,
        color: style?.color,
      ),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          displayName ?? modelId,
          style: style,
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}
