import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/harness/tools/image.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../../core/enums/precise_ref_type.dart';
import '../../../core/utils/display_thumbnail_utils.dart';
import '../../../data/models/precise_ref/precise_ref_library_entry.dart';
import '../../providers/generation/generation_params_notifier.dart';
import '../../providers/precise_ref_library_provider.dart';
import 'agent_resource_resolver.dart';
import 'defined_agent_tool.dart';
import 'toolbox_json.dart';

class PreciseReferenceToolbox {
  PreciseReferenceToolbox(this._ref, this._resolver);

  final Ref _ref;
  final AgentResourceResolver _resolver;

  List<AgentTool> tools() => [
    _list(),
    _get(),
    _create(),
    _update(),
    _preview(),
    _apply(),
    _removeActive(),
    _delete(),
  ];

  DefinedAgentTool _list() => DefinedAgentTool(
    name: 'list_precise_reference_library',
    label: 'List Precise Reference Library',
    description:
        'List precise-reference entries without exposing image paths or bytes.',
    parameters: toolboxObject(
      properties: {
        'query': {'type': 'string'},
        'type': {
          'type': 'string',
          'enum': PreciseRefType.values.map((value) => value.name).toList(),
        },
        'favorites_only': {'type': 'boolean'},
        'limit': {'type': 'integer', 'minimum': 1, 'maximum': 200},
      },
    ),
    executeFn: (_, params) async {
      final notifier = _ref.read(preciseRefLibraryNotifierProvider.notifier);
      await notifier.initialize();
      notifier.clearFilters();
      notifier.setSearchQuery(params['query'] as String? ?? '');
      if (params['type'] case final String typeName) {
        notifier.setTypeFilter(
          PreciseRefType.values.firstWhere((value) => value.name == typeName),
        );
      }
      if (params['favorites_only'] == true) notifier.toggleFavoritesOnly();
      final state = _ref.read(preciseRefLibraryNotifierProvider);
      return agentToolJsonResult({
        'ok': true,
        'total': state.filteredEntries.length,
        'entries': [
          for (final entry in state.filteredEntries.take(
            (params['limit'] as int? ?? 50).clamp(1, 200),
          ))
            _entryJson(entry),
        ],
      });
    },
  );

  DefinedAgentTool _get() => DefinedAgentTool(
    name: 'get_precise_reference_entry',
    label: 'Get Precise Reference Entry',
    description: 'Read complete safe metadata for one precise reference.',
    parameters: _idSchema,
    executeFn: (_, params) async {
      final entry = await _entry(params['entry_id'] as String);
      if (entry == null) {
        return agentToolError(
          'not_found',
          'Precise-reference entry not found.',
        );
      }
      return agentToolJsonResult({'ok': true, 'entry': _entryJson(entry)});
    },
  );

  DefinedAgentTool _create() => DefinedAgentTool(
    name: 'create_precise_reference_entry',
    label: 'Create Precise Reference Entry',
    description:
        'Create a precise-reference library entry from a validated image resource reference.',
    parameters: toolboxObject(
      properties: {
        'resource_ref': {'type': 'object'},
        'name': {'type': 'string', 'minLength': 1, 'maxLength': 200},
        'type': {
          'type': 'string',
          'enum': PreciseRefType.values.map((value) => value.name).toList(),
        },
        'strength': {'type': 'number'},
        'fidelity': {'type': 'number'},
      },
      required: const ['resource_ref', 'name'],
    ),
    executeFn: (_, params) async {
      final reference = _resolver.decode(params['resource_ref']);
      final resolved = await _resolver.resolve(reference);
      if (resolved?.bytes == null) {
        return agentToolError(
          'resource_unavailable',
          'Image resource is unavailable.',
        );
      }
      final typeName = params['type'] as String?;
      final entry = await _ref
          .read(preciseRefLibraryNotifierProvider.notifier)
          .importFromBytes(
            resolved!.bytes!,
            name: params['name'] as String,
            type: typeName == null
                ? PreciseRefType.characterAndStyle
                : PreciseRefType.values.firstWhere(
                    (value) => value.name == typeName,
                  ),
            strength: (params['strength'] as num?)?.toDouble() ?? 1,
            fidelity: (params['fidelity'] as num?)?.toDouble() ?? 1,
          );
      return agentToolJsonResult({'ok': true, 'entry': _entryJson(entry)});
    },
  );

  DefinedAgentTool _update() => DefinedAgentTool(
    name: 'update_precise_reference_entry',
    label: 'Update Precise Reference Entry',
    description: 'Update precise-reference metadata and default parameters.',
    parameters: toolboxObject(
      properties: {
        'entry_id': {'type': 'string'},
        'name': {'type': 'string'},
        'type': {
          'type': 'string',
          'enum': PreciseRefType.values.map((value) => value.name).toList(),
        },
        'strength': {'type': 'number'},
        'fidelity': {'type': 'number'},
        'favorite': {'type': 'boolean'},
      },
      required: const ['entry_id'],
    ),
    executeFn: (_, params) async {
      final notifier = _ref.read(preciseRefLibraryNotifierProvider.notifier);
      await notifier.initialize();
      final id = params['entry_id'] as String;
      var current = await _entry(id);
      if (current == null) {
        return agentToolError(
          'not_found',
          'Precise-reference entry not found.',
        );
      }
      final typeName = params['type'] as String?;
      final updated = await notifier.updateEntry(
        id,
        name: params['name'] as String?,
        type: typeName == null
            ? null
            : PreciseRefType.values.firstWhere(
                (value) => value.name == typeName,
              ),
        strength: (params['strength'] as num?)?.toDouble(),
        fidelity: (params['fidelity'] as num?)?.toDouble(),
      );
      if (updated == null) {
        return agentToolError('write_failed', 'Update failed.');
      }
      current = updated;
      if (params['favorite'] case final bool desired
          when current.isFavorite != desired) {
        await notifier.toggleFavorite(id);
      }
      return agentToolJsonResult({
        'ok': true,
        'entry': _entryJson((await _entry(id))!),
      });
    },
  );

