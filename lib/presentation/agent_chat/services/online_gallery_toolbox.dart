import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../../core/online_gallery/gallery_tag_query.dart';
import '../../../data/datasources/remote/danbooru_api_service.dart';
import '../../../data/datasources/remote/online_gallery/gallery_source_adapter.dart';
import '../../../data/models/online_gallery/gallery_item.dart';
import '../../../data/models/online_gallery/gallery_source.dart';
import '../../providers/online_gallery_provider.dart';
import 'defined_agent_tool.dart';
import 'online_gallery_item_lookup.dart';
import 'online_gallery_resource_identity.dart';
import 'toolbox_json.dart';

/// Source-capability-aware tools for browsing and resolving online gallery works.
class OnlineGalleryToolbox {
  OnlineGalleryToolbox(this._ref);

  final Ref _ref;

  List<AgentTool> tools() => [
    _listSources(),
    _browse(),
    _searchCompatibility(),
    _detail(),
    _toggleFavorite(),
  ];

  DefinedAgentTool _listSources() => DefinedAgentTool(
    name: 'list_online_gallery_sources',
    label: 'List Online Gallery Sources',
    description:
        'List gallery sources and their verified feed and tag-search capabilities, including per-account server limits and client residual filtering.',
    parameters: toolboxObject(),
    executeFn: (_, __) async => agentToolJsonResult({
      'ok': true,
      'sources': [
        for (final source in GallerySourceId.values) _capabilitiesJson(source),
      ],
    }),
  );

  DefinedAgentTool _browse() => DefinedAgentTool(
    name: 'browse_online_gallery',
    label: 'Browse Online Gallery',
    description:
        'Browse an online gallery and return structured stable resource_ref objects only; this tool never displays images. '
        'When source is omitted, the request uses danbooru; an explicit valid source is always respected. '
        'Every call is defined by its own parameters: omitted filters use their defaults and never inherit what the visible gallery had before. '
        'A query may contain at most 6 ordinary tags globally. Sources can enforce lower server limits, so the client pushes down a supported seed and applies remaining tags as residual local filters. '
        'When random=true, limit=N means randomly sample exactly N items from the matching feed (when available); never fetch a larger page and choose items yourself. '
        'To show returned media, pass 1-12 resource_ref objects to display_images. '
        'media_id is null when the listing has no real cover yet; that resource_ref resolves to the first media of the work.',
    parameters: toolboxObject(
      properties: {
        'source': {
          'type': 'string',
          'enum': GallerySourceId.values.map((value) => value.key).toList(),
          'description':
              'Defaults to danbooru when omitted; explicit valid values select their matching adapter.',
        },
        'mode': {
          'type': 'string',
          'enum': ['search', 'ranking', 'favorites'],
        },
        'query': {
          'type': 'string',
          'maxLength': 1000,
          'description':
              'Space/comma-separated query with at most 6 ordinary tags; metatags do not count toward this global cap.',
        },
        'prompt': {
          'type': 'string',
          'maxLength': 4000,
          'description': 'Prompt filter; no prompt filter when omitted.',
        },
        'ratings': {
          'type': 'array',
          'items': {
            'type': 'string',
            'enum': ['g', 's', 'q', 'e'],
          },
          'maxItems': 4,
        },
        'fuzzy': {'type': 'boolean'},
        'random': {
          'type': 'boolean',
          'description':
              'If true, sample from the matching source/feed. Requires that source to advertise this mode in random_feeds.',
        },
        'ranking_scale': {
          'type': 'string',
          'enum': PopularScale.values.map((value) => value.name).toList(),
          'description':
              'Defaults to ${_browseDefaults.popularScale.name} when omitted.',
        },
        'ranking_date': {
          'type': 'string',
          'description': 'Defaults to the latest ranking when omitted.',
        },
        'ai_tag_time_range': {
          'type': 'string',
          'description':
              'Defaults to ${_browseDefaults.aiTagTimeRange} when omitted.',
        },
        'ai_tag_period': {
          'type': 'string',
          'description':
              'Defaults to ${_browseDefaults.aiTagPopularPeriod} when omitted.',
        },
        'load_more': {'type': 'boolean'},
        'limit': {
          'type': 'integer',
          'minimum': 1,
          'maximum': 100,
          'description':
              'Maximum returned items. With random=true this is the requested random sample size, not a candidate-page size.',
        },
      },
      required: const ['mode'],
    ),
    executeWithControl: (_, params, signal, __) =>
        _executeBrowse(params, signal),
  );

