import 'dart:convert';
import 'dart:typed_data';

import '../../agent_types.dart';
import '../harness_types.dart';
import '../utils/truncate.dart';
import 'image.dart';
import 'path_utils.dart';


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

typedef ReadImageProcessor = Future<ReadImageProcessorResult> Function(
  List<int> bytes,
  String mimeType,
  ({bool autoResizeImages}) options,
);

class ReadToolOptions {
  const ReadToolOptions({this.autoResizeImages = true, this.imageProcessor});

  /// 注入的图片处理器是否应缩放图片。默认 true。
  final bool autoResizeImages;

  /// 可选的图片转换/缩放实现。
  final ReadImageProcessor? imageProcessor;
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
              'description':
                  'Path to the file to read (relative or absolute)',
            },
            'offset': {
              'type': 'number',
              'description':
                  'Line number to start reading from (1-indexed)',
            },
            'limit': {
              'type': 'number',
              'description': 'Maximum number of lines to read',
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

    final absolutePath = await resolveReadToolPath(env, path, signal);
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
          details: null,
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
        details: null,
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
      final firstLineSize = formatSize(
        utf8.encode(allLines[startLine]).length,
      );
      outputText =
          '[Line $startLineDisplay is $firstLineSize, exceeds '
          '${formatSize(defaultMaxBytes)} limit. Use bash: sed -n '
          "'${startLineDisplay}p' $path | head -c $defaultMaxBytes]";
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

AgentHarnessTool createReadTool([ReadToolOptions? options]) {
  return ReadHarnessTool(options: options);
}
