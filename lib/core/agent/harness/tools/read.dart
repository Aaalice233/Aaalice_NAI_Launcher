import 'dart:convert';
import 'dart:typed_data';

import '../../agent_types.dart';
import '../harness_types.dart';
import '../utils/truncate.dart';
import 'image.dart';
import 'path_utils.dart';

const int defaultMaxReadFileBytes = 20 * 1024 * 1024;

class ReadToolDetails {
  const ReadToolDetails({this.truncation});

  final TruncationResult? truncation;
}

class ReadImageProcessorResult {
  const ReadImageProcessorResult.ok({
    required this.data,
    required this.mimeType,
    required this.hints,
  }) : message = null;

  const ReadImageProcessorResult.fail(this.message)
    : data = '',
      mimeType = '',
      hints = const [];

  final String? message;
  final String data;
  final String mimeType;
  final List<String> hints;

  bool get ok => message == null;
}

typedef ReadImageProcessor =
    Future<ReadImageProcessorResult> Function(
      List<int> bytes,
      String mimeType,
      ({bool autoResizeImages}) options,
    );

class ReadToolOptions {
  const ReadToolOptions({
    this.autoResizeImages = true,
    this.imageProcessor,
    this.maxFileBytes = defaultMaxReadFileBytes,
  });

  /// 注入的图片处理器是否应缩放图片。默认 true。
  final bool autoResizeImages;

  /// 可选的图片转换/缩放实现。
  final ReadImageProcessor? imageProcessor;

  /// 单次读取的硬上限，避免在截断输出前把任意大的文件载入内存。
  final int maxFileBytes;
}

class ReadHarnessTool extends AgentHarnessTool {
  ReadHarnessTool({this.options})
    : super(
        name: 'read',
        label: 'read',
        description:
            'Read the contents of a file. Supports text files and images '
            '(jpg, png, gif, webp, bmp). Images are sent as attachments. For '
            'text files, output is truncated to $defaultMaxLines lines or '
            '${defaultMaxBytes ~/ 1024}KB (whichever is hit first). Use '
            'offset/limit for large files. When you need the full file, '
            'continue with offset until complete.',
        parameters: const {
          'type': 'object',
          'properties': {
            'path': {
              'type': 'string',
              'description': 'Path to the file to read (relative or absolute)',
            },
            'offset': {
              'type': 'number',
              'description': 'Line number to start reading from (1-indexed)',
            },
            'limit': {
              'type': 'number',
              'description': 'Maximum number of lines to read',
            },
            'character_offset': {
              'type': 'number',
              'description':
                  'Zero-based Unicode character offset within the first '
                  'selected line. Use this to continue a very long line.',
            },
          },
          'required': ['path'],
        },
      );

  final ReadToolOptions? options;

