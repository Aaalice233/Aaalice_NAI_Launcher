import 'dart:convert';
import 'dart:typed_data';


const int defaultMaxLines = 2000;
const int defaultMaxBytes = 50 * 1024; // 50KB
const int grepMaxLineLength = 500;

enum TruncatedBy { lines, bytes }

class TruncationResult {
  const TruncationResult({
    required this.content,
    required this.truncated,
    required this.truncatedBy,
    required this.totalLines,
    required this.totalBytes,
    required this.outputLines,
    required this.outputBytes,
    required this.lastLinePartial,
    required this.firstLineExceedsLimit,
    required this.maxLines,
    required this.maxBytes,
  });

  /// 截断后的内容。
  final String content;

  /// 是否发生了截断。
  final bool truncated;

  /// 命中的限制；未截断时为 null。
  final TruncatedBy? truncatedBy;
  final int totalLines;
  final int totalBytes;
  final int outputLines;
  final int outputBytes;

  /// 最后一行是否被部分截断（仅尾部截断边界情况）。
  final bool lastLinePartial;

  /// 首行是否超过字节限制（头部截断）。
  final bool firstLineExceedsLimit;
  final int maxLines;
  final int maxBytes;
}

class TruncationOptions {
  const TruncationOptions({this.maxLines, this.maxBytes});

  final int? maxLines;
  final int? maxBytes;
}

int _utf8ByteLength(String content) {
  return utf8.encode(content).length;
}

List<String> _splitLinesForCounting(String content) {
  if (content.isEmpty) {
    return const [];
  }
  final lines = content.split('\n');
  if (content.endsWith('\n')) {
    lines.removeLast();
  }
  return lines;
}

