import '../../data/models/character/character_prompt.dart';
import '../constants/model_capabilities.dart';
import '../utils/nai_prompt_parser.dart';
import 'tokenizers/prompt_token_encoder.dart';
import 'tokenizers/qwen_prompt_token_encoder.dart';
import 'tokenizers/t5_prompt_token_encoder.dart';

export 'tokenizers/prompt_token_encoder.dart';
export 'tokenizers/t5_prompt_token_encoder.dart';

class PromptTokenUsage {
  const PromptTokenUsage({
    required this.usedTokens,
    required this.limit,
    this.breakdown = const [],
  });

  final int usedTokens;
  final int limit;
  final List<PromptTokenBreakdownEntry> breakdown;

  bool get isOverLimit => usedTokens > limit;
}

class PromptTokenBreakdownEntry {
  const PromptTokenBreakdownEntry({required this.label, required this.tokens});

  final String label;
  final int tokens;
}

class PromptTokenCounterService {
  const PromptTokenCounterService({
    required PromptTokenEncoder encoder,
    PromptTokenEncoder? qwenEncoder,
  }) : _encoder = encoder,
       _qwenEncoder = qwenEncoder;

  static const String _t5TokenizerAssetPath =
      'assets/data/tokenizers/t5_spiece.model';
  static const String _qwenTokenizerAssetPath =
      'assets/data/tokenizers/qwen35_bpe.txt.gz';

  /// V4 系列使用的 T5 分词器，同时作为未指定分词器时的兜底。
  final PromptTokenEncoder _encoder;

  /// V5 使用的 Qwen 分词器；为空时按需加载官方词表。
  final PromptTokenEncoder? _qwenEncoder;

  /// 是否有可用的分词器实现。V3 及更早使用 CLIP，启动器暂不支持。
  static bool supportsPromptTokenCount(String model) {
    final tokenizer = ModelCapabilityRegistry.of(model).tokenizer;
    return tokenizer == TokenizerKind.t5 || tokenizer == TokenizerKind.qwen35;
  }

  static int? tokenLimitForModel(String model) {
    if (!supportsPromptTokenCount(model)) {
      return null;
    }
    return ModelCapabilityRegistry.of(model).tokenLimit;
  }

  /// 官网计数条相对纯分词结果的偏移。
  ///
  /// T5 的 encode 会附加 EOS，官网计数条把它算进去（实测 "hello world"
  /// 显示 3）；Qwen 的 BPE encode 不带 EOS（同一文本显示 2），不能加。
  static int webAdjustmentForModel(String model) {
    return ModelCapabilityRegistry.of(model).tokenizer == TokenizerKind.t5
        ? 1
        : 0;
  }

  /// 计数前是否剥离 NAI 权重语法。
  ///
  /// T5 词表会把 `{}`、`::` 这类语法字符当作未知字符忽略，剥不剥结果相同，
  /// 剥离只是避免它们干扰逗号分段；Qwen 会把这些字符真实编码进 token
  /// （官网 "4::blending::" 计 5、"blending" 计 2），剥离会让计数偏小。
  static bool _stripsWeightSyntaxForCounting(String model) {
    return ModelCapabilityRegistry.of(model).tokenizer == TokenizerKind.t5;
  }

  static Future<PromptTokenCounterService> createDefault() async {
    // Qwen 词表有 1MB 出头，只在真正切到 V5 时才加载。
    final encoder = await T5PromptTokenEncoder.load(
      assetPath: _t5TokenizerAssetPath,
    );
    return PromptTokenCounterService(encoder: encoder);
  }

  Future<PromptTokenEncoder> _resolveEncoder(String model) async {
    if (ModelCapabilityRegistry.of(model).tokenizer != TokenizerKind.qwen35) {
      return _encoder;
    }
    return _qwenEncoder ??
        await QwenPromptTokenEncoder.load(assetPath: _qwenTokenizerAssetPath);
  }

