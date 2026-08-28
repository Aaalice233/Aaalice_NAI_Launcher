import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/harness/tools/image.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../../core/utils/display_thumbnail_utils.dart';
import '../../../data/models/vibe/vibe_library_entry.dart';
import '../../../data/models/vibe/vibe_reference.dart';
import '../../providers/generation/generation_params_notifier.dart';
import '../../providers/vibe_library_provider.dart';
import 'agent_resource_resolver.dart';
import 'defined_agent_tool.dart';
import 'toolbox_json.dart';

class VibeLibraryToolbox {
  VibeLibraryToolbox(this._ref, this._resolver);

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
    name: 'list_vibe_library',
    label: 'List Vibe Library',
    description:
        'List reusable Vibe entries without exposing encodings, image bytes, or paths.',
    parameters: toolboxObject(
      properties: {
        'query': {'type': 'string'},
        'category_id': {'type': 'string'},
        'favorites_only': {'type': 'boolean'},
        'limit': {'type': 'integer', 'minimum': 1, 'maximum': 200},
      },
    ),
    executeFn: (_, params) async {
      final notifier = _ref.read(vibeLibraryNotifierProvider.notifier);
      await notifier.initialize();
      await notifier.clearAllFilters();
      await notifier.setSearchQuery(params['query'] as String? ?? '');
      if (params['category_id'] case final String categoryId) {
        await notifier.setCategoryFilter(categoryId);
      }
      await notifier.setFavoritesOnly(params['favorites_only'] == true);
      final state = _ref.read(vibeLibraryNotifierProvider);
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
    name: 'get_vibe_library_entry',
    label: 'Get Vibe Library Entry',
    description: 'Read complete safe metadata for one Vibe entry.',
    parameters: _idSchema,
    executeFn: (_, params) async {
      final entry = await _entry(params['entry_id'] as String);
      if (entry == null) {
        return agentToolError('not_found', 'Vibe entry not found.');
      }
      return agentToolJsonResult({'ok': true, 'entry': _entryJson(entry)});
    },
  );

  DefinedAgentTool _create() => DefinedAgentTool(
    name: 'create_vibe_library_entry',
    label: 'Create Vibe Library Entry',
    description:
        'Create a raw-image Vibe entry from a validated resource reference. This does not encode or spend Anlas.',
    parameters: toolboxObject(
      properties: {
        'resource_ref': {'type': 'object'},
        'name': {'type': 'string', 'minLength': 1, 'maxLength': 200},
        'strength': {'type': 'number'},
        'information_extracted': {'type': 'number'},
        'category_id': {'type': 'string'},
        'tags': {
          'type': 'array',
          'items': {'type': 'string'},
          'maxItems': 100,
        },
      },
      required: const ['resource_ref', 'name'],
    ),
    executeFn: (_, params) async {
      final reference = _resolver.decode(params['resource_ref']);
      final resolved = await _resolver.resolve(reference);
      if (resolved == null) {
        return agentToolError(
          'resource_unavailable',
          'Resource is unavailable.',
        );
      }
      final notifier = _ref.read(vibeLibraryNotifierProvider.notifier);
      await notifier.initialize();
      VibeReference vibe;
      if (resolved.vibeEntryId case final String sourceId) {
        final source = await _entry(sourceId);
        if (source == null) {
          return agentToolError(
            'resource_unavailable',
            'Source Vibe is unavailable.',
          );
        }
        vibe = source.toVibeReference().copyWith(
          displayName: params['name'] as String,
          strength: (params['strength'] as num?)?.toDouble() ?? source.strength,
          infoExtracted:
              (params['information_extracted'] as num?)?.toDouble() ??
              source.infoExtracted,
        );
      } else {
        final bytes = resolved.bytes;
        if (bytes == null || bytes.isEmpty) {
          return agentToolError('not_an_image', 'Resource has no image data.');
        }
        vibe = VibeReference(
          displayName: params['name'] as String,
          vibeEncoding: '',
          thumbnail: await DisplayThumbnailUtils.normalize(bytes),
          rawImageData: bytes,
          strength: (params['strength'] as num?)?.toDouble() ?? 0.6,
          infoExtracted:
              (params['information_extracted'] as num?)?.toDouble() ?? 0.7,
        );
      }
      final created = await notifier.saveEntry(
        VibeLibraryEntry.fromVibeReference(
          name: params['name'] as String,
          vibeData: vibe,
          categoryId: params['category_id'] as String?,
          tags: toolboxStrings(params['tags']),
          thumbnail: vibe.thumbnail,
        ),
      );
      if (created == null) {
        return agentToolError('write_failed', 'Could not save Vibe entry.');
      }
      return agentToolJsonResult({'ok': true, 'entry': _entryJson(created)});
    },
  );

