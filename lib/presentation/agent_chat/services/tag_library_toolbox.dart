import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/harness/tools/image.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/display_thumbnail_utils.dart';
import '../../../data/models/tag_library/tag_library_category.dart';
import '../../../data/models/tag_library/tag_library_entry.dart';
import '../../../data/services/tag_library_portable_thumbnail_store.dart';
import '../../providers/tag_library_page_provider.dart';
import 'agent_resource_resolver.dart';
import 'defined_agent_tool.dart';
import 'generation_image_resource.dart';
import 'toolbox_json.dart';

typedef TagLibraryImageResourceLoader =
    Future<ResolvedAgentResource?> Function(
      AgentChatResourceReference reference,
    );

/// Production tools for the reusable tag library and its category tree.
class TagLibraryToolbox {
  TagLibraryToolbox(
    Ref ref, {
    AgentResourceResolver? resourceResolver,
    TagLibraryImageResourceLoader? resourceLoader,
    TagLibraryPortableThumbnailStore thumbnailStore =
        const TagLibraryPortableThumbnailStore(),
  }) : assert(
         resourceResolver == null || resourceLoader == null,
         'Provide either resourceResolver or resourceLoader',
       ),
       _ref = ref,
       _resourceLoader =
           resourceLoader ??
           _validatedResourceLoader(
             resourceResolver ?? AgentResourceResolver(ref),
           ),
       _thumbnailStore = thumbnailStore;

  final Ref _ref;
  final TagLibraryImageResourceLoader _resourceLoader;
  final TagLibraryPortableThumbnailStore _thumbnailStore;

  static TagLibraryImageResourceLoader _validatedResourceLoader(
    AgentResourceResolver resolver,
  ) => (reference) async {
    await resolver.validateForDisplay(reference);
    return resolver.resolve(reference);
  };

  List<AgentTool> tools() => [
    _listEntries(),
    _getEntry(),
    _previewEntry(),
    _createEntry(),
    _updateEntry(),
    _toggleFavorite(),
    _deleteEntry(),
    _listCategories(),
    _createCategory(),
    _updateCategory(),
    _deleteCategory(),
  ];

  DefinedAgentTool _listEntries() => DefinedAgentTool(
    name: 'list_tag_library_entries',
    label: 'List Tag Library Entries',
    description:
        'List reusable prompt entries with stable IDs, categories, favorites, and usage metadata.',
    parameters: toolboxObject(
      properties: {
        'query': {'type': 'string', 'maxLength': 500},
        'category_id': {'type': 'string'},
        'favorite_only': {'type': 'boolean'},
        'offset': {'type': 'integer', 'minimum': 0},
        'limit': {'type': 'integer', 'minimum': 1, 'maximum': 200},
      },
    ),
    executeFn: (_, params) async {
      final state = _ref.read(tagLibraryPageNotifierProvider);
      final query = (params['query'] as String? ?? '').trim().toLowerCase();
      final categoryId = params['category_id'] as String?;
      final favoriteOnly = params['favorite_only'] as bool? ?? false;
      final offset = ((params['offset'] as num?)?.toInt() ?? 0).clamp(
        0,
        1 << 30,
      );
      final limit = ((params['limit'] as num?)?.toInt() ?? 50).clamp(1, 200);
      final matching = state.entries
          .where((entry) {
            return (query.isEmpty ||
                    entry.name.toLowerCase().contains(query) ||
                    entry.content.toLowerCase().contains(query) ||
                    entry.tags.any(
                      (tag) => tag.toLowerCase().contains(query),
                    )) &&
                (categoryId == null || entry.categoryId == categoryId) &&
                (!favoriteOnly || entry.isFavorite);
          })
          .toList(growable: false);
      return agentToolJsonResult({
        'ok': true,
        'total': matching.length,
        'entries': [
          for (final entry in matching.skip(offset).take(limit))
            _entryJson(entry, state.categories),
        ],
      });
    },
  );

  DefinedAgentTool _getEntry() => DefinedAgentTool(
    name: 'get_tag_library_entry',
    label: 'Get Tag Library Entry',
    description: 'Get one complete reusable prompt entry by stable ID.',
    parameters: _idSchema,
    executeFn: (_, params) async {
      final state = _ref.read(tagLibraryPageNotifierProvider);
      final entry = _entry(params['entry_id'] as String);
      return entry == null
          ? agentToolError('not_found', 'Tag library entry not found.')
          : agentToolJsonResult({
              'ok': true,
              'entry': _entryJson(entry, state.categories),
            });
    },
  );