  Future<AgentToolResult> _executeBrowse(
    Map<String, dynamic> params,
    AbortSignal? signal,
  ) async {
    final source = _browseSource(params['source']);
    if (source == null) {
      return agentToolError('unknown_source', 'Unknown gallery source.');
    }
    final mode = params['mode'] as String;
    final capabilities = source.capabilities;
    if ((mode == 'ranking' && !capabilities.supportsRanking) ||
        (mode == 'favorites' && !capabilities.supportsFavorites)) {
      return agentToolError(
        'unsupported_mode',
        '${source.label} does not support $mode.',
      );
    }
    final query = GalleryTagQueryParser.parse(params['query'] as String? ?? '');
    if (!query.isValid) {
      return agentToolError(
        'too_many_query_tags',
        'Online gallery queries support at most $maxGallerySearchTags ordinary tags; received ${query.ordinaryTagCount}.',
      );
    }
    final feed = switch (mode) {
      'ranking' => GalleryFeedKind.ranking,
      'favorites' => GalleryFeedKind.favorites,
      _ => GalleryFeedKind.search,
    };
    if (params['random'] == true && !capabilities.supportsRandomFeed(feed)) {
      return agentToolError(
        'unsupported_random_feed',
        '${source.label} does not support random ${feed.name} results.',
      );
    }

    final notifier = _ref.read(onlineGalleryNotifierProvider.notifier);
    void abortGallery(String? reason) => notifier.cancelActiveRequests(
      reason: reason ?? 'Agent gallery tool cancelled',
      cancelDetails: true,
    );

    signal?.addListener(abortGallery);
    try {
      throwIfAborted(signal);
      return await notifier.runWithExplicitNetworkAccess(() async {
        final limit = (params['limit'] as int? ?? 30).clamp(1, 100);
        if (params['load_more'] == true) {
          final state = _ref.read(onlineGalleryNotifierProvider);
          if (state.activeSourceId != source || state.viewMode.name != mode) {
            return agentToolError(
              'pagination_scope_changed',
              'The active source or mode changed; start a new browse request.',
            );
          }
          await notifier.loadMore();
        } else {
          await _configureBrowse(notifier, source, mode, params, signal);
        }
        throwIfAborted(signal);
        var state = _ref.read(onlineGalleryNotifierProvider);
        if (state.errorCode != null || state.error != null) {
          return agentToolError(
            state.errorCode?.name ?? 'gallery_error',
            state.error ?? 'Online gallery request failed.',
          );
        }
        if (params['random'] == true && params['load_more'] != true) {
          while (state.posts.length < limit && state.hasMore) {
            final previousCount = state.posts.length;
            await notifier.loadMore();
            throwIfAborted(signal);
            state = _ref.read(onlineGalleryNotifierProvider);
            if (state.errorCode != null || state.error != null) {
              return agentToolError(
                state.errorCode?.name ?? 'gallery_error',
                state.error ?? 'Online gallery random sampling failed.',
              );
            }
            if (state.posts.length <= previousCount && state.hasMore) {
              return agentToolError(
                'random_sampling_stalled',
                'The gallery could not make progress while sampling matching results.',
              );
            }
          }
          if (state.posts.length < limit) {
            return agentToolError(
              'insufficient_random_matches',
              'Only ${state.posts.length} matching random items are available; $limit were requested.',
            );
          }
        }
        throwIfAborted(signal);
        return agentToolJsonResult({
          'ok': true,
          'source': source.key,
          'mode': state.viewMode.name,
          'random': params['random'] == true,
          'requested_limit': limit,
          'page': state.page,
          'has_more': state.hasMore,
          'total': state.currentCache.total,
          'items': [
            for (final item in state.posts.take(limit)) _itemJson(item),
          ],
        });
      });
    } finally {
      signal?.removeListener(abortGallery);
    }
  }

