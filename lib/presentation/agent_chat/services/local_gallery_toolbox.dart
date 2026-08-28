import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/harness/tools/image.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../../core/database/database_providers.dart';
import '../../../core/utils/display_thumbnail_utils.dart';
import '../../providers/local_gallery_provider.dart';
import 'defined_agent_tool.dart';
import 'toolbox_json.dart';

/// Indexed local-gallery search, metadata, preview, and favorite tools.
class LocalGalleryToolbox {
  LocalGalleryToolbox(this._ref);

  final Ref _ref;

  List<AgentTool> tools() => [
    _search(),
    _detail(),
    _preview(),
    _toggleFavorite(),
  ];

  DefinedAgentTool _search() => DefinedAgentTool(
    name: 'search_local_gallery',
    label: 'Search Local Gallery',
    description:
        'Search indexed local images by metadata text, tags, favorite, date, model, dimensions, and file size.',
    parameters: toolboxObject(
      properties: {
        'query': {'type': 'string', 'maxLength': 1000},
        'tags': {
          'type': 'array',
          'items': {'type': 'string'},
          'maxItems': 50,
        },
        'favorites_only': {'type': 'boolean'},
        'date_start': {'type': 'string'},
        'date_end': {'type': 'string'},
        'model': {'type': 'string'},
        'sampler': {'type': 'string'},
        'min_steps': {'type': 'integer', 'minimum': 1},
        'max_steps': {'type': 'integer', 'minimum': 1},
        'min_width': {'type': 'integer', 'minimum': 1},
        'min_height': {'type': 'integer', 'minimum': 1},
        'max_width': {'type': 'integer', 'minimum': 1},
        'max_height': {'type': 'integer', 'minimum': 1},
        'min_file_size': {'type': 'integer', 'minimum': 0},
        'max_file_size': {'type': 'integer', 'minimum': 0},
        'metadata_statuses': {
          'type': 'array',
          'items': {'type': 'string'},
          'maxItems': 8,
        },
        'limit': {'type': 'integer', 'minimum': 1, 'maximum': 100},
      },
    ),
    executeFn: (_, params) async {
      final notifier = _ref.read(localGalleryNotifierProvider.notifier);
      await notifier.initialize();
      await notifier.clearAllFilters();
      await notifier.setSearchQuery(params['query'] as String? ?? '');
      await notifier.setSelectedTags(toolboxStrings(params['tags']));
      await notifier.setShowFavoritesOnly(params['favorites_only'] == true);
      await notifier.setDateRange(
        _date(params['date_start']),
        _date(params['date_end']),
      );
      await notifier.setFilterModel(params['model'] as String?);
      await notifier.setFilterSampler(params['sampler'] as String?);
      await notifier.setFilterSteps(
        params['min_steps'] as int?,
        params['max_steps'] as int?,
      );
      await notifier.setDimensionRange(
        minWidth: params['min_width'] as int?,
        minHeight: params['min_height'] as int?,
        maxWidth: params['max_width'] as int?,
        maxHeight: params['max_height'] as int?,
      );
      await notifier.setFileSizeRange(
        minBytes: params['min_file_size'] as int?,
        maxBytes: params['max_file_size'] as int?,
      );
      await notifier.setMetadataStatuses(
        toolboxStrings(params['metadata_statuses']),
      );
      final state = _ref.read(localGalleryNotifierProvider);
      final records = state.currentImages
          .take((params['limit'] as int? ?? 50).clamp(1, 100))
          .toList();
      final dataSource = (await _ref.read(
        databaseManagerProvider.future,
      )).galleryDataSource;
      if (dataSource == null) {
        return agentToolError('unavailable', 'Gallery database unavailable.');
      }
      final ids = await dataSource.getImageIdsByPaths([
        for (final record in records) record.path,
      ]);
      return agentToolJsonResult({
        'ok': true,
        'total': state.filteredCount,
        'page': state.currentPage,
        'page_size': state.pageSize,
        'items': [
          for (final record in records)
            if (ids[record.path] case final int id)
              {
                'image_id': id,
                'resource_ref': AgentChatResourceReferenceCodec.encodeJsonMap(
                  AgentChatResourceReference(
                    kind: AgentChatResourceKind.localGalleryImage,
                    source: 'local_gallery',
                    resourceId: '$id',
                    display: {'title': _basename(record.path)},
                  ),
                ),
                'name': _basename(record.path),
                'size': record.size,
                'modified_at': record.modifiedAt.toIso8601String(),
                'favorite': record.isFavorite,
                'tags': record.tags,
                'has_metadata': record.hasMetadata,
                'has_vibe_metadata': record.hasVibeMetadata,
              },
        ],
      });
    },
  );