  DefinedAgentTool _update() => DefinedAgentTool(
    name: 'update_vibe_library_entry',
    label: 'Update Vibe Library Entry',
    description: 'Update Vibe metadata and default generation parameters.',
    parameters: toolboxObject(
      properties: {
        'entry_id': {'type': 'string'},
        'name': {'type': 'string'},
        'strength': {'type': 'number'},
        'information_extracted': {'type': 'number'},
        'category_id': {
          'type': ['string', 'null'],
        },
        'tags': {
          'type': 'array',
          'items': {'type': 'string'},
          'maxItems': 100,
        },
        'favorite': {'type': 'boolean'},
      },
      required: const ['entry_id'],
    ),
    executeFn: (_, params) async {
      final notifier = _ref.read(vibeLibraryNotifierProvider.notifier);
      await notifier.initialize();
      final id = params['entry_id'] as String;
      var current = await _entry(id);
      if (current == null) {
        return agentToolError('not_found', 'Vibe entry not found.');
      }
      if (params['name'] case final String name) {
        await notifier.renameEntry(id, name);
      }
      if (params.containsKey('strength') ||
          params.containsKey('information_extracted')) {
        await notifier.saveEntryParams(
          id,
          strength:
              (params['strength'] as num?)?.toDouble() ?? current.strength,
          infoExtracted:
              (params['information_extracted'] as num?)?.toDouble() ??
              current.infoExtracted,
        );
      }
      if (params.containsKey('category_id')) {
        await notifier.updateEntryCategory(
          id,
          params['category_id'] as String?,
        );
      }
      if (params['tags'] case final List values) {
        await notifier.updateEntryTags(
          id,
          values.map((value) => value.toString()).toList(),
        );
      }
      current = await _entry(id);
      if (params['favorite'] case final bool desired
          when current != null && current.isFavorite != desired) {
        await notifier.toggleFavorite(id);
      }
      final updated = await _entry(id);
      return agentToolJsonResult({'ok': true, 'entry': _entryJson(updated!)});
    },
  );

  DefinedAgentTool _preview() => DefinedAgentTool(
    name: 'preview_vibe_library_entry',
    label: 'Preview Vibe Library Entry',
    description:
        'Return the bounded Vibe thumbnail without exposing its encoding.',
    parameters: _idSchema,
    executeFn: (_, params) async {
      final entry = await _entry(params['entry_id'] as String);
      if (entry == null) {
        return agentToolError('not_found', 'Vibe entry not found.');
      }
      final bytes =
          entry.thumbnail ?? entry.vibeThumbnail ?? entry.rawImageData;
      if (bytes == null) {
        return agentToolError('preview_unavailable', 'Vibe has no preview.');
      }
      final thumbnail = await DisplayThumbnailUtils.normalize(bytes);
      final mime = thumbnail == null
          ? null
          : detectSupportedImageMimeType(thumbnail);
      if (thumbnail == null || mime == null) {
        return agentToolError('preview_invalid', 'Vibe preview is invalid.');
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

  DefinedAgentTool _apply() => _idAction(
    name: 'apply_vibe_library_entry',
    label: 'Apply Vibe Library Entry',
    description: 'Add a Vibe entry to current generation parameters.',
    action: (id) => _ref
        .read(generationParamsNotifierProvider.notifier)
        .addVibeFromLibrary(id),
  );

  DefinedAgentTool _removeActive() => _indexAction(
    name: 'remove_active_vibe',
    label: 'Remove Active Vibe',
    description: 'Remove a Vibe from generation parameters by index.',
    max: () =>
        _ref.read(generationParamsNotifierProvider).vibeReferencesV4.length,
    action: (index) => _ref
        .read(generationParamsNotifierProvider.notifier)
        .removeVibeReference(index),
  );

  DefinedAgentTool _delete() => _idAction(
    name: 'delete_vibe_library_entry',
    label: 'Delete Vibe Library Entry',
    description: 'Permanently delete a Vibe entry and its managed files.',
    action: (id) =>
        _ref.read(vibeLibraryNotifierProvider.notifier).deleteEntry(id),
  );

  Future<VibeLibraryEntry?> _entry(String id) async {
    final notifier = _ref.read(vibeLibraryNotifierProvider.notifier);
    await notifier.initialize();
    return (await notifier.resolveEntriesByIds([id])).firstOrNull;
  }
}

Map<String, dynamic> _entryJson(VibeLibraryEntry entry) => {
  'entry_id': entry.id,
  'resource_ref': AgentChatResourceReferenceCodec.encodeJsonMap(
    AgentChatResourceReference(
      kind: AgentChatResourceKind.vibeLibraryEntry,
      source: 'vibe_library',
      resourceId: entry.id,
      display: {'name': entry.displayName},
    ),
  ),
  'name': entry.displayName,
  'source_type': entry.sourceType.name,
  'strength': entry.strength,
  'information_extracted': entry.infoExtracted,
  'encoding_model': entry.encodingModel,
  'needs_encoding': entry.vibeEncoding.isEmpty,
  'category_id': entry.categoryId,
  'tags': entry.tags,
  'favorite': entry.isFavorite,
  'used_count': entry.usedCount,
  'bundle_count': entry.bundledVibeCount,
};

final _idSchema = toolboxObject(
  properties: {
    'entry_id': {'type': 'string'},
  },
  required: const ['entry_id'],
);

DefinedAgentTool _idAction({
  required String name,
  required String label,
  required String description,
  required Future<bool> Function(String) action,
}) => DefinedAgentTool(
  name: name,
  label: label,
  description: description,
  parameters: _idSchema,
  executeFn: (_, params) async {
    final id = params['entry_id'] as String;
    return await action(id)
        ? agentToolJsonResult({'ok': true, 'entry_id': id})
        : agentToolError(
            'not_found_or_limit',
            '$label could not be completed.',
          );
  },
);

DefinedAgentTool _indexAction({
  required String name,
  required String label,
  required String description,
  required int Function() max,
  required void Function(int) action,
}) => DefinedAgentTool(
  name: name,
  label: label,
  description: description,
  parameters: toolboxObject(
    properties: {
      'index': {'type': 'integer', 'minimum': 0},
    },
    required: const ['index'],
  ),
  executeFn: (_, params) async {
    final index = params['index'] as int;
    if (index >= max()) {
      return agentToolError('invalid_index', 'Index out of range.');
    }
    action(index);
    return agentToolJsonResult({'ok': true, 'index': index});
  },
);
