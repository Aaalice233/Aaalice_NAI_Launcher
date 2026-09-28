import 'dart:convert';

import '../../agent_types.dart';
import '../harness_types.dart';
import 'edit_diff.dart';
import 'file_mutation_queue.dart';
import 'path_utils.dart';

/// 精确文本替换编辑工具。
///
/// 每个编辑项的 oldText 必须在原文件中唯一且互不重叠；相邻/重叠的
/// 变更应合并为单个编辑。写回时保留 BOM 与原文件行尾风格，并生成
/// 展示 diff 与 unified patch 供 UI 呈现。

class EditToolDetails {
  const EditToolDetails({
    required this.diff,
    required this.patch,
    this.firstChangedLine,
  });

  final String diff;
  final String patch;
  final int? firstChangedLine;
}

bool _isSingleEditInput(dynamic value) {
  if (value is! Map) {
    return false;
  }
  return value['oldText'] is String && value['newText'] is String;
}

/// 参数整流：字符串形态的 edits 尝试 JSON 解析；单编辑对象包成数组；
/// 兼容旧版顶层 oldText/newText 入参（合并进 edits）。
Map<String, dynamic> prepareEditArguments(Map<String, dynamic> input) {
  final args = Map<String, dynamic>.of(input);
  if (args['edits'] is String) {
    try {
      final parsed = jsonDecode(args['edits'] as String);
      if (parsed is List) {
        args['edits'] = parsed;
      } else if (_isSingleEditInput(parsed)) {
        args['edits'] = [parsed];
      }
    } catch (_) {
      // 保持原样，交由 schema 校验报错。
    }
  } else if (_isSingleEditInput(args['edits'])) {
    args['edits'] = [args['edits']];
  }

  final oldText = args['oldText'];
  final newText = args['newText'];
  if (oldText is! String || newText is! String) {
    return args;
  }
  final edits = args['edits'] is List
      ? List.of(args['edits'] as List)
      : <dynamic>[];
  edits.add({'oldText': oldText, 'newText': newText});
  args.remove('oldText');
  args.remove('newText');
  args['edits'] = edits;
  return args;
}

({String path, List<Edit> edits}) _validateEditInput(
  Map<String, dynamic> input,
) {
  final rawEdits = input['edits'];
  if (rawEdits is! List || rawEdits.isEmpty) {
    throw StateError(
      'Edit tool input is invalid. edits must contain at least one '
      'replacement.',
    );
  }
  return (
    path: input['path'] as String,
    edits: [
      for (final edit in rawEdits)
        Edit(
          oldText: (edit as Map)['oldText'] as String? ?? '',
          newText: edit['newText'] as String? ?? '',
        ),
    ],
  );
}

StateError _editAccessError(String path, FileError error) {
  return StateError(
    'Could not edit file: $path. Error code: ${error.code.name}. '
    '(${error.message})',
  );
}

class EditHarnessTool extends AgentHarnessTool {
  EditHarnessTool()
    : super(
        name: 'edit',
        label: 'edit',
        description:
            'Edit a single file using exact text replacement. Every '
            "edits[].oldText must match a unique, non-overlapping region of "
            'the original file. If two changes affect the same block or '
            'nearby lines, merge them into one edit instead of emitting '
            'overlapping edits. Do not include large unchanged regions just '
            'to connect distant changes.',
        parameters: const {
          'type': 'object',
          'properties': {
            'path': {
              'type': 'string',
              'description':
                  'Path to the file to edit (relative or absolute)',
            },
            'edits': {
              'type': 'array',
              'description':
                  'One or more targeted replacements. Each edit is matched '
                  'against the original file, not incrementally. Do not '
                  'include overlapping or nested edits. If two changes touch '
                  'the same block or nearby lines, merge them into one edit '
                  'instead.',
              'items': {
                'type': 'object',
                'properties': {
                  'oldText': {
                    'type': 'string',
                    'description':
                        'Exact text for one targeted replacement. It must be '
                        'unique in the original file and must not overlap with '
                        'any other edits[].oldText in the same call.',
                  },
                  'newText': {
                    'type': 'string',
                    'description': 'Replacement text for this targeted edit.',
                  },
                },
                'required': ['oldText', 'newText'],
              },
            },
          },
          'required': ['path', 'edits'],
        },
      );

  @override
  Map<String, dynamic> prepareArguments(Map<String, dynamic> args) {
    return prepareEditArguments(args);
  }

  @override
  Future<AgentToolResult> executeWithContext(
    String toolCallId,
    Map<String, dynamic> params, [
    AbortSignal? signal,
    AgentToolUpdateCallback? onUpdate,
    dynamic context,
  ]) async {
    final input = _validateEditInput(params);
    final path = input.path;
    final edits = input.edits;
    final env = (context as ExecutionToolContext).env;

    final absolutePath = await resolveToolPath(env, path, signal);
    return withFileMutationQueue(env, absolutePath, () async {
      if (signal?.aborted == true) {
        throw StateError('Operation aborted');
      }
      final info = await env.fileInfo(absolutePath, signal);
      final infoValue = info.valueOrNull;
      if (infoValue == null) {
        throw _editAccessError(path, info.errorOrNull!);
      }
      if (infoValue.kind != FileKind.file &&
          infoValue.kind != FileKind.symlink) {
        throw StateError('Could not edit file: $path. Path is not a file.');
      }

      final readResult = await env.readTextFile(absolutePath, signal);
      final readValue = readResult.valueOrNull;
      if (readValue == null) {
        throw _editAccessError(path, readResult.errorOrNull!);
      }
      if (signal?.aborted == true) {
        throw StateError('Operation aborted');
      }

      final bomAndText = stripBom(readValue);
      final bom = bomAndText.$1;
      final content = bomAndText.$2;
      final originalEnding = detectLineEnding(content);
      final normalizedContent = normalizeToLF(content);
      final applied = applyEditsToNormalizedContent(
        normalizedContent,
        edits,
        path,
      );
      if (signal?.aborted == true) {
        throw StateError('Operation aborted');
      }

      final finalContent =
          bom + restoreLineEndings(applied.newContent, originalEnding);
      final writeResult = await env.writeFile(
        absolutePath,
        finalContent,
        signal,
      );
      final writeError = writeResult.errorOrNull;
      if (writeError != null) {
        throw _editAccessError(path, writeError);
      }
      if (signal?.aborted == true) {
        throw StateError('Operation aborted');
      }

      final diffResult =
          generateDiffString(applied.baseContent, applied.newContent);
      return AgentToolResult(
        content: [
          ToolResultTextContent(
            'Successfully replaced ${edits.length} block(s) in $path.',
          ),
        ],
        details: EditToolDetails(
          diff: diffResult.diff,
          patch: generateUnifiedPatch(
            path,
            applied.baseContent,
            applied.newContent,
          ),
          firstChangedLine: diffResult.firstChangedLine,
        ),
      );
    });
  }
}

/// 创建精确文本替换编辑工具。
AgentHarnessTool createEditTool() {
  return EditHarnessTool();
}
