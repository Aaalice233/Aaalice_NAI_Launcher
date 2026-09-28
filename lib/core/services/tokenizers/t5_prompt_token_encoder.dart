import 'package:dart_sentencepiece_tokenizer/dart_sentencepiece_tokenizer.dart';
import 'package:flutter/services.dart';

import 'prompt_token_encoder.dart';

/// NovelAI V4 / V4.5 使用的 T5 分词器。
class T5PromptTokenEncoder implements PromptTokenEncoder {
  T5PromptTokenEncoder._(this._tokenizer);

  /// 按资产路径缓存实例，词表解析只做一次。
  static final Map<String, Future<T5PromptTokenEncoder>> _instances =
      <String, Future<T5PromptTokenEncoder>>{};

  final SentencePieceTokenizer _tokenizer;

  /// 偏离上游：上游每次 countTokens 都真的跑一遍 SentencePiece 编码。一次计数
  /// 会把主提示词、固定词、质量预设、角色等多段文本分别编码，而两次计数之间
  /// 大部分段落并没有变化。按文本内容做实例级 LRU 缓存后，每次只需真正编码
  /// 发生变化的段落——移动端 UI 线程上这笔开销很明显。
  final Map<String, int> _countCache = <String, int>{};

  static const int _countCacheLimit = 512;

  static Future<T5PromptTokenEncoder> load({required String assetPath}) {
    return _instances.putIfAbsent(assetPath, () => _loadFromAsset(assetPath));
  }

  static Future<T5PromptTokenEncoder> _loadFromAsset(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    final tokenizer = SentencePieceTokenizer.fromBytes(
      data.buffer.asUint8List(),
      config: const SentencePieceConfig(),
    );
    return T5PromptTokenEncoder._(tokenizer);
  }

  @override
  Future<int> countTokens(String text) async {
    final normalized = text.trim();
    if (normalized.isEmpty) {
      return 0;
    }

    // LRU 命中：取出后重新写回末尾，保持最近使用顺序。
    final cached = _countCache.remove(normalized);
    if (cached != null) {
      _countCache[normalized] = cached;
      return cached;
    }

    final encoding = _tokenizer.encode(normalized, addSpecialTokens: false);
    final count = encoding.ids.length;
    if (_countCache.length >= _countCacheLimit) {
      _countCache.remove(_countCache.keys.first);
    }
    _countCache[normalized] = count;
    return count;
  }
}
