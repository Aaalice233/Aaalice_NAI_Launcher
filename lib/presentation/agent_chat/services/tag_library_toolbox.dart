import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/harness/tools/image.dart';
import '../../../core/utils/display_thumbnail_utils.dart';
import '../../../data/models/tag_library/tag_library_category.dart';
import '../../../data/models/tag_library/tag_library_entry.dart';
import '../../providers/tag_library_page_provider.dart';
import 'defined_agent_tool.dart';
import 'toolbox_json.dart';

/// Production tools for the reusable tag library and its category tree.
class TagLibraryToolbox {
  TagLibraryToolbox(this._ref);

  final Ref _ref;

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
      final offset = (params['offset'] as int? ?? 0).clamp(0, 1 << 30);
      final limit = (params['limit'] as int? ?? 50).clamp(1, 200);
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
    description: 'Create a persisted reusable prompt entry.',
    parameters: toolboxObject(
      properties: _entryMutationProperties,
      required: const ['name', 'content'],
    ),
    executeFn: (_, params) async {
      final categoryError = _validateCategory(params['category_id'] as String?);
      if (categoryError != null) return categoryError;
      final entry = await _ref
          .read(tagLibraryPageNotifierProvider.notifier)
          .addEntry(
            name: params['name'] as String,
            content: params['content'] as String,
            tags: toolboxStrings(params['tags']),
            categoryId: params['category_id'] as String?,
            isFavorite: params['favorite'] as bool? ?? false,
            failOnPersistenceError: true,
          );
      return agentToolJsonResult({'ok': true, 'entry': _entryJson(entry)});
    },
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
