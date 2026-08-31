/// Whether a generation error says the endpoint cannot serve streaming output.
bool isStreamingGenerationUnsupportedError(Object? error) {
  if (error == null) return false;

  final message = error.toString().toLowerCase();
  const englishPhrases = [
    'streaming is not allowed',
    'streaming not allowed',
    'stream is not allowed',
    'stream not allowed',
    'streaming is not supported',
    'streaming not supported',
    'stream is not supported',
    'stream not supported',
    'streaming unsupported',
    'does not support streaming',
    "doesn't support streaming",
  ];
  if (englishPhrases.any(message.contains)) return true;

  const chinesePhrases = ['不支持流式', '不支援串流', '不允许流式', '不允許串流', '禁止流式', '串流不支援'];
  if (chinesePhrases.any(message.contains)) return true;

  if (message.contains('ストリーミング')) {
    return message.contains('未対応') ||
        message.contains('対応していない') ||
        message.contains('対応していません') ||
        message.contains('許可されていない') ||
        message.contains('許可されていません');
  }

  return false;
}