  DefinedAgentTool _detail() => DefinedAgentTool(
    name: 'get_local_gallery_detail',
    label: 'Get Local Gallery Detail',
    description:
        'Read indexed generation metadata for a local image by stable database ID. Raw metadata fields that may embed paths, URLs, or image data are excluded.',
    parameters: _identitySchema,
    executeFn: (_, params) async {
      final data = await _load(params['image_id'] as int);
      if (data.error != null) return data.error!;
      final metadata = await data.source!.getMetadataByImageId(data.id);
      final tags = await data.source!.getImageTags(data.id);
      return agentToolJsonResult({
        'ok': true,
        'image_id': data.id,
        'name': data.record!.fileName,
        'size': data.record!.fileSize,
        'width': data.record!.width,
        'height': data.record!.height,
        'favorite': await data.source!.isFavorite(data.id),
        'tags': tags,
        'prompt': metadata?.prompt,
        'negative_prompt': metadata?.negativePrompt,
        'seed': metadata?.seed,
        'model': metadata?.model,
        'sampler': metadata?.sampler,
        'steps': metadata?.steps,
        'scale': metadata?.scale,
        'noise_schedule': metadata?.noiseSchedule,
        'cfg_rescale': metadata?.cfgRescale,
        'smea': metadata?.smea,
        'smea_dyn': metadata?.smeaDyn,
        'img2img': metadata?.isImg2Img,
        'strength': metadata?.strength,
        'noise': metadata?.noise,
        'software': metadata?.software,
        'version': metadata?.version,
      });
    },
  );

  DefinedAgentTool _preview() => DefinedAgentTool(
    name: 'preview_local_gallery_image',
    label: 'Preview Local Gallery Image',
    description:
        'Return a bounded preview for a local image without revealing its file path.',
    parameters: _identitySchema,
    executeFn: (_, params) async {
      final data = await _load(params['image_id'] as int);
      if (data.error != null) return data.error!;
      final thumbnail = await DisplayThumbnailUtils.normalize(
        await File(data.record!.filePath).readAsBytes(),
      );
      if (thumbnail == null) {
        return agentToolError('preview_invalid', 'Image preview is invalid.');
      }
      final mime = detectSupportedImageMimeType(thumbnail);
      if (mime == null) {
        return agentToolError('preview_invalid', 'Unsupported preview format.');
      }
      final details = <String, dynamic>{
        'ok': true,
        'image_id': data.id,
        'name': data.record!.fileName,
      };
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

  DefinedAgentTool _toggleFavorite() => DefinedAgentTool(
    name: 'toggle_local_gallery_favorite',
    label: 'Toggle Local Gallery Favorite',
    description: 'Toggle a local image favorite by stable database ID.',
    parameters: _identitySchema,
    executeFn: (_, params) async {
      final data = await _load(params['image_id'] as int);
      if (data.error != null) return data.error!;
      final favorite = await _ref
          .read(localGalleryNotifierProvider.notifier)
          .toggleFavorite(data.record!.filePath);
      return agentToolJsonResult({
        'ok': true,
        'image_id': data.id,
        'favorite': favorite,
      });
    },
  );

  Future<_LoadedLocalImage> _load(int id) async {
    final source = (await _ref.read(
      databaseManagerProvider.future,
    )).galleryDataSource;
    if (source == null) {
      return _LoadedLocalImage(
        id,
        error: agentToolError('unavailable', 'Gallery database unavailable.'),
      );
    }
    final record = await source.getImageById(id);
    if (record == null ||
        record.isDeleted ||
        !File(record.filePath).existsSync()) {
      return _LoadedLocalImage(
        id,
        error: agentToolError(
          'not_found',
          'Local image is no longer available.',
        ),
      );
    }
    return _LoadedLocalImage(id, source: source, record: record);
  }
}

class _LoadedLocalImage {
  const _LoadedLocalImage(this.id, {this.source, this.record, this.error});

  final int id;
  final dynamic source;
  final dynamic record;
  final AgentToolResult? error;
}

DateTime? _date(dynamic value) =>
    value is String && value.isNotEmpty ? DateTime.tryParse(value) : null;

final _identitySchema = toolboxObject(
  properties: {
    'image_id': {'type': 'integer', 'minimum': 1},
  },
  required: const ['image_id'],
);

String _basename(String path) => path.split(RegExp(r'[/\\]')).last;