  @override
  Future<AgentToolResult> executeWithContext(
    String toolCallId,
    Map<String, dynamic> params, [
    AbortSignal? signal,
    AgentToolUpdateCallback? onUpdate,
    dynamic context,
  ]) async {
    final env = (context as ExecutionToolContext).env;
    final path = params['path'] as String;
    final offset = (params['offset'] as num?)?.toInt();
    final limit = (params['limit'] as num?)?.toInt();
    final characterOffset = (params['character_offset'] as num?)?.toInt();
    if (characterOffset != null && characterOffset < 0) {
      throw StateError('character_offset must be at least 0');
    }

    final absolutePath = await resolveReadToolPath(env, path, signal);
    final maxFileBytes = options?.maxFileBytes ?? defaultMaxReadFileBytes;
    final info = getOrThrow(await env.fileInfo(absolutePath, signal));
    if (maxFileBytes > 0 && info.size > maxFileBytes) {
      throw StateError(
        'File is ${formatSize(info.size)}, exceeds the '
        '${formatSize(maxFileBytes)} read limit.',
      );
    }
    final bytesResult = await env.readBinaryFile(absolutePath, signal);
    final bytes = Uint8List.fromList(getOrThrow(bytesResult));
    final mimeType = detectSupportedImageMimeType(bytes);
    if (mimeType != null) {
      final processor = options?.imageProcessor;
      if (processor != null) {
        final processed = await processor(bytes, mimeType, (
          autoResizeImages: options?.autoResizeImages ?? true,
        ));
        if (!processed.ok) {
          return AgentToolResult(
            content: [
              ToolResultTextContent(
                'Read image file [$mimeType]\n${processed.message}',
              ),
            ],
            details: null,
            isError: true,
          );
        }
        final hints = processed.hints.isNotEmpty
            ? '\n${processed.hints.join('\n')}'
            : '';
        return AgentToolResult(
          content: [
            ToolResultTextContent(
              'Read image file [${processed.mimeType}]$hints',
            ),
            ToolResultImageContent(
              ImageContent(
                source: ImageSource.base64(
                  mimeType: processed.mimeType,
                  base64Data: processed.data,
                ),
              ),
            ),
          ],
          details: <String, dynamic>{
            'files': [absolutePath],
          },
        );
      }
      if (mimeType == 'image/bmp') {
        return AgentToolResult(
          content: [
            const ToolResultTextContent(
              'Read image file [image/bmp]\n[Image omitted: configure an '
              'imageProcessor to convert BMP images.]',
            ),
          ],
          details: null,
          isError: true,
        );
      }
      return AgentToolResult(
        content: [
          ToolResultTextContent('Read image file [$mimeType]'),
          ToolResultImageContent(
            ImageContent(
              source: ImageSource.base64(
                mimeType: mimeType,
                base64Data: encodeBase64ImageBytes(bytes),
              ),
            ),
          ),
        ],
        details: <String, dynamic>{
          'files': [absolutePath],
        },
      );
    }

    final textContent = utf8.decode(bytes, allowMalformed: true);
    final allLines = textContent.split('\n');
    final totalFileLines = allLines.length;
    final startLine = offset != null && offset > 0 ? offset - 1 : 0;
    final startLineDisplay = startLine + 1;
    if (startLine >= allLines.length) {
      throw StateError(
        'Offset $offset is beyond end of file (${allLines.length} lines total)',
      );
    }

    if (characterOffset != null) {
      return AgentToolResult(
        content: [
          ToolResultTextContent(
            _longLineChunk(
              allLines[startLine],
              lineNumber: startLineDisplay,
              characterOffset: characterOffset,
            ),
          ),
        ],
        details: null,
      );
    }

    String selectedContent;
    int? userLimitedLines;
    if (limit != null) {
      final endLine = (startLine + limit) < allLines.length
          ? startLine + limit
          : allLines.length;
      selectedContent = allLines.sublist(startLine, endLine).join('\n');
      userLimitedLines = endLine - startLine;
    } else {
      selectedContent = allLines.sublist(startLine).join('\n');
    }

    final truncation = truncateHead(selectedContent);
    String outputText;
    ReadToolDetails? details;
    if (truncation.firstLineExceedsLimit) {
      outputText = _longLineChunk(
        allLines[startLine],
        lineNumber: startLineDisplay,
        characterOffset: 0,
      );
      details = ReadToolDetails(truncation: truncation);
    } else if (truncation.truncated) {
      final endLineDisplay = startLineDisplay + truncation.outputLines - 1;
      final nextOffset = endLineDisplay + 1;
      outputText = truncation.content;
      if (truncation.truncatedBy == TruncatedBy.lines) {
        outputText +=
            '\n\n[Showing lines $startLineDisplay-$endLineDisplay of '
            '$totalFileLines. Use offset=$nextOffset to continue.]';
      } else {
        outputText +=
            '\n\n[Showing lines $startLineDisplay-$endLineDisplay of '
            '$totalFileLines (${formatSize(defaultMaxBytes)} limit). Use '
            'offset=$nextOffset to continue.]';
      }
      details = ReadToolDetails(truncation: truncation);
    } else if (userLimitedLines != null &&
        startLine + userLimitedLines < allLines.length) {
      final remaining = allLines.length - (startLine + userLimitedLines);
      final nextOffset = startLine + userLimitedLines + 1;
      outputText =
          '${truncation.content}\n\n[$remaining more lines in file. Use '
          'offset=$nextOffset to continue.]';
    } else {
      outputText = truncation.content;
    }

    return AgentToolResult(
      content: [ToolResultTextContent(outputText)],
      details: details,
    );
  }
}

String _longLineChunk(
  String line, {
  required int lineNumber,
  required int characterOffset,
}) {
  final characters = line.runes.toList(growable: false);
  if (characterOffset >= characters.length) {
    throw StateError(
      'character_offset $characterOffset is beyond end of line '
      '$lineNumber (${characters.length} characters total)',
    );
  }
  final selected = <int>[];
  var selectedBytes = 0;
  for (var index = characterOffset; index < characters.length; index++) {
    final character = characters[index];
    final byteLength = utf8.encode(String.fromCharCode(character)).length;
    if (selected.isNotEmpty && selectedBytes + byteLength > defaultMaxBytes) {
      break;
    }
    selected.add(character);
    selectedBytes += byteLength;
  }
  final content = String.fromCharCodes(selected);
  final nextOffset = characterOffset + selected.length;
  if (nextOffset >= characters.length) {
    return content;
  }
  return '$content\n\n[Showing characters ${characterOffset + 1}-$nextOffset '
      'of line $lineNumber (${characters.length} total). Use '
      'offset=$lineNumber and character_offset=$nextOffset to continue.]';
}

AgentHarnessTool createReadTool([ReadToolOptions? options]) {
  return ReadHarnessTool(options: options);
}
