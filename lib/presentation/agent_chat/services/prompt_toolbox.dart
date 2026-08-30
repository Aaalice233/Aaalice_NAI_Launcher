import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/harness/env/dart_io_execution_env.dart';
import '../../../core/agent/harness/harness_types.dart';
import '../../../data/models/character/character_prompt.dart';
import '../../providers/character_prompt_provider.dart';
import '../../providers/generation/generation_params_notifier.dart';
import 'defined_agent_tool.dart';
import '../../../core/agent/harness/skills.dart';
import '../../../core/agent/private_data_guard.dart';
import '../../../core/constants/model_capabilities.dart';

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
    isError: true,
  );
}

/// 提示词工具集。
///
/// 通过注入的 [Ref] 读写现有 Riverpod providers，任何改动都会即时
/// 反映到生成页 UI。
class PromptToolbox {
  PromptToolbox(
    this._ref, {
    Map<String, HarnessSkill>? skills,
    List<SkillDiagnostic>? skillDiagnostics,
    Future<int> Function()? reloadSkills,
  }) : _skills = skills ?? const {},
       _skillDiagnostics = skillDiagnostics ?? const [],
       _reloadSkills = reloadSkills;

  final Ref _ref;
  final Map<String, HarnessSkill> _skills;
  final List<SkillDiagnostic> _skillDiagnostics;
  final Future<int> Function()? _reloadSkills;