  DefinedAgentTool _previewEntry() => DefinedAgentTool(
    name: 'preview_tag_library_entry',
    label: 'Preview Tag Library Entry',
    description:
        'Inspect an entry and its bounded thumbnail without exposing a local path.',
    parameters: _idSchema,
    executeFn: (_, params) async {
      final state = _ref.read(tagLibraryPageNotifierProvider);
      final entry = _entry(params['entry_id'] as String);
      if (entry == null) {
        return agentToolError('not_found', 'Tag library entry not found.');
      }
      final details = <String, dynamic>{
        'ok': true,
        'entry': _entryJson(entry, state.categories),
      };
      final content = <ToolResultContent>[
        ToolResultTextContent(jsonEncode(details)),
      ];
      final thumbnailPath = entry.thumbnail;
      if (thumbnailPath != null && thumbnailPath.isNotEmpty) {
        final file = File(thumbnailPath);
        if (await file.exists()) {
          final thumbnail = await DisplayThumbnailUtils.normalize(
            await file.readAsBytes(),
          );
          final mime = thumbnail == null
              ? null
              : detectSupportedImageMimeType(thumbnail);
          if (thumbnail != null && mime != null) {
            content.add(
              ToolResultImageContent(
                ImageContent(
                  source: ImageSource.base64(
                    mimeType: mime,
                    base64Data: base64Encode(thumbnail),
                  ),
                ),
              ),
            );
          }
        }
      }
      return AgentToolResult(content: content, details: details);
    },
  );

  DefinedAgentTool _createEntry() => DefinedAgentTool(
    name: 'create_tag_library_entry',
    label: 'Create Tag Library Entry',
    description:
        'Create a persisted reusable prompt entry. An optional generated-image '
        'thumbnail must be supplied as thumbnail.resource_ref.',
    parameters: toolboxObject(
      properties: {
        ..._entryMutationProperties,
        'thumbnail': {
          'type': 'object',
          'description':
              'Optional thumbnail source. resource_ref is required and must '
              'identify an available generated image.',
          'properties': {
            'resource_ref': {
              'type': 'object',
              'description': 'Stable generated-image resource reference.',
            },
          },
          'required': ['resource_ref'],
          'additionalProperties': false,
        },
      },
      required: const ['name', 'content'],
    ),
    executeFn: (_, params) async {
      final categoryError = _validateCategory(params['category_id'] as String?);
      if (categoryError != null) return categoryError;
      final thumbnail = params['thumbnail'];
      if (thumbnail == null) return _createEntryWithoutThumbnail(params);
      if (thumbnail is! Map || !thumbnail.containsKey('resource_ref')) {
        return agentToolError(
          'invalid_resource_ref',
          'thumbnail.resource_ref is required.',
        );
      }

      final AgentChatResourceReference reference;
      try {
        final value = thumbnail['resource_ref'];
        if (value is! Map) {
          throw const FormatException('resource_ref must be an object');
        }
        reference = AgentChatResourceReferenceCodec.decodeJsonMap(
          Map<String, dynamic>.from(value),
        );
      } on FormatException catch (error) {
        return agentToolError(
          'invalid_resource_ref',
          'thumbnail.resource_ref is invalid: ${error.message}',
        );
      }
      if (reference.kind != AgentChatResourceKind.generatedImage) {
        return agentToolError(
          'wrong_resource_kind',
          'thumbnail.resource_ref must identify a generated image.',
        );
      }
      final ResolvedAgentResource? resolved;
      try {
        resolved = await _resourceLoader(reference);
      } on GenerationImageResourceException catch (error) {
        return agentToolError(
          error.code,
          'create_tag_library_entry: ${error.message}',
        );
      } on Object catch (error) {
        return agentToolError(
          'resource_resolution_failed',
          'create_tag_library_entry: generated image '
              '${reference.resourceId} failed during thumbnail resource '
              'resolution (${error.runtimeType}).',
        );
      }
      final bytes = resolved?.bytes;
      if (resolved == null || bytes == null || bytes.isEmpty) {
        return agentToolError(
          'resource_unavailable',
          'create_tag_library_entry: generated image '
              '${reference.resourceId} is unavailable.',
        );
      }
      final extension = _thumbnailExtension(bytes);
      if (extension == null) {
        return agentToolError(
          'unsupported_thumbnail',
          'create_tag_library_entry: generated image '
              '${reference.resourceId} is not a supported thumbnail format.',
        );
      }
      return _createEntryWithThumbnail(params, reference, bytes, extension);
    },
  );

