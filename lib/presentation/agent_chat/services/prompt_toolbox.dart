import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agent/agent_types.dart';
import '../../../data/models/character/character_prompt.dart';
import '../../providers/character_prompt_provider.dart';
import '../../providers/generation/generation_params_notifier.dart';
import '../../../core/agent/harness/harness_types.dart';

/// 定义式工具构造。
class DefinedAgentTool extends AgentTool {
  DefinedAgentTool({
    required super.name,
    required super.description,
    required super.parameters,
    required super.label,
    this.executionModeOverride,
    Future<AgentToolResult> Function(
      String toolCallId,
      Map<String, dynamic> params,
    )?
    executeFn,
    Future<AgentToolResult> Function(
      String toolCallId,
      Map<String, dynamic> params,
      AbortSignal? signal,
      AgentToolUpdateCallback? onUpdate,
    )?
    executeWithControl,
  }) : assert(
         executeFn != null || executeWithControl != null,
         'Provide executeFn or executeWithControl',
       ),
       _executeFn =
           executeFn ??
           ((toolCallId, params) async => AgentToolResult(
             content: const [ToolResultTextContent('Tool not configured.')],
             details: const <String, dynamic>{},
           )),
       _executeWithControl = executeWithControl;

  final ToolExecutionMode? executionModeOverride;
  final Future<AgentToolResult> Function(
    String toolCallId,
    Map<String, dynamic> params,
  ) _executeFn;

  /// 需要中止信号 / 流式进度反馈的工具提供此实现；缺省走 [_executeFn]。
  final Future<AgentToolResult> Function(
    String toolCallId,
    Map<String, dynamic> params,
    AbortSignal? signal,
    AgentToolUpdateCallback? onUpdate,
  )? _executeWithControl;

  @override
  ToolExecutionMode? get executionMode => executionModeOverride;

  @override
  Future<AgentToolResult> execute(
    String toolCallId,
    Map<String, dynamic> params, [
    AbortSignal? signal,
    AgentToolUpdateCallback? onUpdate,
  ]) {
    throwIfAborted(signal);
    final controlled = _executeWithControl;
    if (controlled != null) {
      return controlled(toolCallId, params, signal, onUpdate);
    }
    return _executeFn(toolCallId, params);
  }
}

AgentToolResult _textResult(String text) {
  return AgentToolResult(
    content: [ToolResultTextContent(text)],
    details: const <String, dynamic>{},
  );
}

AgentToolResult _errorResult(String text) {
  return AgentToolResult(
    content: [ToolResultTextContent(text)],
    details: const <String, dynamic>{},
  );
}

/// 提示词工具集。
///
/// 通过注入的 [Ref] 读写现有 Riverpod providers，任何改动都会即时
/// 反映到生成页 UI。
class PromptToolbox {
  PromptToolbox(this._ref, {Map<String, HarnessSkill>? skills})
    : _skills = skills ?? const {};

  final Ref _ref;
  final Map<String, HarnessSkill> _skills;