/// 字节数格式化为人类可读大小。
String formatSize(int bytes) {
  if (bytes < 1024) {
    return '${bytes}B';
  } else if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)}KB';
  } else {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

/// 头部截断（保留前 N 行/字节）。适合文件读取。
///
/// 绝不返回半行。首行超过字节限制时返回空内容并置
/// firstLineExceedsLimit=true。
TruncationResult truncateHead(
  String content, [
  TruncationOptions? options,
]) {
  final maxLines = options?.maxLines ?? defaultMaxLines;
  final maxBytes = options?.maxBytes ?? defaultMaxBytes;

  final totalBytes = _utf8ByteLength(content);
  final lines = _splitLinesForCounting(content);
  final totalLines = lines.length;

  if (totalLines <= maxLines && totalBytes <= maxBytes) {
    return TruncationResult(
      content: content,
      truncated: false,
      truncatedBy: null,
      totalLines: totalLines,
      totalBytes: totalBytes,
      outputLines: totalLines,
      outputBytes: totalBytes,
      lastLinePartial: false,
      firstLineExceedsLimit: false,
      maxLines: maxLines,
      maxBytes: maxBytes,
    );
  }

  final firstLineBytes = lines.isEmpty ? 0 : _utf8ByteLength(lines[0]);
  if (firstLineBytes > maxBytes) {
    return TruncationResult(
      content: '',
      truncated: true,
      truncatedBy: TruncatedBy.bytes,
      totalLines: totalLines,
      totalBytes: totalBytes,
      outputLines: 0,
      outputBytes: 0,
      lastLinePartial: false,
      firstLineExceedsLimit: true,
      maxLines: maxLines,
      maxBytes: maxBytes,
    );
  }

  final outputLinesArr = <String>[];
  var outputBytesCount = 0;
  var truncatedBy = TruncatedBy.lines;

  for (var i = 0; i < lines.length && i < maxLines; i++) {
    final line = lines[i];
    final lineBytes = _utf8ByteLength(line) + (i > 0 ? 1 : 0);

    if (outputBytesCount + lineBytes > maxBytes) {
      truncatedBy = TruncatedBy.bytes;
      break;
    }

    outputLinesArr.add(line);
    outputBytesCount += lineBytes;
  }

  if (outputLinesArr.length >= maxLines && outputBytesCount <= maxBytes) {
    truncatedBy = TruncatedBy.lines;
  }

  final outputContent = outputLinesArr.join('\n');
  final finalOutputBytes = _utf8ByteLength(outputContent);

  return TruncationResult(
    content: outputContent,
    truncated: true,
    truncatedBy: truncatedBy,
    totalLines: totalLines,
    totalBytes: totalBytes,
    outputLines: outputLinesArr.length,
    outputBytes: finalOutputBytes,
    lastLinePartial: false,
    firstLineExceedsLimit: false,
    maxLines: maxLines,
    maxBytes: maxBytes,
  );
}

/// 尾部截断（保留后 N 行/字节）。适合 bash 输出（要看结尾的错误/结果）。
///
/// 原内容最后一行超过字节限制时可能返回部分首行。
TruncationResult truncateTail(
  String content, [
  TruncationOptions? options,
]) {
  final maxLines = options?.maxLines ?? defaultMaxLines;
  final maxBytes = options?.maxBytes ?? defaultMaxBytes;

  final totalBytes = _utf8ByteLength(content);
  final lines = _splitLinesForCounting(content);
  final totalLines = lines.length;

  if (totalLines <= maxLines && totalBytes <= maxBytes) {
    return TruncationResult(
      content: content,
      truncated: false,
      truncatedBy: null,
      totalLines: totalLines,
      totalBytes: totalBytes,
      outputLines: totalLines,
      outputBytes: totalBytes,
      lastLinePartial: false,
      firstLineExceedsLimit: false,
      maxLines: maxLines,
      maxBytes: maxBytes,
    );
  }

  final outputLinesArr = <String>[];
  var outputBytesCount = 0;
  var truncatedBy = TruncatedBy.lines;
  var lastLinePartial = false;

  for (var i = lines.length - 1;
      i >= 0 && outputLinesArr.length < maxLines;
      i--) {
    final line = lines[i];
    final lineBytes =
        _utf8ByteLength(line) + (outputLinesArr.isNotEmpty ? 1 : 0);

    if (outputBytesCount + lineBytes > maxBytes) {
      truncatedBy = TruncatedBy.bytes;
      if (outputLinesArr.isEmpty) {
        final truncatedLine = _truncateStringToBytesFromEnd(line, maxBytes);
        outputLinesArr.insert(0, truncatedLine);
        outputBytesCount = _utf8ByteLength(truncatedLine);
        lastLinePartial = true;
      }
      break;
    }

    outputLinesArr.insert(0, line);
    outputBytesCount += lineBytes;
  }

  if (outputLinesArr.length >= maxLines && outputBytesCount <= maxBytes) {
    truncatedBy = TruncatedBy.lines;
  }

  final outputContent = outputLinesArr.join('\n');
  final finalOutputBytes = _utf8ByteLength(outputContent);

  return TruncationResult(
    content: outputContent,
    truncated: true,
    truncatedBy: truncatedBy,
    totalLines: totalLines,
    totalBytes: totalBytes,
    outputLines: outputLinesArr.length,
    outputBytes: finalOutputBytes,
    lastLinePartial: lastLinePartial,
    firstLineExceedsLimit: false,
    maxLines: maxLines,
    maxBytes: maxBytes,
  );
}

/// 把字符串截到字节上限内（从尾部保留），正确处理多字节 UTF-8。
String _truncateStringToBytesFromEnd(String str, int maxBytes) {
  if (maxBytes <= 0) {
    return '';
  }

  final bytes = utf8.encode(str);
  if (bytes.length <= maxBytes) {
    return str;
  }
  var start = bytes.length - maxBytes;
  while (start < bytes.length && (bytes[start] & 0xc0) == 0x80) {
    start++;
  }
  return utf8.decode(bytes.sublist(start), allowMalformed: true);
}

/// 把单行截到最大字符数并加 [truncated] 后缀（grep 匹配行用）。
({String text, bool wasTruncated}) truncateLine(
  String line, [
  int maxChars = grepMaxLineLength,
]) {
  if (line.length <= maxChars) {
    return (text: line, wasTruncated: false);
  }
  return (
    text: '${line.substring(0, maxChars)}... [truncated]',
    wasTruncated: true,
  );
}

/// 供 shell 捕获层复用的 UTF-8 编码探针。
Uint8List utf8EncodeBytes(String text) => Uint8List.fromList(utf8.encode(text));