  DefinedAgentTool _preview() => DefinedAgentTool(
    name: 'preview_precise_reference_entry',
    label: 'Preview Precise Reference Entry',
    description: 'Return a bounded preview for a precise-reference entry.',
    parameters: _idSchema,
    executeFn: (_, params) async {
      final entry = await _entry(params['entry_id'] as String);
      if (entry == null) {
        return agentToolError(
          'not_found',
          'Precise-reference entry not found.',
        );
      }
      final file = File(entry.imagePath);
      if (!await file.exists()) {
        return agentToolError(
          'resource_unavailable',
          'Reference image is unavailable.',
        );
      }
      final thumbnail = await DisplayThumbnailUtils.normalize(
        await file.readAsBytes(),
      );
      final mime = thumbnail == null
          ? null
          : detectSupportedImageMimeType(thumbnail);
      if (thumbnail == null || mime == null) {
        return agentToolError(
          'preview_invalid',
          'Reference preview is invalid.',
        );
      }
      final details = <String, dynamic>{'ok': true, 'entry': _entryJson(entry)};
      return AgentToolResult(
        content: [
          ToolResultTextContent(jsonEncode(details)),
          ToolResultImageContent(
            ImageContent(
              source: ImageSource.base64(
                mimeType: mime,
                base64Data: base64Encode(thumbnail),
              ),
            ),
          ),
        ],
        details: details,
      );
    },
  );

  DefinedAgentTool _apply() => DefinedAgentTool(
    name: 'apply_precise_reference_entry',
    label: 'Apply Precise Reference Entry',
    description: 'Add an existing precise reference to generation parameters.',
    parameters: _idSchema,
    executeFn: (_, params) async {
      final id = params['entry_id'] as String;
      final entry = await _entry(id);
      if (entry == null) return agentToolError('not_found', 'Entry not found.');
      final file = File(entry.imagePath);
      if (!await file.exists()) {
        return agentToolError(
          'resource_unavailable',
          'Reference image is unavailable.',
        );
      }
      await _ref
          .read(generationParamsNotifierProvider.notifier)
          .addPreciseReferenceFromImage(
            await file.readAsBytes(),
            type: entry.type,
            strength: entry.strength,
            fidelity: entry.fidelity,
          );
      await _ref
          .read(preciseRefLibraryNotifierProvider.notifier)
          .recordUsage(id);
      return agentToolJsonResult({'ok': true, 'entry_id': id});
    },
  );

  DefinedAgentTool _removeActive() => DefinedAgentTool(
    name: 'remove_active_precise_reference',
    label: 'Remove Active Precise Reference',
    description: 'Remove a precise reference from generation by index.',
    parameters: toolboxObject(
      properties: {
        'index': {'type': 'integer', 'minimum': 0},
      },
      required: const ['index'],
    ),
    executeFn: (_, params) async {
      final index = params['index'] as int;
      if (index >=
          _ref
              .read(generationParamsNotifierProvider)
              .preciseReferences
              .length) {
        return agentToolError('invalid_index', 'Index out of range.');
      }
      _ref
          .read(generationParamsNotifierProvider.notifier)
          .removePreciseReference(index);
      return agentToolJsonResult({'ok': true, 'index': index});
    },
  );

  DefinedAgentTool _delete() => DefinedAgentTool(
    name: 'delete_precise_reference_entry',
    label: 'Delete Precise Reference Entry',
    description:
        'Permanently delete a precise-reference entry and managed image.',
    parameters: _idSchema,
    executeFn: (_, params) async {
      final id = params['entry_id'] as String;
      return await _ref
              .read(preciseRefLibraryNotifierProvider.notifier)
              .deleteEntry(id)
          ? agentToolJsonResult({'ok': true, 'entry_id': id})
          : agentToolError('not_found', 'Precise-reference entry not found.');
    },
  );

  Future<PreciseRefLibraryEntry?> _entry(String id) async {
    final notifier = _ref.read(preciseRefLibraryNotifierProvider.notifier);
    await notifier.initialize();
    return _ref
        .read(preciseRefLibraryNotifierProvider)
        .entries
        .where((value) => value.id == id)
        .firstOrNull;
  }
}

Map<String, dynamic> _entryJson(PreciseRefLibraryEntry entry) => {
  'entry_id': entry.id,
  'resource_ref': AgentChatResourceReferenceCodec.encodeJsonMap(
    AgentChatResourceReference(
      kind: AgentChatResourceKind.preciseRefLibraryEntry,
      source: 'precise_reference_library',
      resourceId: entry.id,
      display: {'name': entry.name},
    ),
  ),
  'name': entry.name,
  'type': entry.type.name,
  'strength': entry.strength,
  'fidelity': entry.fidelity,
  'favorite': entry.isFavorite,
  'used_count': entry.usedCount,
  'last_used_at': entry.lastUsedAt?.toIso8601String(),
  'created_at': entry.createdAt.toIso8601String(),
};

final _idSchema = toolboxObject(
  properties: {
    'entry_id': {'type': 'string'},
  },
  required: const ['entry_id'],
);