  List<AgentTool> tools() {
    return [
      DefinedAgentTool(
        name: 'get_prompt_state',
        label: 'Get Prompt State',
        description:
            'Read the complete NovelAI prompt and character orchestration '
            'state. Returns stable character IDs, exact order, independent '
            'positive/negative prompts, enabled state, per-character saved '
            'position mode and continuous x/y centers, global AI/custom '
            'layout mode, current model, and its effective character limit. '
            'Call this before editing anything.',
        parameters: const {
          'type': 'object',
          'properties': <String, dynamic>{},
          'required': <String>[],
        },
        executeFn: (_, __) async {
          final params = _ref.read(generationParamsNotifierProvider);
          final config = _ref.read(characterPromptNotifierProvider);
          final capabilities = ModelCapabilityRegistry.of(params.model);
          return _textResult(
            jsonEncode({
              'model': params.model,
              'model_character_limit': capabilities.maxCharacters,
              'supports_characters': capabilities.maxCharacters > 0,
              'character_layout_mode': config.globalAiChoice
                  ? 'ai_choice'
                  : 'custom',
              'positive_prompt': params.prompt,
              'negative_prompt': params.negativePrompt,
              'characters': [
                for (var index = 0; index < config.characters.length; index++)
                  _characterJson(config.characters[index], order: index),
              ],
            }),
          );
        },
      ),
      DefinedAgentTool(
        name: 'set_positive_prompt',
        label: 'Set Positive Prompt',
        description:
            'Write the main positive prompt. mode: "replace" '
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
        executeFn: (_, params) async =>
            _setPrompt(positive: true, args: params),
      ),
      DefinedAgentTool(
        name: 'set_negative_prompt',
        label: 'Set Negative Prompt',
        description:
            'Write the negative prompt (Undesired Content). mode: '
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
        description:
            'Update one character matched by stable id or case-insensitive '
            'name. Only provided fields change. position_mode ai_choice '
            'keeps any saved custom point but lets AI choose while the global '
            'layout is AI. position_mode custom may reuse the saved point or '
            'accept both position_x and position_y. x is left-to-right and y '
            'is top-to-bottom; both must be finite values from 0 to 1.',
        parameters: const {
          'type': 'object',
          'properties': {
            'id': {'type': 'string', 'description': 'Stable character ID.'},
            'name': {
              'type': 'string',
              'description': 'Existing character name to match.',
            },
            'new_name': {'type': 'string', 'description': 'New display name.'},
            'gender': {
              'type': 'string',
              'enum': ['female', 'male', 'other'],
            },
            'prompt': {'type': 'string'},
            'negative_prompt': {'type': 'string'},
            'enabled': {'type': 'boolean'},
            'position_mode': {
              'type': 'string',
              'enum': ['ai_choice', 'custom'],
            },
            'position_x': {
              'type': 'number',
              'minimum': 0,
              'maximum': 1,
              'description': 'Horizontal center: 0 left, 1 right.',
            },
            'position_y': {
              'type': 'number',
              'minimum': 0,
              'maximum': 1,
              'description': 'Vertical center: 0 top, 1 bottom.',
            },
          },
          'required': <String>[],
        },
        executeFn: (_, params) => _updateCharacter(params),
      ),
      DefinedAgentTool(
        name: 'add_character',
        label: 'Add Character',
        description:
            'Add one ordered character using the current model limit. Optional '
            'custom coordinates require both axes (x left-to-right, y '
            'top-to-bottom, finite 0..1). ai_choice conflicts with coordinates.',
        parameters: const {
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
            'gender': {
              'type': 'string',
              'enum': ['female', 'male', 'other'],
              'description': 'Default: female.',
            },
            'prompt': {'type': 'string'},
            'negative_prompt': {'type': 'string'},
            'enabled': {'type': 'boolean'},
            'position_mode': {
              'type': 'string',
              'enum': ['ai_choice', 'custom'],
            },
            'position_x': {'type': 'number', 'minimum': 0, 'maximum': 1},
            'position_y': {'type': 'number', 'minimum': 0, 'maximum': 1},
          },
          'required': ['name'],
        },
        executeFn: (_, params) => _addCharacter(params),
      ),
      DefinedAgentTool(
        name: 'set_character_layout_mode',
        label: 'Set Character Layout Mode',
        description:
            'Switch the whole scene between NovelAI AI placement and custom '
            'continuous coordinates. Switching to custom assigns stable, '
            'non-overlapping defaults only where needed. Switching to AI '
            'preserves every saved custom point for later restoration.',
        parameters: const {
          'type': 'object',
          'properties': {
            'mode': {
              'type': 'string',
              'enum': ['ai_choice', 'custom'],
            },
          },
          'required': ['mode'],
        },
        executeFn: (_, params) => _setCharacterLayoutMode(params),
      ),
      DefinedAgentTool(
        name: 'reorder_characters',
        label: 'Reorder Characters',
        description:
            'Set the exact character order using stable IDs. ordered_ids must '
            'contain every current character ID exactly once.',
        parameters: const {
          'type': 'object',
          'properties': {
            'ordered_ids': {
              'type': 'array',
              'items': {'type': 'string'},
            },
          },
          'required': ['ordered_ids'],
        },
        executeFn: (_, params) => _reorderCharacters(params),
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
      DefinedAgentTool(
        name: 'clear_characters',
        label: 'Clear Characters',
        description: 'Remove every character from the current scene.',
        parameters: const {
          'type': 'object',
          'properties': <String, dynamic>{},
          'required': <String>[],
        },
        executeFn: (_, params) => _clearCharacters(),
      ),
      if (_skills.isNotEmpty)
        DefinedAgentTool(
          name: 'read_skill',
          label: 'Read Skill',
          description:
              'Read the full instructions of an available skill '
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
      if (_skills.isNotEmpty)
        DefinedAgentTool(
          name: 'read_skill_resource',
          label: 'Read Skill Resource',
          description:
              'Read a text reference, template, or script belonging to an '
              'available skill. The relative path is strictly confined to '
              'that skill directory. Use offset and limit for long files.',
          parameters: const {
            'type': 'object',
            'properties': {
              'name': {'type': 'string', 'description': 'Skill name.'},
              'path': {
                'type': 'string',
                'description': 'Path relative to the skill directory.',
              },
              'offset': {
                'type': 'integer',
                'minimum': 0,
                'description': 'Zero-based starting line. Default 0.',
              },
              'limit': {
                'type': 'integer',
                'minimum': 1,
                'maximum': 1000,
                'description': 'Maximum lines to return, 1-1000. Default 200.',
              },
            },
            'required': ['name', 'path'],
          },
          executeFn: (_, params) => _readSkillResource(params),
        ),
      DefinedAgentTool(
        name: 'get_skill_diagnostics',
        label: 'Get Skill Diagnostics',
        description:
            'List warnings from the latest skill discovery pass, including '
            'invalid metadata and unreadable files.',
        parameters: const {
          'type': 'object',
          'properties': <String, dynamic>{},
          'required': <String>[],
        },
        executeFn: (_, __) async => _textResult(
          jsonEncode({
            'count': _skillDiagnostics.length,
            'diagnostics': [
              for (final diagnostic in _skillDiagnostics)
                {
                  'code': diagnostic.code.name,
                  'message': PrivateDataGuard.redactAbsolutePaths(
                    diagnostic.message,
                  ),
                  'path': _agentSafePath(diagnostic.path),
                },
            ],
          }),
        ),
      ),
      if (_reloadSkills != null)
        DefinedAgentTool(
          name: 'reload_skills',
          label: 'Reload Skills',
          description:
              'Rediscover skills from workspace and user-global directories. '
              'The refreshed inventory and tools apply to subsequent model '
              'turns.',
          parameters: const {
            'type': 'object',
            'properties': <String, dynamic>{},
            'required': <String>[],
          },
          executeFn: (_, __) async {
            final count = await _reloadSkills();
            final available = _skills.keys.toList()..sort();
            return _textResult(
              jsonEncode({
                'ok': true,
                'count': count,
                'skills': available,
                'diagnostic_count': _skillDiagnostics.length,
              }),
            );
          },
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
        positive ? 'positive_prompt' : 'negative_prompt': positive
            ? applied.prompt
            : applied.negativePrompt,
      }),
    );
  }