  List<AgentTool> tools() {
    return [
      DefinedAgentTool(
        name: 'get_prompt_state',
        label: 'Get Prompt State',
        description: 'Read the current NovelAI workspace state: positive '
            'prompt, negative prompt, current model, and the full character '
            'prompt list (id, name, gender, enabled, prompt, negative '
            'prompt). Call this before editing anything.',
        parameters: const {
          'type': 'object',
          'properties': <String, dynamic>{},
          'required': <String>[],
        },
        executeFn: (_, __) async {
          final params = _ref.read(generationParamsNotifierProvider);
          final characters = _ref
              .read(characterPromptNotifierProvider)
              .characters;
          return _textResult(
            jsonEncode({
              'model': params.model,
              'positive_prompt': params.prompt,
              'negative_prompt': params.negativePrompt,
              'characters': [
                for (final c in characters)
                  {
                    'id': c.id,
                    'name': c.name,
                    'gender': c.gender.name,
                    'enabled': c.enabled,
                    'prompt': c.prompt,
                    'negative_prompt': c.negativePrompt,
                  },
              ],
            }),
          );
        },
      ),
      DefinedAgentTool(
        name: 'set_positive_prompt',
        label: 'Set Positive Prompt',
        description: 'Write the main positive prompt. mode: "replace" '
            '(default), "append" (add at the end), or "prepend" (add at the '
            'beginning). Content should be English danbooru-style tags '
            'separated by commas. Use NovelAI emphasis syntax — {tag} / '
            '[tag] on every model, 1.3::tag :: numeric on V4+ — never '
            '(tag:1.2) which is Stable Diffusion syntax.',
        parameters: const {
          'type': 'object',
          'properties': {
            'text': {
              'type': 'string',
              'description': 'The prompt text or tags to write.',
            },
            'mode': {
              'type': 'string',
              'enum': ['replace', 'append', 'prepend'],
              'description': 'How to apply the text. Default: replace.',
            },
          },
          'required': ['text'],
        },
        executeFn: (_, params) async => _setPrompt(positive: true, args: params),
      ),
      DefinedAgentTool(
        name: 'set_negative_prompt',
        label: 'Set Negative Prompt',
        description: 'Write the negative prompt (Undesired Content). mode: '
            '"replace" (default), "append", or "prepend".',
        parameters: const {
          'type': 'object',
          'properties': {
            'text': {
              'type': 'string',
              'description': 'The negative prompt text or tags to write.',
            },
            'mode': {
              'type': 'string',
              'enum': ['replace', 'append', 'prepend'],
              'description': 'How to apply the text. Default: replace.',
            },
          },
          'required': ['text'],
        },
        executeFn: (_, params) async =>
            _setPrompt(positive: false, args: params),
      ),
      DefinedAgentTool(
        name: 'update_character',
        label: 'Update Character',
        description: 'Update an existing character prompt entry matched by id '
            'or name (case-insensitive). Only provided fields are changed. '
            'Set "enabled" to false to temporarily exclude the character '
            'from generation while keeping it in the list, and true to '
            'include it again — use this to toggle characters on/off. '
            'Characters only take effect on V4+ models.',
        parameters: const {
          'type': 'object',
          'properties': {
            'id': {'type': 'string', 'description': 'Character id.'},
            'name': {
              'type': 'string',
              'description':
                  'Character name to match (or new name when renaming).',
            },
            'new_name': {
              'type': 'string',
              'description': 'Rename the character.',
            },
            'gender': {'type': 'string', 'enum': ['female', 'male', 'other']},
            'prompt': {
              'type': 'string',
              'description': 'New positive prompt for the character.',
            },
            'negative_prompt': {
              'type': 'string',
              'description': 'New negative prompt for the character.',
            },
            'enabled': {
              'type': 'boolean',
              'description': 'true to include the character in generation, '
                  'false to disable it while keeping it in the list.',
            },
          },
          'required': <String>[],
        },
        executeFn: (_, params) => _updateCharacter(params),
      ),
      DefinedAgentTool(
        name: 'add_character',
        label: 'Add Character',
        description: 'Add a new character prompt entry (V4+ models support '
            'multiple characters; there is a model-dependent limit).',
        parameters: const {
          'type': 'object',
          'properties': {
            'name': {'type': 'string', 'description': 'Character display name.'},
            'gender': {
              'type': 'string',
              'enum': ['female', 'male', 'other'],
              'description': 'Default: female.',
            },
            'prompt': {
              'type': 'string',
              'description': 'Character positive prompt tags.',
            },
            'negative_prompt': {
              'type': 'string',
              'description': 'Character negative prompt tags.',
            },
          },
          'required': ['name'],
        },
        executeFn: (_, params) => _addCharacter(params),
      ),
      DefinedAgentTool(
        name: 'remove_character',
        label: 'Remove Character',
        description: 'Remove a character prompt entry matched by id or name.',
        parameters: const {
          'type': 'object',
          'properties': {
            'id': {'type': 'string'},
            'name': {'type': 'string'},
          },
          'required': <String>[],
        },
        executeFn: (_, params) => _removeCharacter(params),
      ),
      if (_skills.isNotEmpty)
        DefinedAgentTool(
          name: 'read_skill',
          label: 'Read Skill',
          description: 'Read the full instructions of an available skill '
              'listed in the system prompt. Returns the SKILL.md content.',
          parameters: const {
            'type': 'object',
            'properties': {
              'name': {'type': 'string', 'description': 'Skill name.'},
            },
            'required': ['name'],
          },
          executeFn: (_, params) => _readSkill(params),
        ),
    ];
  }

  Future<AgentToolResult> _setPrompt({
    required bool positive,
    required Map<String, dynamic> args,
  }) async {
    final text = (args['text'] as String?)?.trim() ?? '';
    if (text.isEmpty) {
      return _errorResult('Parameter "text" must be a non-empty string.');
    }
    final mode = (args['mode'] as String?) ?? 'replace';
    final params = _ref.read(generationParamsNotifierProvider);
    final current = positive ? params.prompt : params.negativePrompt;
    final combined = combinePromptText(current, text, mode);

    final notifier = _ref.read(generationParamsNotifierProvider.notifier);
    if (positive) {
      notifier.updatePrompt(combined);
    } else {
      notifier.updateNegativePrompt(combined);
    }
    // updatePrompt 内部经 Future.microtask 写入 state，冲刷微任务队列后
    // 再回读，保证返回给模型的是已生效的值。
    await Future<void>.delayed(Duration.zero);
    final applied = _ref.read(generationParamsNotifierProvider);
    return _textResult(
      jsonEncode({
        'ok': true,
        positive ? 'positive_prompt' : 'negative_prompt':
            positive ? applied.prompt : applied.negativePrompt,
      }),
    );
  }