  Future<AgentToolResult> _createEntryWithoutThumbnail(
    Map<String, dynamic> params,
  ) async {
    final entry = await _addEntry(params);
    return agentToolJsonResult({'ok': true, 'entry': _entryJson(entry)});
  }

  Future<AgentToolResult> _createEntryWithThumbnail(
    Map<String, dynamic> params,
    AgentChatResourceReference reference,
    Uint8List bytes,
    String extension,
  ) async {
    final notifier = _ref.read(tagLibraryPageNotifierProvider.notifier);
    TagLibraryEntry? entry;
    PortableThumbnailMutation? mutation;
    var step = 'create_entry';
    try {
      entry = await _addEntry(params);
      step = 'stage_thumbnail';
      mutation = await _thumbnailStore.stage(
        entry.id,
        extension: extension,
        bytes: Stream<List<int>>.value(bytes),
      );
      final persisted = entry.copyWith(
        thumbnail: mutation.path,
        updatedAt: DateTime.now(),
      );
      step = 'persist_thumbnail_link';
      await notifier.updateEntry(persisted, failOnPersistenceError: true);
      step = 'commit_thumbnail';
      await mutation.commit();
      return agentToolJsonResult({'ok': true, 'entry': _entryJson(persisted)});
    } on Object catch (error, stackTrace) {
      AppLogger.e(
        'Agent tag-library thumbnail failed: entryId=${entry?.id}, step=$step',
        error,
        stackTrace,
        'AgentTagLibrary',
      );
      final cleanupFailures = <String>[];
      var entryRollbackFailed = false;
      if (entry != null) {
        try {
          await notifier.deleteEntry(entry.id, failOnPersistenceError: true);
        } on Object catch (deleteError, deleteStackTrace) {
          AppLogger.e(
            'Agent tag-library entry rollback failed: entryId=${entry.id}',
            deleteError,
            deleteStackTrace,
            'AgentTagLibrary',
          );
          entryRollbackFailed = true;
          cleanupFailures.add('entry rollback: ${_safeFailure(deleteError)}');
        }
      }
      // A commit-stage failure may leave persistence pointing at the target.
      // Keep that target if entry rollback also failed, rather than creating a
      // broken persisted thumbnail reference.
      if (!(entryRollbackFailed && step == 'commit_thumbnail')) {
        try {
          await mutation?.rollback();
        } on Object catch (rollbackError, rollbackStackTrace) {
          AppLogger.e(
            'Agent tag-library thumbnail rollback failed: entryId=${entry?.id}',
            rollbackError,
            rollbackStackTrace,
            'AgentTagLibrary',
          );
          cleanupFailures.add(
            'thumbnail rollback: ${_safeFailure(rollbackError)}',
          );
        }
      }
      final cleanup = cleanupFailures.isEmpty
          ? ''
          : ' Cleanup also failed (${cleanupFailures.join('; ')}).';
      return agentToolError(
        cleanupFailures.isEmpty ? 'write_failed' : 'rollback_failed',
        'create_tag_library_entry: generated image ${reference.resourceId} '
        'thumbnail failed at $step (${_safeFailure(error)}).$cleanup',
      );
    }
  }

  String _safeFailure(Object error) => error.runtimeType.toString();

  Future<TagLibraryEntry> _addEntry(Map<String, dynamic> params) => _ref
      .read(tagLibraryPageNotifierProvider.notifier)
      .addEntry(
        name: params['name'] as String,
        content: params['content'] as String,
        tags: toolboxStrings(params['tags']),
        categoryId: params['category_id'] as String?,
        isFavorite: params['favorite'] as bool? ?? false,
        failOnPersistenceError: true,
      );