  CharacterPrompt? _findCharacter({String? id, String? name}) {
    final characters = _ref.read(characterPromptNotifierProvider).characters;
    final normalizedId = id?.trim() ?? '';
    final normalizedName = name?.trim().toLowerCase() ?? '';

    if (normalizedId.isNotEmpty) {
      final byId = characters.where((c) => c.id == normalizedId).firstOrNull;
      if (byId == null) return null;
      if (normalizedName.isNotEmpty &&
          byId.name.trim().toLowerCase() != normalizedName) {
        throw const _PromptToolValidationException(
          'invalid_character_selector',
          'The supplied character id and name identify different characters.',
        );
      }
      return byId;
    }

    if (normalizedName.isNotEmpty) {
      final byName = characters
          .where((c) => c.name.trim().toLowerCase() == normalizedName)
          .toList();
      if (byName.length > 1) {
        throw const _PromptToolValidationException(
          'invalid_character_selector',
          'Character name is ambiguous. Call get_prompt_state and use a stable id.',
        );
      }
      return byName.firstOrNull;
    }
    return null;
  }

  Future<AgentToolResult> _updateCharacter(Map<String, dynamic> args) async {
    late final CharacterPrompt? target;
    late final _CharacterPositionChange positionChange;
    try {
      _validateCharacterStringFields(args);
      target = _findCharacter(
        id: args['id'] as String?,
        name: args['name'] as String?,
      );
      positionChange = _parsePositionChange(args);
    } on _PromptToolValidationException catch (error) {
      return agentToolError(error.code, error.message);
    }
    if (target == null) {
      return agentToolError(
        'character_not_found',
        'Character not found. Call get_prompt_state for stable IDs.',
      );
    }

    var updated = target;
    final newName = (args['new_name'] as String?)?.trim();
    if (newName != null && newName.isNotEmpty) {
      updated = updated.copyWith(name: newName);
    }
    final gender = _parseGender(args['gender']);
    if (gender != null) updated = updated.copyWith(gender: gender);
    if (args.containsKey('prompt')) {
      updated = updated.copyWith(prompt: (args['prompt'] as String?) ?? '');
    }
    if (args.containsKey('negative_prompt')) {
      updated = updated.copyWith(
        negativePrompt: (args['negative_prompt'] as String?) ?? '',
      );
    }
    if (args.containsKey('enabled')) {
      final enabled = args['enabled'];
      if (enabled is! bool) {
        return agentToolError(
          'invalid_character_enabled',
          'enabled must be a boolean.',
        );
      }
      updated = updated.copyWith(enabled: enabled);
    }
    updated = _applyPositionChange(updated, positionChange);

    final notifier = _ref.read(characterPromptNotifierProvider.notifier);
    if (!await notifier.updateCharacterPersisted(updated)) {
      return agentToolError(
        'character_persistence_failed',
        'The character changed in memory but could not be persisted.',
      );
    }
    final applied = _findCharacter(id: updated.id)!;
    final order = _ref
        .read(characterPromptNotifierProvider)
        .characters
        .indexWhere((character) => character.id == applied.id);
    return _textResult(
      jsonEncode({
        'ok': true,
        'character': _characterJson(applied, order: order),
      }),
    );
  }

