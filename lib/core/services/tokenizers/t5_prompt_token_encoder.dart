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

    final encoding = _tokenizer.encode(normalized, addSpecialTokens: false);
    return encoding.ids.length;
  }
}