  DefinedAgentTool _updateEntry() => DefinedAgentTool(
    name: 'update_tag_library_entry',
    label: 'Update Tag Library Entry',
    description:
        'Update entry fields; linked fixed tags remain synchronized by the owning provider.',
    parameters: toolboxObject(
      properties: {
        'entry_id': {'type': 'string'},
        ..._entryMutationProperties,
        'clear_category': {'type': 'boolean'},
      },
      required: const ['entry_id'],
    ),
    executeFn: (_, params) async {
      final notifier = _ref.read(tagLibraryPageNotifierProvider.notifier);
      final entry = notifier.getEntry(params['entry_id'] as String);
      if (entry == null) {
        return agentToolError('not_found', 'Tag library entry not found.');
      }
      final category = params['clear_category'] == true
          ? null
          : params.containsKey('category_id')
          ? params['category_id'] as String?
          : entry.categoryId;
      final categoryError = _validateCategory(category);
      if (categoryError != null) return categoryError;
      final updated = entry.copyWith(
        name: params['name'] as String? ?? entry.name,
        content: params['content'] as String? ?? entry.content,
        tags: params.containsKey('tags')
            ? toolboxStrings(params['tags'])
            : entry.tags,
        categoryId: category,
        isFavorite: params['favorite'] as bool? ?? entry.isFavorite,
        updatedAt: DateTime.now(),
      );
      await notifier.updateEntry(updated, failOnPersistenceError: true);
      return agentToolJsonResult({'ok': true, 'entry': _entryJson(updated)});
    },
  );

  DefinedAgentTool _toggleFavorite() => DefinedAgentTool(
    name: 'toggle_tag_library_favorite',
    label: 'Toggle Tag Library Favorite',
    description: 'Toggle the favorite state of a reusable prompt entry.',
    parameters: _idSchema,
    executeFn: (_, params) async {
      final id = params['entry_id'] as String;
      if (_entry(id) == null) {
        return agentToolError('not_found', 'Tag library entry not found.');
      }
      await _ref
          .read(tagLibraryPageNotifierProvider.notifier)
          .toggleFavorite(id);
      return agentToolJsonResult({
        'ok': true,
        'entry': _entryJson(_entry(id)!),
      });
    },
  );

  DefinedAgentTool _deleteEntry() => toolboxIdTool(
    name: 'delete_tag_library_entry',
    label: 'Delete Tag Library Entry',
    description: 'Permanently delete a reusable prompt entry.',
    idKey: 'entry_id',
    execute: (id) async {
      if (_entry(id) == null) return false;
      await _ref.read(tagLibraryPageNotifierProvider.notifier).deleteEntry(id);
      return true;
    },
  );

  DefinedAgentTool _listCategories() => DefinedAgentTool(
    name: 'list_tag_library_categories',
    label: 'List Tag Library Categories',
    description: 'List the complete persisted tag-library category tree.',
    parameters: toolboxObject(),
    executeFn: (_, __) async {
      final state = _ref.read(tagLibraryPageNotifierProvider);
      return agentToolJsonResult({
        'ok': true,
        'categories': [
          for (final category in state.categories)
            _categoryJson(category, state.entries),
        ],
      });
    },
  );

  DefinedAgentTool _createCategory() => DefinedAgentTool(
    name: 'create_tag_library_category',
    label: 'Create Tag Library Category',
    description: 'Create a persisted category, optionally below a parent.',
    parameters: toolboxObject(
      properties: {
        'name': {'type': 'string'},
        'parent_id': {'type': 'string'},
      },
      required: const ['name'],
    ),
    executeFn: (_, params) async {
      final parentId = params['parent_id'] as String?;
      final error = _validateCategory(parentId);
      if (error != null) return error;
      final category = await _ref
          .read(tagLibraryPageNotifierProvider.notifier)
          .addCategory(name: params['name'] as String, parentId: parentId);
      return category == null
          ? agentToolError('duplicate_name', 'Category name already exists.')
          : agentToolJsonResult({
              'ok': true,
              'category': _categoryJson(category),
            });
    },
  );