  Future<AgentToolResult> _addCharacter(Map<String, dynamic> args) async {
    late final _CharacterPositionChange positionChange;
    try {
      _validateCharacterStringFields(args);
      positionChange = _parsePositionChange(args);
    } on _PromptToolValidationException catch (error) {
      return agentToolError(error.code, error.message);
    }
    final name = (args['name'] as String?)?.trim() ?? '';
    if (name.isEmpty) {
      return agentToolError('invalid_character_name', 'name is required.');
    }

    final notifier = _ref.read(characterPromptNotifierProvider.notifier);
    final limit = notifier.characterLimit;
    final existingCharacters = _ref
        .read(characterPromptNotifierProvider)
        .characters;
    if (limit == 0) {
      final model = _ref.read(generationParamsNotifierProvider).model;
      return agentToolError(
        'model_character_unsupported',
        'Model $model does not support character prompts.',
      );
    }
    if (existingCharacters.length >= limit) {
      return agentToolError(
        'model_character_limit',
        'The current model supports at most $limit characters.',
      );
    }

    final enabled = args['enabled'] ?? true;
    if (enabled is! bool) {
      return agentToolError(
        'invalid_character_enabled',
        'enabled must be a boolean.',
      );
    }
    final positionMode = positionChange.mode ?? CharacterPositionMode.aiChoice;
    final customPosition = positionChange.x == null
        ? null
        : CharacterPosition(
            mode: CharacterPositionMode.custom,
            row: positionChange.y!,
            column: positionChange.x!,
          );
    final result = await notifier.addCharacterPersisted(
      _parseGender(args['gender']) ?? CharacterGender.female,
      name: name,
      prompt: (args['prompt'] as String?) ?? '',
      negativePrompt: args.containsKey('negative_prompt')
          ? (args['negative_prompt'] as String?) ?? ''
          : null,
      enabled: enabled,
      positionMode: positionMode,
      customPosition: customPosition,
    );
    if (result == null) {
      return agentToolError(
        'character_add_failed',
        'Character could not be added.',
      );
    }
    if (!result.persisted) {
      return agentToolError(
        'character_persistence_failed',
        'The character changed in memory but could not be persisted.',
      );
    }
    final created = result.character;
    final order = _ref
        .read(characterPromptNotifierProvider)
        .characters
        .indexWhere((character) => character.id == created.id);
    return _textResult(
      jsonEncode({
        'ok': true,
        'character': _characterJson(created, order: order),
      }),
    );
  }

  Future<AgentToolResult> _setCharacterLayoutMode(
    Map<String, dynamic> args,
  ) async {
    final mode = args['mode'];
    if (mode != 'ai_choice' && mode != 'custom') {
      return agentToolError(
        'invalid_character_layout_mode',
        'mode must be "ai_choice" or "custom".',
      );
    }
    final notifier = _ref.read(characterPromptNotifierProvider.notifier);
    if (!await notifier.setGlobalAiChoicePersisted(mode == 'ai_choice')) {
      return agentToolError(
        'character_persistence_failed',
        'The layout changed in memory but could not be persisted.',
      );
    }
    final config = _ref.read(characterPromptNotifierProvider);
    return _textResult(
      jsonEncode({
        'ok': true,
        'character_layout_mode': mode,
        'characters': [
          for (var index = 0; index < config.characters.length; index++)
            _characterJson(config.characters[index], order: index),
        ],
      }),
    );
  }

  Future<AgentToolResult> _reorderCharacters(Map<String, dynamic> args) async {
    final rawIds = args['ordered_ids'];
    if (rawIds is! List || rawIds.any((value) => value is! String)) {
      return agentToolError(
        'invalid_character_order',
        'ordered_ids must be an array of stable character IDs.',
      );
    }
    final ids = rawIds.cast<String>();
    final notifier = _ref.read(characterPromptNotifierProvider.notifier);
    try {
      if (!await notifier.setCharacterOrderPersisted(ids)) {
        return agentToolError(
          'character_persistence_failed',
          'The order changed in memory but could not be persisted.',
        );
      }
    } on FormatException catch (error) {
      return agentToolError('invalid_character_order', error.message);
    }
    final characters = _ref.read(characterPromptNotifierProvider).characters;
    return _textResult(
      jsonEncode({
        'ok': true,
        'characters': [
          for (var index = 0; index < characters.length; index++)
            _characterJson(characters[index], order: index),
        ],
      }),
    );
  }

