import '../agent_types.dart';

/// 上下文溢出识别：按各 provider 的报错文本匹配，并识别静默溢出与截断式溢出。

final _overflowPatterns = <RegExp>[
  _pattern('prompt (?:is )?too long'),
  _pattern('prompt exceeds max length'),
  _pattern('request_too_large'),
  _pattern('input is too long for requested model'),
  _pattern('exceeds the context window'),
  _pattern(
    r"exceeds (?:the )?(?:model'?s )?maximum context length"
    r'(?: of [\d,]+ tokens?|\s*\([\d,]+\))',
  ),
  _pattern('input token count.*exceeds the maximum'),
  _pattern(r'maximum prompt length is \d+'),
  _pattern('reduce the length of the messages'),
  _pattern(r'maximum context length is \d+ tokens'),
  _pattern(r'exceeds (?:the )?maximum allowed input length of [\d,]+ tokens?'),
  _pattern(
    r"input \(\d+ tokens\) is longer than the model'?s context length "
    r'\(\d+ tokens\)',
  ),
  _pattern(r'exceeds the limit of \d+'),
  _pattern('exceeds the available context size'),
  _pattern('greater than the context length'),
  _pattern('context window exceeds limit'),
  _pattern('exceeded model token limit'),
  _pattern(r'too large for model with \d+ maximum context length'),
  _pattern(
    r'prompt has [\d,]+ tokens?, but the configured context size is '
    r'[\d,]+ tokens?',
  ),
  _pattern('model_context_window_exceeded'),
  _pattern('prompt too long; exceeded (?:max )?context length'),
  _pattern('range of input length should be'),
  _pattern('context[_ ]length[_ ]exceeded'),
  _pattern('too many tokens'),
  _pattern('token limit exceeded'),
  // 413 只认开头的状态码，正文里顺带提到的 413 不算。
  _pattern(r'^(?:[\w -]+ API error \(413\):|413(?:\s|:|$))'),
];

final _cerebrasBodylessOverflowPattern = _pattern(
  r'^4(?:00|13)\s*(?:status code)?\s*\(no body\)',
);

// 限流文案也会出现 "too many tokens"，需先排除。
final _nonOverflowPatterns = <RegExp>[
  _pattern('^(Throttling error|Service unavailable):'),
  _pattern('rate limit'),
  _pattern('too many requests'),
];

RegExp _pattern(String source) => RegExp(source, caseSensitive: false);

/// 助手消息是否表示上下文溢出：报错文本命中溢出模式；或成功返回但输入超出
/// [contextWindow]；或输入占满窗口导致零输出的 length 停止。
bool isContextOverflow(AssistantMessage message, [int? contextWindow]) {
  final errorMessage = message.errorMessage;
  if (message.stopReason == StopReason.error &&
      errorMessage != null &&
      errorMessage.isNotEmpty) {
    final isNonOverflow = _nonOverflowPatterns.any(
      (pattern) => pattern.hasMatch(errorMessage),
    );
    if (!isNonOverflow) {
      if (_overflowPatterns.any((pattern) => pattern.hasMatch(errorMessage))) {
        return true;
      }
      if (message.provider == 'cerebras' &&
          _cerebrasBodylessOverflowPattern.hasMatch(errorMessage)) {
        return true;
      }
    }
  }
  final usage = message.usage ?? Usage.empty;
  final inputTokens = usage.input + usage.cacheRead;
  if (contextWindow != null &&
      contextWindow > 0 &&
      message.stopReason == StopReason.stop &&
      inputTokens > contextWindow) {
    return true;
  }
  if (contextWindow != null &&
      contextWindow > 0 &&
      message.stopReason == StopReason.length &&
      usage.output == 0 &&
      inputTokens >= contextWindow * 0.99) {
    return true;
  }
  return false;
}