  DefinedAgentTool _updateCategory() => DefinedAgentTool(
    name: 'update_tag_library_category',
    label: 'Update Tag Library Category',
    description: 'Rename or move a persisted category.',
    parameters: toolboxObject(
      properties: {
        'category_id': {'type': 'string'},
        'name': {'type': 'string'},
        'parent_id': {'type': 'string'},
        'move_to_root': {'type': 'boolean'},
      },
      required: const ['category_id'],
    ),
    executeFn: (_, params) async {
      final notifier = _ref.read(tagLibraryPageNotifierProvider.notifier);
      final state = _ref.read(tagLibraryPageNotifierProvider);
      final id = params['category_id'] as String;
      final category = state.categories
          .where((item) => item.id == id)
          .firstOrNull;
      if (category == null) {
        return agentToolError('not_found', 'Tag library category not found.');
      }
      final parentId = params['move_to_root'] == true
          ? null
          : params.containsKey('parent_id')
          ? params['parent_id'] as String?
          : category.parentId;
      if (state.categories.wouldCreateCycle(id, parentId)) {
        return agentToolError(
          'category_cycle',
          'Category move would create a cycle.',
        );
      }
      final parentError = _validateCategory(parentId);
      if (parentError != null) return parentError;
      final updated = category.copyWith(
        name: params['name'] as String? ?? category.name,
        parentId: parentId,
      );
      await notifier.updateCategory(updated);
      return agentToolJsonResult({
        'ok': true,
        'category': _categoryJson(updated),
      });
    },
  );

  DefinedAgentTool _deleteCategory() => toolboxIdTool(
    name: 'delete_tag_library_category',
    label: 'Delete Tag Library Category',
    description:
        'Delete a category using the owning provider’s existing descendant and entry migration semantics.',
    idKey: 'category_id',
    execute: (id) async {
      if (!_ref
          .read(tagLibraryPageNotifierProvider)
          .categories
          .any((c) => c.id == id)) {
        return false;
      }
      await _ref
          .read(tagLibraryPageNotifierProvider.notifier)
          .deleteCategory(id);
      return true;
    },
  );

  TagLibraryEntry? _entry(String id) =>
      _ref.read(tagLibraryPageNotifierProvider.notifier).getEntry(id);

  AgentToolResult? _validateCategory(String? id) {
    if (id == null) return null;
    return _ref
            .read(tagLibraryPageNotifierProvider)
            .categories
            .any((c) => c.id == id)
        ? null
        : agentToolError(
            'category_not_found',
            'Tag library category not found.',
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

String? _thumbnailExtension(Uint8List bytes) =>
    switch (detectSupportedImageMimeType(bytes)) {
      'image/png' => '.png',
      'image/jpeg' => '.jpg',
      'image/webp' => '.webp',
      'image/gif' => '.gif',
      'image/bmp' => '.bmp',
      _ => null,
    };

const _entryMutationProperties = <String, dynamic>{
  'name': {'type': 'string'},
  'content': {'type': 'string'},
  'tags': {
    'type': 'array',
    'items': {'type': 'string'},
    'maxItems': 100,
  },
  'category_id': {'type': 'string'},
  'favorite': {'type': 'boolean'},
};

Map<String, dynamic> _entryJson(
  TagLibraryEntry entry, [
  List<TagLibraryCategory> categories = const [],
]) => {
  'id': entry.id,
  'name': entry.name,
  'content': entry.content,
  'tags': entry.tags,
  'category_id': entry.categoryId,
  'category_path': entry.categoryId == null
      ? null
      : categories.getPathString(entry.categoryId!),
  'favorite': entry.isFavorite,
  'has_thumbnail': entry.hasThumbnail,
  'thumbnail_offset_x': entry.thumbnailOffsetX,
  'thumbnail_offset_y': entry.thumbnailOffsetY,
  'thumbnail_scale': entry.thumbnailScale,
  'sort_order': entry.sortOrder,
  'use_count': entry.useCount,
  'last_used_at': entry.lastUsedAt?.toIso8601String(),
  'created_at': entry.createdAt.toIso8601String(),
  'updated_at': entry.updatedAt.toIso8601String(),
};

Map<String, dynamic> _categoryJson(
  TagLibraryCategory category, [
  List<TagLibraryEntry> entries = const [],
]) => {
  'id': category.id,
  'name': category.name,
  'parent_id': category.parentId,
  'sort_order': category.sortOrder,
  'entry_count': entries
      .where((entry) => entry.categoryId == category.id)
      .length,
};