  Future<AgentToolResult> _removeCharacter(Map<String, dynamic> args) async {
    late final CharacterPrompt? target;
    try {
      _validateCharacterStringFields(args);
      target = _findCharacter(
        id: args['id'] as String?,
        name: args['name'] as String?,
      );
    } on _PromptToolValidationException catch (error) {
      return agentToolError(error.code, error.message);
    }
    if (target == null) {
      return agentToolError('character_not_found', 'Character not found.');
    }
    final notifier = _ref.read(characterPromptNotifierProvider.notifier);
    if (!await notifier.removeCharacterPersisted(target.id)) {
      return agentToolError(
        'character_persistence_failed',
        'The character was removed in memory but could not be persisted.',
      );
    }
    return _textResult(jsonEncode({'ok': true, 'removed': target.name}));
  }

  Future<AgentToolResult> _clearCharacters() async {
    final notifier = _ref.read(characterPromptNotifierProvider.notifier);
    if (!await notifier.clearAllCharactersPersisted()) {
      return agentToolError(
        'character_persistence_failed',
        'Characters were cleared in memory but could not be persisted.',
      );
    }
    return _textResult(jsonEncode({'ok': true, 'characters': <Object>[]}));
  }

  CharacterPrompt _applyPositionChange(
    CharacterPrompt character,
    _CharacterPositionChange change,
  ) {
    if (!change.hasChange) return character;
    if (change.mode == CharacterPositionMode.aiChoice) {
      return character.copyWith(positionMode: CharacterPositionMode.aiChoice);
    }
    final config = _ref.read(characterPromptNotifierProvider);
    final position = change.x != null
        ? CharacterPosition(
            mode: CharacterPositionMode.custom,
            row: change.y!,
            column: change.x!,
          )
        : character.customPosition ?? config.resolvePosition(character);
    return character.copyWith(
      positionMode: CharacterPositionMode.custom,
      customPosition: position,
    );
  }

  _CharacterPositionChange _parsePositionChange(Map<String, dynamic> args) {
    final rawMode = args['position_mode'];
    final mode = switch (rawMode) {
      null => null,
      'ai_choice' => CharacterPositionMode.aiChoice,
      'custom' => CharacterPositionMode.custom,
      _ => throw const _PromptToolValidationException(
        'invalid_character_position_mode',
        'position_mode must be "ai_choice" or "custom".',
      ),
    };
    final hasX = args.containsKey('position_x');
    final hasY = args.containsKey('position_y');
    if (hasX != hasY) {
      throw const _PromptToolValidationException(
        'partial_character_coordinates',
        'position_x and position_y must be provided together.',
      );
    }
    double? x;
    double? y;
    if (hasX) {
      x = _validateCoordinate(args['position_x'], 'position_x');
      y = _validateCoordinate(args['position_y'], 'position_y');
      if (mode == CharacterPositionMode.aiChoice) {
        throw const _PromptToolValidationException(
          'character_position_conflict',
          'ai_choice cannot be combined with coordinates.',
        );
      }
    }
    return _CharacterPositionChange(
      hasChange: rawMode != null || hasX,
      mode: mode ?? (hasX ? CharacterPositionMode.custom : null),
      x: x,
      y: y,
    );
  }

  double _validateCoordinate(Object? value, String name) {
    if (value is! num) {
      throw _PromptToolValidationException(
        'invalid_character_coordinate',
        '$name must be a finite number between 0 and 1.',
      );
    }
    final coordinate = value.toDouble();
    if (!coordinate.isFinite || coordinate < 0 || coordinate > 1) {
      throw _PromptToolValidationException(
        'invalid_character_coordinate',
        '$name must be a finite number between 0 and 1.',
      );
    }
    return coordinate;
  }