  CharacterPrompt? _findCharacter({String? id, String? name}) {
    final characters = _ref.read(characterPromptNotifierProvider).characters;
    if (id != null && id.trim().isNotEmpty) {
      final byId = characters.where((c) => c.id == id.trim()).toList();
      if (byId.isNotEmpty) {
        return byId.first;
      }
    }
    if (name != null && name.trim().isNotEmpty) {
      final lowered = name.trim().toLowerCase();
      final byName = characters
          .where((c) => c.name.trim().toLowerCase() == lowered)
          .toList();
      if (byName.isNotEmpty) {
        return byName.first;
      }
    }
    return null;
  }

  Future<AgentToolResult> _updateCharacter(Map<String, dynamic> args) async {
    final target = _findCharacter(
      id: args['id'] as String?,
      name: args['name'] as String?,
    );
    if (target == null) {
      return _errorResult(
        'Character not found. Call get_prompt_state to list valid ids and '
        'names.',
      );
    }
    var updated = target;
    final newName = (args['new_name'] as String?)?.trim();
    if (newName != null && newName.isNotEmpty) {
      updated = updated.copyWith(name: newName);
    }
    final gender = _parseGender(args['gender']);
    if (gender != null) {
      updated = updated.copyWith(gender: gender);
    }
    if (args.containsKey('prompt')) {
      updated = updated.copyWith(prompt: (args['prompt'] as String?) ?? '');
    }
    if (args.containsKey('negative_prompt')) {
      updated = updated.copyWith(
        negativePrompt: (args['negative_prompt'] as String?) ?? '',
      );
    }
    if (args.containsKey('enabled')) {
      updated = updated.copyWith(enabled: args['enabled'] as bool? ?? true);
    }
    _ref
        .read(characterPromptNotifierProvider.notifier)
        .updateCharacter(updated);
    await Future<void>.delayed(Duration.zero);
    return _textResult(
      jsonEncode({
        'ok': true,
        'character': {
          'id': updated.id,
          'name': updated.name,
          'prompt': updated.prompt,
          'negative_prompt': updated.negativePrompt,
          'enabled': updated.enabled,
        },
      }),
    );
  }

  Future<AgentToolResult> _addCharacter(Map<String, dynamic> args) async {
    final name = (args['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) {
      return _errorResult('Parameter "name" is required.');
    }
    final notifier = _ref.read(characterPromptNotifierProvider.notifier);
    final limit = notifier.characterLimit;
    final count = _ref.read(characterPromptNotifierProvider).characters.length;
    if (limit > 0 && count >= limit) {
      return _errorResult(
        'Character limit reached ($limit). Remove one first.',
      );
    }
    notifier.addCharacter(
      _parseGender(args['gender']) ?? CharacterGender.female,
      name: name,
      prompt: (args['prompt'] as String?) ?? '',
    );
    await Future<void>.delayed(Duration.zero);
    // addCharacter 生成默认负向后补充传入的负向词。
    if (args.containsKey('negative_prompt')) {
      final negative = (args['negative_prompt'] as String?) ?? '';
      final created = _findCharacter(name: name);
      if (created != null && negative.isNotEmpty) {
        _ref
            .read(characterPromptNotifierProvider.notifier)
            .updateCharacter(created.copyWith(negativePrompt: negative));
      }
    }
    final created = _findCharacter(name: name);
    return _textResult(
      jsonEncode({
        'ok': true,
        'character': {
          if (created != null) 'id': created.id,
          'name': name,
        },
      }),
    );
  }

  Future<AgentToolResult> _removeCharacter(Map<String, dynamic> args) async {
    final target = _findCharacter(
      id: args['id'] as String?,
      name: args['name'] as String?,
    );
    if (target == null) {
      return _errorResult('Character not found.');
    }
    _ref
        .read(characterPromptNotifierProvider.notifier)
        .removeCharacter(target.id);
    await Future<void>.delayed(Duration.zero);
    return _textResult(jsonEncode({'ok': true, 'removed': target.name}));
  }

  Future<AgentToolResult> _readSkill(Map<String, dynamic> args) async {
    final name = (args['name'] as String?)?.trim() ?? '';
    final skill = _skills[name];
    if (skill == null) {
      final available = _skills.keys.toList()..sort();
      return _errorResult(
        'Skill "$name" not found. Available skills: ${available.join(', ')}.',
      );
    }
    // 代理 的 Skill.content 即 SKILL.md 正文（加载时已剥离 frontmatter）。
    final content = skill.content;
    return _textResult(content.isEmpty ? '(empty)' : content);
  }

  CharacterGender? _parseGender(dynamic raw) {
    switch (raw) {
      case 'female':
        return CharacterGender.female;
      case 'male':
        return CharacterGender.male;
      case 'other':
        return CharacterGender.other;
      default:
        return null;
    }
  }
}

/// 按 NAI 逗号分隔习惯合并提示词文本。
String combinePromptText(String current, String addition, String mode) {
  final cur = current.trim();
  final add = addition.trim();
  switch (mode) {
    case 'append':
      if (cur.isEmpty) {
        return add;
      }
      return '$cur, $add';
    case 'prepend':
      if (cur.isEmpty) {
        return add;
      }
      return '$add, $cur';
    default:
      return add;
  }
}