  Future<PromptTokenUsage?> countUsageFromTexts({
    required String model,
    required String mainText,
    Iterable<String> extraTexts = const [],
    bool applyWebAdjustment = true,
    List<PromptTokenBreakdownEntry> breakdown = const [],
  }) async {
    final limit = tokenLimitForModel(model);
    if (limit == null) {
      return null;
    }

    final usedTokens = await countTokensForTexts(
      _collectCountedTexts(mainText: mainText, extraTexts: extraTexts),
      model: model,
      applyWebAdjustment: applyWebAdjustment,
    );

    return PromptTokenUsage(
      usedTokens: usedTokens,
      limit: limit,
      breakdown: breakdown,
    );
  }

  Future<PromptTokenUsage?> countUsage({
    required String model,
    required String basePrompt,
    required List<CharacterPrompt> characters,
    bool applyWebAdjustment = true,
  }) async {
    return countUsageFromTexts(
      model: model,
      mainText: basePrompt,
      extraTexts: characters
          .where((character) => character.enabled)
          .map((character) => character.prompt),
      applyWebAdjustment: applyWebAdjustment,
    );
  }

  Future<int> countTokensForTexts(
    Iterable<String> texts, {
    required String model,
    bool applyWebAdjustment = false,
  }) async {
    final encoder = await _resolveEncoder(model);
    final stripWeightSyntax = _stripsWeightSyntaxForCounting(model);

    var usedTokens = 0;
    for (final text in texts) {
      // Qwen 会把首尾空白与换行也编码成 token，官网原样计数，这里不能 trim。
      final normalizedText = stripWeightSyntax
          ? _normalizePromptForCounting(text)
          : text;
      if (normalizedText.trim().isEmpty) {
        continue;
      }
      usedTokens += await encoder.countTokens(normalizedText);
    }

    if (applyWebAdjustment && usedTokens > 0) {
      usedTokens += webAdjustmentForModel(model);
    }

    return usedTokens;
  }

  Iterable<String> _collectCountedTexts({
    required String mainText,
    required Iterable<String> extraTexts,
  }) sync* {
    // 只过滤纯空白文本，不做 trim：首尾空白是否计数由分词器分支决定。
    if (mainText.trim().isNotEmpty) {
      yield mainText;
    }

    for (final text in extraTexts) {
      if (text.trim().isEmpty) {
        continue;
      }
      yield text;
    }
  }

  static String _normalizePromptForCounting(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final normalizedBuffer = StringBuffer();
    final segmentBuffer = StringBuffer();
    var braceDepth = 0;
    var bracketDepth = 0;
    var parenDepth = 0;
    var inPipe = false;

    void flushSegment() {
      if (segmentBuffer.length == 0) {
        return;
      }
      normalizedBuffer.write(
        _stripSegmentWeightSyntaxPreservingWhitespace(segmentBuffer.toString()),
      );
      segmentBuffer.clear();
    }

    for (var i = 0; i < trimmed.length; i++) {
      final char = trimmed[i];

      if (char == '{') {
        braceDepth++;
      } else if (char == '}') {
        braceDepth--;
      } else if (char == '[') {
        bracketDepth++;
      } else if (char == ']') {
        bracketDepth--;
      } else if (char == '(') {
        parenDepth++;
      } else if (char == ')') {
        parenDepth--;
      }

      if (char == '|' && i + 1 < trimmed.length && trimmed[i + 1] == '|') {
        inPipe = !inPipe;
        segmentBuffer.write('||');
        i++;
        continue;
      }

      if (char == ',' &&
          braceDepth == 0 &&
          bracketDepth == 0 &&
          parenDepth == 0 &&
          !inPipe) {
        flushSegment();
        normalizedBuffer.write(',');
        continue;
      }

      segmentBuffer.write(char);
    }

    flushSegment();

    final normalized = normalizedBuffer.toString().trim();
    return normalized.isEmpty ? trimmed : normalized;
  }

  static String _stripSegmentWeightSyntaxPreservingWhitespace(String segment) {
    final leadingWhitespaceLength = segment.length - segment.trimLeft().length;
    final trailingWhitespaceLength =
        segment.length - segment.trimRight().length;
    final leadingWhitespace = segment.substring(0, leadingWhitespaceLength);
    final trailingWhitespace = segment.substring(
      segment.length - trailingWhitespaceLength,
    );
    final core = segment.trim();
    if (core.isEmpty) {
      return segment;
    }

    final strippedCore = NaiPromptParser.stripWeightSyntax(core);
    return '$leadingWhitespace$strippedCore$trailingWhitespace';
  }
}