  DefinedAgentTool _searchCompatibility() => DefinedAgentTool(
    name: 'search_online_gallery',
    label: 'Search Online Gallery',
    description:
        'Compatibility search entry point; source defaults to danbooru when omitted. Use browse_online_gallery for all modes and filters.',
    parameters: toolboxObject(
      properties: {
        'source': {
          'type': 'string',
          'enum': GallerySourceId.values.map((value) => value.key).toList(),
          'description':
              'Defaults to danbooru when omitted; explicit valid values select their matching adapter.',
        },
        'query': {'type': 'string'},
        'limit': {'type': 'integer', 'minimum': 1, 'maximum': 100},
      },
      required: const ['query'],
    ),
    executeWithControl: (id, params, signal, onUpdate) =>
        _browse().execute(id, {...params, 'mode': 'search'}, signal, onUpdate),
  );

  DefinedAgentTool _detail() => DefinedAgentTool(
    name: 'get_online_gallery_detail',
    label: 'Get Online Gallery Detail',
    description:
        'Get a work directly by source and work_id without browsing first. '
        'Each image in media[] reports structured generation parameters in '
        'metadata and prompts in prompt, negative_prompt and character_prompts. '
        'Set include_raw_metadata to receive the original text in raw_metadata. '
        'This can add up to $_rawMetadataCharacterLimit Unicode code points per image.',
    parameters: toolboxObject(
      properties: {
        ..._identityProperties,
        'include_raw_metadata': {
          'type': 'boolean',
          'description':
              'Include raw_metadata and its truncation flag for each image. Defaults to false.',
        },
      },
      required: const ['source', 'work_id'],
    ),
    executeWithControl: (_, params, signal, __) =>
        _executeDetail(params, signal),
  );

  Future<AgentToolResult> _executeDetail(
    Map<String, dynamic> params,
    AbortSignal? signal,
  ) async {
    final source = _source(params['source']);
    if (source == null) {
      return agentToolError('unknown_source', 'Unknown gallery source.');
    }
    final identity = OnlineGalleryResourceIdentity(
      source: source,
      workId: params['work_id'] as String,
    );
    final notifier = _ref.read(onlineGalleryNotifierProvider.notifier);
    final lookupToken = CancelToken();
    GalleryItem? loadingItem;
    void abortDetail(String? reason) {
      lookupToken.cancel(reason);
      if (loadingItem case final item?) notifier.cancelDetail(item);
    }

    GalleryDetail? detail;
    signal?.addListener(abortDetail);
    try {
      throwIfAborted(signal);
      detail = await notifier.runWithExplicitNetworkAccess(() async {
        final item = await locateOnlineGalleryItem(
          identity,
          visibleItem: visibleOnlineGalleryItem(_ref, identity),
          adapter: _ref.read(onlineGallerySourceAdaptersProvider)[source]!,
          cancelToken: lookupToken,
        );
        throwIfAborted(signal);
        if (item == null) return null;
        loadingItem = item;
        return notifier.loadDetail(item);
      });
    } on GallerySourceException catch (error) {
      if (error.code != GallerySourceErrorCode.detailNotFound) rethrow;
    } finally {
      signal?.removeListener(abortDetail);
    }
    throwIfAborted(signal);
    if (detail == null) {
      return agentToolError('not_found', 'The requested work was not found.');
    }
    return agentToolJsonResult(
      _detailJson(
        detail,
        includeRawMetadata: params['include_raw_metadata'] == true,
      ),
    );
  }

  DefinedAgentTool _toggleFavorite() => DefinedAgentTool(
    name: 'toggle_online_gallery_favorite',
    label: 'Toggle Online Gallery Favorite',
    description: 'Toggle the existing device-local favorite for a loaded work.',
    parameters: _identitySchema,
    executeFn: (_, params) async {
      final item = _find(params);
      if (item == null) {
        return agentToolError('not_loaded', 'Browse the work first.');
      }
      if (!item.sourceId.capabilities.supportsLocalFavorites) {
        return agentToolError(
          'unsupported',
          'This source has no local favorites.',
        );
      }
      final favorite = await _ref
          .read(onlineGalleryNotifierProvider.notifier)
          .toggleFavorite(item);
      return agentToolJsonResult({
        'ok': true,
        'source': item.sourceId.key,
        'work_id': item.sourceWorkId,
        'favorite': favorite,
      });
    },
  );

