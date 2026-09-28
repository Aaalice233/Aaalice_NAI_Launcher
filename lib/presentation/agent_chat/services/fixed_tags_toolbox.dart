import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agent/agent_types.dart';
import '../../../data/models/fixed_tag/fixed_tag_entry.dart';
import '../../../data/models/fixed_tag/fixed_tag_prompt_type.dart';
import '../../providers/fixed_tags_provider.dart';
import '../../providers/tag_library_page_provider.dart';
import 'defined_agent_tool.dart';
import 'toolbox_json.dart';

/// Tools for ordered positive and negative fixed prompt fragments.
class FixedTagsToolbox {
  FixedTagsToolbox(this._ref);

  final Ref _ref;

  List<AgentTool> tools() => [
    _list(),
    _create(),
    _addFromLibrary(),
    _update(),
    _toggleEnabled(),
    _delete(),
    _reorder(),
  ];

  DefinedAgentTool _list() => DefinedAgentTool(
    name: 'list_fixed_tags',
    label: 'List Fixed Tags',
    description:
        'List ordered positive or negative fixed prompt fragments and their current applied projection.',
    parameters: toolboxObject(
      properties: {
        'prompt_type': {
          'type': 'string',
          'enum': ['positive', 'negative', 'all'],
        },
        'enabled_only': {'type': 'boolean'},
        'category_id': {'type': 'string'},
      },
    ),
    executeFn: (_, params) async {
      final state = _ref.read(fixedTagsNotifierProvider);
      final promptType = params['prompt_type'] as String? ?? 'all';
      final categoryId = params['category_id'] as String?;
      final enabledOnly = params['enabled_only'] as bool? ?? false;
      final entries = state.entries.where((entry) {
        return (promptType == 'all' || entry.promptType.name == promptType) &&
            (categoryId == null || entry.categoryId == categoryId) &&
            (!enabledOnly || entry.enabled);
      });
      return agentToolJsonResult({
        'ok': true,
        'entries': [for (final entry in entries) _entryJson(entry)],
        'links': [
          for (final link in state.links)
            {
              'id': link.id,
              'positive_entry_id': link.positiveEntryId,
              'negative_entry_id': link.negativeEntryId,
              'mismatched': state.isMismatched(link),
            },
        ],
        'projection': {
          'positive_prefixes': state.enabledPrefixes,
          'positive_suffixes': state.enabledSuffixes,
          'negative_prefixes': state.negativeEnabledPrefixes,
          'negative_suffixes': state.negativeEnabledSuffixes,
        },
        'can_undo': state.canUndo,
        'can_redo': state.canRedo,
      });
    },
  );

  DefinedAgentTool _create() => DefinedAgentTool(
    name: 'create_fixed_tag',
    label: 'Create Fixed Tag',
    description: 'Create an ordered fixed prompt fragment.',
    parameters: toolboxObject(
      properties: _mutationProperties,
      required: const ['name', 'content'],
    ),
    executeFn: (_, params) async {
      final sourceError = _validateSource(params['source_entry_id'] as String?);
      if (sourceError != null) return sourceError;
      final entry = await _ref
          .read(fixedTagsNotifierProvider.notifier)
          .addEntry(
            name: params['name'] as String,
            content: params['content'] as String,
            weight: (params['weight'] as num?)?.toDouble() ?? 1,
            position: _position(params['position'] as String?),
            enabled: params['enabled'] as bool? ?? true,
            promptType: _promptType(params['prompt_type'] as String?),
            sourceEntryId: params['source_entry_id'] as String?,
            categoryId: params['category_id'] as String?,
          );
      return agentToolJsonResult({'ok': true, 'entry': _entryJson(entry)});
    },
  );

  DefinedAgentTool _addFromLibrary() => DefinedAgentTool(
    name: 'add_fixed_tag_from_library',
    label: 'Add Fixed Tag From Library',
    description:
        'Create a fixed tag from an authoritative tag-library entry and retain the stable source link.',
    parameters: toolboxObject(
      properties: {
        'library_entry_id': {'type': 'string'},
        'name': {'type': 'string'},
        'weight': {'type': 'number', 'minimum': 0.5, 'maximum': 2.0},
        'position': {
          'type': 'string',
          'enum': ['prefix', 'suffix'],
        },
        'enabled': {'type': 'boolean'},
        'prompt_type': {
          'type': 'string',
          'enum': ['positive', 'negative'],
        },
      },
      required: const ['library_entry_id'],
    ),
    executeFn: (_, params) async {
      final source = _ref
          .read(tagLibraryPageNotifierProvider.notifier)
          .getEntry(params['library_entry_id'] as String);
      if (source == null) {
        return agentToolError('not_found', 'Tag library entry not found.');
      }
      final entry = await _ref
          .read(fixedTagsNotifierProvider.notifier)
          .addEntry(
            name: params['name'] as String? ?? source.name,
            content: source.content,
            weight: (params['weight'] as num?)?.toDouble() ?? 1,
            position: _position(params['position'] as String?),
            enabled: params['enabled'] as bool? ?? true,
            promptType: _promptType(params['prompt_type'] as String?),
            sourceEntryId: source.id,
            categoryId: source.categoryId,
          );
      return agentToolJsonResult({'ok': true, 'entry': _entryJson(entry)});
    },
  );