  static Map<String, dynamic> _characterJson(
    CharacterPrompt character, {
    required int order,
  }) => {
    'id': character.id,
    'order': order,
    'name': character.name,
    'gender': character.gender.name,
    'enabled': character.enabled,
    'prompt': character.prompt,
    'negative_prompt': character.negativePrompt,
    'position_mode': character.positionMode == CharacterPositionMode.aiChoice
        ? 'ai_choice'
        : 'custom',
    'position_x': character.customPosition?.column,
    'position_y': character.customPosition?.row,
  };

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
    final content = PrivateDataGuard.redactAbsolutePaths(skill.content);
    return _textResult(content.isEmpty ? '(empty)' : content);
  }

  Future<AgentToolResult> _readSkillResource(Map<String, dynamic> args) async {
    final name = (args['name'] as String?)?.trim() ?? '';
    final relativePath = (args['path'] as String?)?.trim() ?? '';
    final skill = _skills[name];
    if (skill == null) {
      return _errorResult('Skill "$name" not found.');
    }
    if (relativePath.isEmpty) {
      return _errorResult('Parameter "path" is required.');
    }
    final offset = (args['offset'] as num?)?.toInt() ?? 0;
    final limit = (args['limit'] as num?)?.toInt() ?? 200;
    if (offset < 0) {
      return _errorResult('Parameter "offset" must be at least 0.');
    }
    if (limit < 1 || limit > 1000) {
      return _errorResult('Parameter "limit" must be between 1 and 1000.');
    }

    final skillRoot = File(skill.filePath).parent.path;
    final env = DartIoExecutionEnv(workingDirectory: skillRoot);
    final resolved = await env.absolutePath(relativePath);
    final absolutePath = resolved.valueOrNull;
    if (absolutePath == null) {
      return _errorResult('Skill resource path is not permitted.');
    }
    final info = await env.fileInfo(absolutePath);
    if (info.valueOrNull?.kind != FileKind.file) {
      return _errorResult('Skill resource is not a readable text file.');
    }
    final result = await env.readTextFile(absolutePath);
    final content = result.valueOrNull;
    if (content == null) {
      return _errorResult('Failed to read skill resource.');
    }
    final lines = content.split(RegExp(r'\r?\n'));
    final selected = offset >= lines.length
        ? const <String>[]
        : lines.skip(offset).take(limit).toList(growable: false);
    return _textResult(
      jsonEncode({
        'path': relativePath,
        'offset': offset,
        'returned_lines': selected.length,
        'total_lines': lines.length,
        'truncated': offset + selected.length < lines.length,
        'content': PrivateDataGuard.redactAbsolutePaths(selected.join('\n')),
      }),
    );
  }

  String _agentSafePath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final segments = normalized
        .split('/')
        .where((segment) => segment.isNotEmpty && !segment.endsWith(':'))
        .toList(growable: false);
    if (segments.isEmpty) return '(unknown)';
    final start = segments.length > 3 ? segments.length - 3 : 0;
    return '.../${segments.skip(start).join('/')}';
  }

  void _validateCharacterStringFields(Map<String, dynamic> args) {
    const fields = [
      'id',
      'name',
      'new_name',
      'gender',
      'prompt',
      'negative_prompt',
    ];
    for (final field in fields) {
      if (args.containsKey(field) && args[field] is! String) {
        throw _PromptToolValidationException(
          'invalid_character_field',
          '$field must be a string.',
        );
      }
    }
    if (args.containsKey('gender')) _parseGender(args['gender']);
  }

  CharacterGender? _parseGender(Object? raw) => switch (raw) {
    null => null,
    'female' => CharacterGender.female,
    'male' => CharacterGender.male,
    'other' => CharacterGender.other,
    _ => throw const _PromptToolValidationException(
      'invalid_character_gender',
      'gender must be "female", "male", or "other".',
    ),
  };
}

class _CharacterPositionChange {
  const _CharacterPositionChange({
    required this.hasChange,
    required this.mode,
    required this.x,
    required this.y,
  });

  final bool hasChange;
  final CharacterPositionMode? mode;
  final double? x;
  final double? y;
}

class _PromptToolValidationException implements Exception {
  const _PromptToolValidationException(this.code, this.message);

  final String code;
  final String message;
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