  Future<void> _configureBrowse(
    OnlineGalleryNotifier notifier,
    GallerySourceId source,
    String mode,
    Map<String, dynamic> params,
    AbortSignal? signal,
  ) async {
    final ratings = toolboxStrings(params['ratings']);
    final random = params['random'] as bool? ?? false;
    final query = params['query'] as String? ?? '';
    final prompt = params['prompt'] as String? ?? '';
    await notifier.runWithDeferredLoading(() async {
      // A prior random session belongs to its original query and source. Leave
      // it before configuring a new request so enabling random resamples.
      await notifier.setRandomEnabled(false);
      await notifier.setRatings(ratings.toSet());
      await notifier.setFuzzySearchEnabled(params['fuzzy'] as bool? ?? false);
      await notifier.setArtistHuntEnabled(_browseDefaults.artistHuntEnabled);
      if (mode == 'ranking') {
        await notifier.setPopularSource(source);
        await notifier.switchToPopular();
        await notifier.setPopularScale(switch (params['ranking_scale']) {
          final String name => PopularScale.values.byName(name),
          _ => _browseDefaults.popularScale,
        });
        await notifier.setPopularDate(switch (params['ranking_date']) {
          final String date => DateTime.parse(date),
          _ => _browseDefaults.popularDate,
        });
        await notifier.setAiTagPopularPeriod(
          params['ai_tag_period'] as String? ??
              _browseDefaults.aiTagPopularPeriod,
        );
        await notifier.searchPopular(query: query, prompt: prompt);
      } else if (mode == 'favorites') {
        await notifier.setFavoritesSource(source);
        await notifier.switchToFavorites();
        await notifier.searchFavorites(query);
      } else {
        await notifier.setSource(source);
        await notifier.switchToSearch();
        await notifier.clearDateRange();
        await notifier.setAiTagTimeRange(
          params['ai_tag_time_range'] as String? ??
              _browseDefaults.aiTagTimeRange,
        );
        await notifier.searchWithPrompt(query, prompt: prompt);
      }
      if (random) await notifier.setRandomEnabled(true);
    });
    throwIfAborted(signal);
    await notifier.loadPosts(refresh: true);
  }

  GalleryItem? _find(Map<String, dynamic> params) {
    final source = _source(params['source']);
    if (source == null) return null;
    final identity = OnlineGalleryResourceIdentity(
      source: source,
      workId: params['work_id'] as String,
    );
    return visibleOnlineGalleryItem(_ref, identity);
  }
}

const _browseDefaults = OnlineGalleryState();

GallerySourceId? _browseSource(dynamic value) =>
    value == null ? GallerySourceId.danbooru : _source(value);

GallerySourceId? _source(dynamic value) =>
    GallerySourceId.values.where((source) => source.key == value).firstOrNull;

Map<String, dynamic> _capabilitiesJson(GallerySourceId source) {
  final value = source.capabilities;
  return {
    'source': source.key,
    'label': source.label,
    'search': value.supportsSearch,
    'fuzzy': value.supportsFuzzySearch,
    'date_range': value.supportsDateRange,
    'ratings': value.supportsRatings,
    'prompt_query': value.supportsPromptQuery,
    'ranking': value.rankingKinds.map((kind) => kind.name).toList(),
    'favorites': value.supportsFavorites,
    'writable_remote_favorites': value.supportsWritableFavorites,
    'details': value.supportsDetails,
    'multiple_media': value.supportsMultipleMedia,
    'random_feeds': value.randomFeeds.map((feed) => feed.name).toList(),
    'tag_search': {
      'strategy': value.tagSearch.strategy.name,
      'max_query_tags': maxGallerySearchTags,
      'server_limits': {
        'anonymous': value.tagSearch.anonymousLimit,
        if (value.tagSearch.authenticatedLimit case final limit?)
          'authenticated': limit,
        if (value.tagSearch.goldLimit case final limit?) 'gold': limit,
        if (value.tagSearch.unlimitedFromLevel case final level?)
          'max_query_tags_from_account_level': level,
      },
      'residual_filtering':
          'Ordinary tags beyond the active server limit are evaluated by the client against returned item tags; the global query cap remains $maxGallerySearchTags.',
    },
  };
}