  DefinedAgentTool _update() => DefinedAgentTool(
    name: 'update_fixed_tag',
    label: 'Update Fixed Tag',
    description:
        'Update content, weight, ordering semantics, prompt side, and source linkage by stable ID.',
    parameters: toolboxObject(
      properties: {
        'entry_id': {'type': 'string'},
        ..._mutationProperties,
        'clear_source': {'type': 'boolean'},
        'clear_category': {'type': 'boolean'},
      },
      required: const ['entry_id'],
    ),
    executeFn: (_, params) async {
      final current = _find(params['entry_id'] as String);
      if (current == null) {
        return agentToolError('not_found', 'Fixed tag not found.');
      }
      final sourceId = params['clear_source'] == true
          ? null
          : params.containsKey('source_entry_id')
          ? params['source_entry_id'] as String?
          : current.sourceEntryId;
      final sourceError = _validateSource(sourceId);
      if (sourceError != null) return sourceError;
      final categoryId = params['clear_category'] == true
          ? null
          : params.containsKey('category_id')
          ? params['category_id'] as String?
          : current.categoryId;
      final updated = current.copyWith(
        name: params['name'] as String? ?? current.name,
        content: params['content'] as String? ?? current.content,
        weight: (params['weight'] as num?)?.toDouble() ?? current.weight,
        position: params.containsKey('position')
            ? _position(params['position'] as String?)
            : current.position,
        enabled: params['enabled'] as bool? ?? current.enabled,
        promptType: params.containsKey('prompt_type')
            ? _promptType(params['prompt_type'] as String?)
            : current.promptType,
        sourceEntryId: sourceId,
        categoryId: categoryId,
        updatedAt: DateTime.now(),
      );
      await _ref.read(fixedTagsNotifierProvider.notifier).updateEntry(updated);
      return agentToolJsonResult({'ok': true, 'entry': _entryJson(updated)});
    },
  );

  DefinedAgentTool _toggleEnabled() => DefinedAgentTool(
    name: 'toggle_fixed_tag_enabled',
    label: 'Toggle Fixed Tag Enabled',
    description: 'Toggle one fixed tag and its provider-managed linked state.',
    parameters: _idSchema,
    executeFn: (_, params) async {
      final id = params['entry_id'] as String;
      if (_find(id) == null) {
        return agentToolError('not_found', 'Fixed tag not found.');
      }
      await _ref.read(fixedTagsNotifierProvider.notifier).toggleEnabled(id);
      return agentToolJsonResult({'ok': true, 'entry': _entryJson(_find(id)!)});
    },
  );

  DefinedAgentTool _delete() => toolboxIdTool(
    name: 'delete_fixed_tag',
    label: 'Delete Fixed Tag',
    description: 'Permanently delete a fixed prompt fragment.',
    idKey: 'entry_id',
    execute: (id) async {
      if (_find(id) == null) return false;
      await _ref.read(fixedTagsNotifierProvider.notifier).deleteEntry(id);
      return true;
    },
  );

  DefinedAgentTool _reorder() => DefinedAgentTool(
    name: 'reorder_fixed_tag',
    label: 'Reorder Fixed Tag',
    description: 'Move one fixed prompt fragment to an absolute ordered index.',
    parameters: toolboxObject(
      properties: {
        'entry_id': {'type': 'string'},
        'new_index': {'type': 'integer', 'minimum': 0},
      },
      required: const ['entry_id', 'new_index'],
    ),
    executeFn: (_, params) async {
      final entries = _ref.read(fixedTagsNotifierProvider).entries;
      final id = params['entry_id'] as String;
      final oldIndex = entries.indexWhere((entry) => entry.id == id);
      final newIndex = params['new_index'] as int;
      if (oldIndex < 0) {
        return agentToolError('not_found', 'Fixed tag not found.');
      }
      if (newIndex < 0 || newIndex >= entries.length) {
        return agentToolError('invalid_index', 'new_index is out of range.');
      }
      await _ref
          .read(fixedTagsNotifierProvider.notifier)
          .reorder(oldIndex, newIndex);
      return agentToolJsonResult({'ok': true, 'entry': _entryJson(_find(id)!)});
    },
  );

  FixedTagEntry? _find(String id) => _ref
      .read(fixedTagsNotifierProvider)
      .entries
      .where((entry) => entry.id == id)
      .firstOrNull;

  AgentToolResult? _validateSource(String? id) {
    if (id == null) return null;
    return _ref.read(tagLibraryPageNotifierProvider.notifier).getEntry(id) !=
            null
        ? null
        : agentToolError(
            'source_not_found',
            'Tag library source entry not found.',
          );
  }
}

const _idSchema = <String, dynamic>{
  'type': 'object',
  'properties': {
    'entry_id': {'type': 'string'},
  },
  'required': ['entry_id'],
};

const _mutationProperties = <String, dynamic>{
  'name': {'type': 'string'},
  'content': {'type': 'string'},
  'weight': {'type': 'number', 'minimum': 0.5, 'maximum': 2.0},
  'position': {
    'type': 'string',
    'enum': ['prefix', 'suffix'],
  },
  'enabled': {'type': 'boolean'},
  'prompt_type': {
    'type': 'string',
    'enum': ['positive', 'negative'],
  },
  'source_entry_id': {'type': 'string'},
  'category_id': {'type': 'string'},
};

FixedTagPosition _position(String? value) =>
    value == 'suffix' ? FixedTagPosition.suffix : FixedTagPosition.prefix;

FixedTagPromptType _promptType(String? value) => value == 'negative'
    ? FixedTagPromptType.negative
    : FixedTagPromptType.positive;

Map<String, dynamic> _entryJson(FixedTagEntry entry) => {
  'id': entry.id,
  'name': entry.name,
  'content': entry.content,
  'weight': entry.weight,
  'position': entry.position.name,
  'enabled': entry.enabled,
  'prompt_type': entry.promptType.name,
  'source_entry_id': entry.sourceEntryId,
  'category_id': entry.categoryId,
  'sort_order': entry.sortOrder,
  'created_at': entry.createdAt.toIso8601String(),
  'updated_at': entry.updatedAt.toIso8601String(),
};