Map<String, dynamic> _itemJson(GalleryItem item) => {
  'source': item.sourceId.key,
  'work_id': item.sourceWorkId,
  'media_id': item.coverMediaId,
  'resource_ref': AgentChatResourceReferenceCodec.encodeJsonMap(
    OnlineGalleryResourceIdentity.coverOf(item).toReference(
      display: {
        'source_label': item.sourceId.label,
        if (item.title?.trim().isNotEmpty == true) 'title': item.title!.trim(),
        if (item.author?.trim().isNotEmpty == true)
          'author': item.author!.trim(),
      },
    ),
  ),
  'title': item.title,
  'author': item.author,
  'rating': item.rating,
  'width': item.width,
  'height': item.height,
  'media_count': item.mediaCount,
  'tags': item.tags,
};

Map<String, dynamic> _detailJson(
  GalleryDetail detail, {
  required bool includeRawMetadata,
}) => {
  'ok': true,
  'item': _itemJson(detail.item),
  'prompt': detail.prompt,
  'negative_prompt': detail.negativePrompt,
  'description': detail.description,
  'tags': detail.rawTags,
  'character_prompts': [
    for (final character in detail.characterPrompts) _characterJson(character),
  ],
  'contributors': [
    for (final contributor in detail.contributors)
      {'name': contributor.name, 'role': contributor.role},
  ],
  'media': [
    for (final media in detail.media)
      _mediaJson(
        media,
        source: detail.item.sourceId,
        workId: detail.item.sourceWorkId,
        title: detail.item.title,
        includeRawMetadata: includeRawMetadata,
      ),
  ],
};

Map<String, dynamic> _characterJson(GalleryCharacterPrompt character) => {
  'label': character.label,
  'prompt': character.prompt,
  'negative_prompt': character.negativePrompt,
};

Map<String, dynamic> _mediaJson(
  GalleryMedia media, {
  required GallerySourceId source,
  required String workId,
  required bool includeRawMetadata,
  String? title,
}) => {
  'media_id': media.id,
  'resource_ref': AgentChatResourceReferenceCodec.encodeJsonMap(
    OnlineGalleryResourceIdentity(
      source: source,
      workId: workId,
      mediaId: media.id,
    ).toReference(
      display: {
        'source_label': source.label,
        if (title?.trim().isNotEmpty == true) 'title': title!.trim(),
      },
    ),
  ),
  'width': media.width,
  'height': media.height,
  'mime_type': media.mimeType,
  'media_type': media.mediaType,
  'prompt': media.prompt,
  'negative_prompt': media.negativePrompt,
  'metadata': media.generationParametersFor(source),
  if (media.metadataFormat != null) 'metadata_format': media.metadataFormat,
  if (media.metadataError != null) 'metadata_error': media.metadataError,
  'character_prompts': [
    for (final character in media.characterPrompts)
      {
        ..._characterJson(character),
        if (character.hasCustomPosition) ...{
          'position_x': character.positionX,
          'position_y': character.positionY,
        },
      },
  ],
  if (includeRawMetadata) ..._rawMetadataJson(media.rawMetadata),
};

const _rawMetadataCharacterLimit = 8000;

Map<String, dynamic> _rawMetadataJson(String? raw) {
  final text = raw == null
      ? null
      : String.fromCharCodes(raw.runes.take(_rawMetadataCharacterLimit));
  return {'raw_metadata': text, 'raw_metadata_truncated': text != raw};
}

final _identityProperties = <String, dynamic>{
  'source': {
    'type': 'string',
    'enum': GallerySourceId.values.map((value) => value.key).toList(),
  },
  'work_id': {'type': 'string'},
};

final _identitySchema = toolboxObject(
  properties: _identityProperties,
  required: const ['source', 'work_id'],
);
