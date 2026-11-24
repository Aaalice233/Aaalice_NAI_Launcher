import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/mcp/mcp_tool_adapter.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/datasources/remote/danbooru_api_service.dart';
import 'package:nai_launcher/data/datasources/remote/online_gallery/gallery_source_adapter.dart';
import 'package:nai_launcher/data/datasources/remote/online_gallery/quick_tag_cloud_gallery_query.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/presentation/agent_chat/services/online_gallery_toolbox.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_provider.dart';
import 'package:nai_launcher/presentation/providers/quick_tag_cloud_gallery_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../helpers/ai_tag_character_gallery.dart';
import '../../../helpers/memory_local_storage.dart';

final _refProvider = Provider<Ref>((ref) => ref);

void main() {
  late ProviderContainer container;
  late List<AgentTool> tools;

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    container = ProviderContainer();
    tools = OnlineGalleryToolbox(container.read(_refProvider)).tools();
  });

  tearDown(() => container.dispose());

  AgentTool tool(String name) => tools.singleWhere((tool) => tool.name == name);

  test('unlisted AI TAG details include each image’s metadata', () async {
    const params = {'source': 'ai_tag', 'work_id': '42'};
    const parameters = {
      'seed': 123,
      'sampler': 'euler',
      'steps': 28,
      'scale': 6.0,
      'model': 'test',
      'software': 'NovelAI',
      'source_model': 'test source',
      'aiTagImageType': 'NovelAI',
      'aiTagModel': 'test model',
      'aiTagModelHash': '1234abcd',
      'aiTagVae': 'test vae',
      'aiTagSampler': 'euler',
    };
    var calls = 0;
    final adapter = _DetailAdapter(GallerySourceId.aiTag, (item, _) async {
      calls++;
      expect(item.id, 42);
      expect(item.sourceWorkId, '42');
      return GalleryDetail(
        item: item,
        media: const [
          GalleryMedia(
            id: '42_p0',
            metadata: {...parameters, 'source_data': 'source text'},
            metadataFormat: 'NovelAI',
            rawMetadata: 'original',
            promptMetadata: NaiImageMetadata(
              characterInfos: [
                CharacterPromptInfo(
                  prompt: 'green eyes',
                  centerX: 0.2,
                  centerY: 0.7,
                ),
              ],
              characterPrompts: ['unused', 'silver ribbon'],
              characterNegativePrompts: ['glasses', 'lowres', 'negative only'],
            ),
          ),
          GalleryMedia(id: '42_p1', metadataError: 'unknown format'),
        ],
      );
    });
    final harness = _createHarness({GallerySourceId.aiTag: adapter});
    addTearDown(harness.container.dispose);
    harness.container
        .read(onlineGalleryNotifierProvider.notifier)
        .setBackgroundNetworkPaused(true);

    final result = await harness.detail.execute('detail', params);
    expect(result.isError, isFalse);
    expect(result.details['character_prompts'], isEmpty);
    final images = result.details['media'] as List;
    expect(images[0]['metadata'], parameters);
    expect(images[0]['metadata_format'], 'NovelAI');
    expect(images[0], isNot(contains('metadata_error')));
    expect(images[0]['character_prompts'], [
      {
        'label': '',
        'prompt': 'green eyes',
        'negative_prompt': 'glasses',
        'position_x': 0.2,
        'position_y': 0.7,
      },
      {'label': '', 'prompt': 'silver ribbon', 'negative_prompt': 'lowres'},
      {'label': '', 'prompt': '', 'negative_prompt': 'negative only'},
    ]);
    expect(images[1]['metadata_error'], 'unknown format');
    expect(images[1]['metadata'], isEmpty);
    expect(images[1], isNot(contains('metadata_format')));
    expect(images[1]['character_prompts'], isEmpty);
    for (final image in images) {
      expect(image, isNot(contains('raw_metadata')));
      expect(image, isNot(contains('raw_metadata_truncated')));
    }
    final repeat = await harness.detail.execute('cached', params);
    expect(repeat.details, result.details);
    expect(calls, 1);
    final state = harness.container.read(onlineGalleryNotifierProvider);
    expect(state.posts, isEmpty);
    final toggle = OnlineGalleryToolbox(harness.container.read(_refProvider))
        .tools()
        .singleWhere((tool) => tool.name == 'toggle_online_gallery_favorite');
    final favorite = await toggle.execute('favorite', params);
    expect(favorite.details['code'], 'not_loaded');
  });

  test('AI TAG exposes original metadata only in the opt-in raw field', () async {
    const source = GallerySourceId.aiTag;
    const params = {'source': 'ai_tag', 'work_id': '11'};
    final harness = _createHarness({source: aiTagCharacterGallery()});
    addTearDown(harness.container.dispose);

    final compact = await harness.detail.execute('compact', params);
    final expanded = await harness.detail.execute('raw', {
      ...params,
      'include_raw_metadata': true,
    });
    final original = harness.container
        .read(onlineGalleryNotifierProvider.notifier)
        .peekDetail(const GalleryItem(id: 11, sourceId: source))!;
    expect(original.media, hasLength(2));
    final compactJson = jsonEncode(compact.details);
    final expandedJson = jsonEncode(expanded.details);

    for (final (index, image) in original.media.indexed) {
      final full = image.metadata['aiTag'] as Map;
      final raw = image.rawMetadata!;
      final pretty = full['prettyJson'] as String;
      expect(full['rawJson'], raw);
      expect(pretty, isNot(raw));
      expect(full['prompt'], 'sunset');
      expect(full['negativePrompt'], 'blue cape, main negative');
      final expected = Map.of(full)
        ..remove('rawJson')
        ..remove('prettyJson')
        ..remove('prompt')
        ..remove('negativePrompt');
      final media = compact.details['media'][index] as Map;
      expect(media['metadata'], {...image.metadata, 'aiTag': expected});
      expect(media['metadata']['aiTag']['seed'], 123);
      expect(media['prompt'], full['prompt']);
      expect(media['negative_prompt'], full['negativePrompt']);
      expect(media, isNot(contains('raw_metadata')));
      expect(compactJson, isNot(contains(jsonEncode(raw))));
      expect(compactJson, isNot(contains(jsonEncode(pretty))));
      expect(expanded.details['media'][index], {
        ...media,
        'raw_metadata': raw,
        'raw_metadata_truncated': false,
      });
      expect(expandedJson.split(jsonEncode(raw)), hasLength(2));
      expect(expandedJson, isNot(contains(jsonEncode(pretty))));
    }
  });

  test('raw metadata is opt-in and capped per image at 8000 runes', () async {
    final boundary = '${'x' * 7999}😀';
    const workId = 'book/entry%2F1';
    const source = GallerySourceId.quickTagCloud;
    final adapter = _DetailAdapter(source, (item, _) async {
      expect(item.sourceWorkId, workId);
      return GalleryDetail(
        item: item,
        characterPrompts: const [GalleryCharacterPrompt(label: 'A', prompt: 'solo')],
        media: [
          GalleryMedia(
            id: 'a',
            rawMetadata: '$boundary尾',
            metadata: {'path': 'a.webp', 'rawTag': '$boundary尾'},
          ),
          GalleryMedia(
            id: 'b',
            rawMetadata: boundary,
            metadata: {'hasOriginal': true, 'rawTags': boundary},
          ),
          const GalleryMedia(id: 'c', rawMetadata: 'short'),
          const GalleryMedia(id: 'd'),
        ],
      );
    });
    final harness = _createHarness({source: adapter});
    addTearDown(harness.container.dispose);
    const params = {'source': 'quick_tag_cloud', 'work_id': workId};
    final descriptor = jsonDecode(jsonEncode(
      McpToolAdapter.toMcpTool(harness.detail),
    )) as Map;
    final schema = descriptor['inputSchema'] as Map;
    expect(schema['properties']['include_raw_metadata']['type'], 'boolean');
    expect(schema['required'], isNot(contains('include_raw_metadata')));
    expect(descriptor['annotations']['readOnlyHint'], isTrue);
    final result = await harness.detail.execute('raw', {
      ...params,
      'include_raw_metadata': true,
    });
    expect(result.details['character_prompts'], [
      {'label': 'A', 'prompt': 'solo', 'negative_prompt': ''},
    ]);
    final media = (result.details['media'] as List).cast<Map>();
    expect(media.map((image) => image['metadata']), everyElement(isEmpty));
    expect(McpToolAdapter.toCallToolResult(result).structuredContent, result.details);
    expect(
      media.map((image) => image['raw_metadata']),
      [boundary, boundary, 'short', null],
    );
    expect(
      media.map((image) => image['raw_metadata_truncated']),
      [true, false, false, false],
    );
    final compact = await harness.detail.execute('compact', {
      ...params,
      'include_raw_metadata': false,
    });
    for (final image in compact.details['media'] as List) {
      expect(image['metadata'], isEmpty);
      expect(image, isNot(contains('raw_metadata')));
      expect(image, isNot(contains('raw_metadata_truncated')));
    }
  });

  test('a detail aborted before network access skips lookup and load', () async {
    final controller = AbortController();
    final booru = _ScriptedGalleryAdapter(
      GallerySourceId.danbooru,
      (request, _) => _page(request, [_item(GallerySourceId.danbooru, 9, [])]),
    );
    var detailCalls = 0;
    final scoped = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWith((_) {
          // Cancel during gallery initialization, after the tool dispatcher checks.
          controller.abort('before lookup');
          return MemoryLocalStorage();
        }),
        onlineGallerySourceAdaptersProvider.overrideWithValue({
          GallerySourceId.danbooru: booru,
          GallerySourceId.aiTag: _DetailAdapter(
            GallerySourceId.aiTag,
            (item, _) async {
              detailCalls++;
              return GalleryDetail(item: item, media: [item.cover]);
            },
          ),
        }),
      ],
    );
    addTearDown(scoped.dispose);
    final detail = OnlineGalleryToolbox(scoped.read(_refProvider))
        .tools()
        .singleWhere((tool) => tool.name == 'get_online_gallery_detail');

    for (final source in ['danbooru', 'ai_tag']) {
      await expectLater(
        () => detail.execute(
          'cancelled',
          {'source': source, 'work_id': '9'},
          controller.signal,
        ),
        throwsStateError,
      );
      expect(controller.signal.aborted, isTrue);
    }
    expect(booru.requests, isEmpty);
    expect(detailCalls, 0);
  });

  for (final source in [
    GallerySourceId.danbooru,
    GallerySourceId.safebooru,
    GallerySourceId.gelbooru,
  ]) {
    test('${source.key} direct lookup finds the work by id', () async {
      final adapter = _ScriptedGalleryAdapter(
        source,
        (request, _) => _page(request, [_item(source, 42, ['found_tag'])]),
      );
      final harness = _createHarness({source: adapter}, blacklist: ['found_tag']);
      addTearDown(harness.container.dispose);
      final found = await harness.detail.execute('detail', {
        'source': source.key,
        'work_id': '42',
      });
      expect(found.details['item']['tags'], ['found_tag']);
      expect(adapter.requests.single.query, 'id:42');
      expect(adapter.requests.single.pageSize, 1);
      expect(adapter.requests.single.blacklistTags, isEmpty);
      final missing = await harness.detail.execute('missing', {
        'source': source.key,
        'work_id': '43',
      });
      expect(missing.isError, isTrue);
      expect(missing.details['code'], 'not_found');
    });
  }

  test('missing AI TAG and booru works yield not_found', () async {
    const source = GallerySourceId.aiTag;
    final harness = _createHarness({
      source: _DetailAdapter(source, (_, _) async {
        throw const GallerySourceException(GallerySourceErrorCode.detailNotFound);
      }),
    });
    addTearDown(harness.container.dispose);
    for (final sourceKey in ['ai_tag', 'danbooru']) {
      final result = await harness.detail.execute('missing', {
        'source': sourceKey,
        'work_id': '404',
      });
      expect(result.isError, isTrue);
      expect(result.details['code'], 'not_found');
    }
    final unknown = await harness.detail.execute('bad-source', {
      'source': 'bogus',
      'work_id': '1',
    });
    expect(unknown.details['code'], 'unknown_source');
  });

  test('direct detail propagates other source failures', () async {
    const source = GallerySourceId.aiTag;
    const error = GallerySourceException(GallerySourceErrorCode.malformedResponse);
    final harness = _createHarness({
      source: _DetailAdapter(source, (_, _) async => throw error),
    });
    addTearDown(harness.container.dispose);
    await expectLater(
      harness.detail.execute('invalid', {'source': source.key, 'work_id': '7'}),
      throwsA(same(error)),
    );
  });

  for (final source in [
    GallerySourceId.danbooru,
    GallerySourceId.safebooru,
    GallerySourceId.aiTag,
  ]) {
    test('abort cancels the active ${source.key} request', () async {
      final started = Completer<CancelToken>();
      Future<DioException> waitForAbort(CancelToken token) {
        started.complete(token);
        return token.whenCancel;
      }
      final item = _item(source, 9, ['late']);
      final harness = _createHarness({
        source: source == GallerySourceId.aiTag
            ? _DetailAdapter(source, (_, token) async {
                throw await waitForAbort(token!);
              })
            : _ScriptedGalleryAdapter(source, (request, token) async {
                await waitForAbort(token!);
                if (source == GallerySourceId.safebooru) {
                  throw const GallerySourceException(
                    GallerySourceErrorCode.detailNotFound,
                  );
                }
                return _page(request, [item]);
              }),
      });
      addTearDown(harness.container.dispose);
      final controller = AbortController();
      final pending = harness.detail.execute(
        'cancel-detail',
        {'source': source.key, 'work_id': '9'},
        controller.signal,
      );
      await Future.any([started.future, pending]);
      expect(started.isCompleted, isTrue);
      final failed = expectLater(
        pending,
        throwsA(source == GallerySourceId.aiTag ? anything : isA<StateError>()),
      );
      controller.abort('stop');
      expect((await started.future).isCancelled, isTrue);
      await failed;
      final notifier = harness.container.read(
        onlineGalleryNotifierProvider.notifier,
      );
      expect(notifier.peekDetail(item), isNull);
    });
  }

  test('browse contract defines bounded tags and danbooru default', () {
    final browse = tool('browse_online_gallery');
    final properties = browse.parameters['properties'] as Map;
    final required = browse.parameters['required'] as List;

    expect(browse.description, contains('at most 6 ordinary tags'));
    expect(browse.description, contains('source is omitted'));
    expect(required, isNot(contains('source')));
    expect(properties['source']['description'], contains('danbooru'));
    expect(browse.description, contains('random=true, limit=N'));
    expect(browse.description, contains('display_images'));
    expect(properties['query']['description'], contains('at most 6'));
    expect(properties['random']['description'], contains('random_feeds'));
    expect(properties['limit']['description'], contains('sample size'));
    expect(properties['limit']['minimum'], 1);
  });

  test(
    'browse rejects more than six ordinary tags before loading gallery',
    () async {
      final result = await tool('browse_online_gallery').execute('too-many', {
        'source': 'danbooru',
        'mode': 'search',
        'query': 'one two three four five six seven',
      });

      expect(result.isError, isTrue);
      expect(result.details, containsPair('code', 'too_many_query_tags'));
    },
  );

  test('source list explains tier limits and residual filtering', () async {
    final result = await tool(
      'list_online_gallery_sources',
    ).execute('list', {});
    final sources = result.details['sources'] as List;
    final danbooru = sources.cast<Map>().singleWhere(
      (source) => source['source'] == 'danbooru',
    );
    final tagSearch = danbooru['tag_search'] as Map;

    expect(tagSearch['strategy'], 'accountTierSeedResidual');
    expect(tagSearch['max_query_tags'], 6);
    expect(tagSearch['server_limits'], {
      'anonymous': 2,
      'authenticated': 2,
      'gold': 6,
      'max_query_tags_from_account_level': 31,
    });
    expect(tagSearch['residual_filtering'], contains('client'));
  });

  test(
    'source list declares no date range the browse tool cannot set',
    () async {
      final result = await tool(
        'list_online_gallery_sources',
      ).execute('list', {});
      final browseParameters =
          tool('browse_online_gallery').parameters['properties'] as Map;

      expect(browseParameters.keys, isNot(contains('date_start')));
      expect(browseParameters.keys, isNot(contains('date_end')));
      for (final source in (result.details['sources'] as List).cast<Map>()) {
        expect(source.containsKey('date_range'), isFalse);
      }
    },
  );

  test('display_images remains the only explicit display contract', () {
    expect(
      tools.map((tool) => tool.name),
      isNot(contains('display_online_gallery')),
    );
    expect(
      tool('browse_online_gallery').description,
      contains('never displays'),
    );
  });

  test('browse loads results while the gallery page is hidden', () async {
    final adapter = _ToolGalleryAdapter();
    final toolContainer = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(MemoryLocalStorage()),
        onlineGalleryTagMetadataLoaderProvider.overrideWithValue(
          (_) async => const {},
        ),
        onlineGallerySourceAdaptersProvider.overrideWithValue({
          for (final source in GallerySourceId.values)
            source: source == GallerySourceId.danbooru
                ? adapter
                : _EmptyGalleryAdapter(source),
        }),
      ],
    );
    addTearDown(toolContainer.dispose);
    final notifier = toolContainer.read(onlineGalleryNotifierProvider.notifier);
    notifier.setBackgroundNetworkPaused(true);
    final browse = OnlineGalleryToolbox(
      toolContainer.read(_refProvider),
    ).tools().singleWhere((tool) => tool.name == 'browse_online_gallery');

    final result = await browse.execute('hidden-gallery', {
      'source': 'danbooru',
      'mode': 'search',
      'query': 'blue_archive',
      'limit': 5,
    });

    expect(result.isError, isFalse);
    expect((result.details['items'] as List), hasLength(1));
    expect(adapter.queries, ['blue_archive']);
  });

  test(
    'screenshot AI TAG parameters complete with one configured load',
    () async {
      final aiTag = _ScriptedGalleryAdapter(
        GallerySourceId.aiTag,
        (request, _) async => _page(request, [
          _item(GallerySourceId.aiTag, 101, const ['ibuki', 'blue', 'archive']),
        ]),
      );
      final danbooru = _ScriptedGalleryAdapter(
        GallerySourceId.danbooru,
        (request, _) async => _page(request, const []),
      );
      final harness = _createHarness({
        GallerySourceId.aiTag: aiTag,
        GallerySourceId.danbooru: danbooru,
      });
      addTearDown(harness.container.dispose);

      final result = await harness.browse.execute('screenshot', {
        'source': 'ai_tag',
        'mode': 'search',
        'query': 'ibuki blue archive',
        'ratings': ['s'],
        'limit': 6,
      });

      expect(result.isError, isFalse);
      expect(result.details['source'], 'ai_tag');
      expect(result.details['requested_limit'], 6);
      expect(result.details['items'], hasLength(1));
      expect(aiTag.requests, hasLength(1));
      expect(aiTag.requests.single.query, 'archive blue ibuki');
      expect(
        harness.container.read(onlineGalleryNotifierProvider).searchQuery,
        'ibuki blue archive',
      );
      expect(danbooru.requests, isEmpty);
    },
  );

  test('placeholder covers expose no media id in browse results', () async {
    final cases = {
      GallerySourceId.aiTag: (_pendingAiTagItem(101), 'ibuki', '_pending'),
      GallerySourceId.quickTagCloud: (
        _textOnlyQuickTagCloudItem(7),
        'concept',
        'no-image',
      ),
    };

    for (final MapEntry(key: source, value: (listed, query, placeholder))
        in cases.entries) {
      final harness = _createHarness({
        source: _ScriptedGalleryAdapter(
          source,
          (request, _) async => _page(request, [listed]),
        ),
      });
      addTearDown(harness.container.dispose);

      final result = await harness.browse.execute('placeholder-$source', {
        'source': source.key,
        'mode': 'search',
        'query': query,
      });

      expect(result.isError, isFalse, reason: '$source');
      final item = (result.details['items'] as List).single as Map;
      expect(item['work_id'], listed.sourceWorkId, reason: '$source');
      expect(item['media_id'], isNull, reason: '$source');
      final reference = item['resource_ref'] as Map;
      expect(reference['resourceId'], listed.sourceWorkId, reason: '$source');
      expect(reference.containsKey('mediaId'), isFalse, reason: '$source');
      expect(
        jsonEncode(result.details),
        isNot(contains(placeholder)),
        reason: '$source',
      );
    }
  });

  test('resolved covers keep their media id in browse results', () async {
    const source = GallerySourceId.gelbooru;
    final adapter = _ScriptedGalleryAdapter(
      source,
      (request, _) async => _page(request, [_item(source, 404, ['ibuki'])]),
    );
    final harness = _createHarness({source: adapter});
    addTearDown(harness.container.dispose);

    final result = await harness.browse.execute('resolved-cover', {
      'source': 'gelbooru',
      'mode': 'search',
      'query': 'ibuki',
    });

    final item = (result.details['items'] as List).single as Map;
    expect(item['media_id'], '404');
    expect((item['resource_ref'] as Map)['mediaId'], '404');
    final detail = await harness.detail.execute('visible', {
      'source': source.key,
      'work_id': item['work_id'],
    });
    expect(detail.details['item']['media_id'], '404');
    expect(adapter.requests.map((request) => request.query), ['ibuki']);
  });

  test('omitted source uses danbooru adapter', () async {
    final danbooru = _ScriptedGalleryAdapter(
      GallerySourceId.danbooru,
      (request, _) async => _page(request, const []),
    );
    final aiTag = _ScriptedGalleryAdapter(
      GallerySourceId.aiTag,
      (request, _) async => _page(request, const []),
    );
    final harness = _createHarness({
      GallerySourceId.danbooru: danbooru,
      GallerySourceId.aiTag: aiTag,
    });
    addTearDown(harness.container.dispose);

    final result = await harness.browse.execute('default-source', {
      'mode': 'search',
      'query': 'ibuki',
    });

    expect(result.isError, isFalse);
    expect(result.details['source'], 'danbooru');
    expect(danbooru.requests, hasLength(1));
    expect(aiTag.requests, isEmpty);
  });

  test(
    'explicit source selects its adapter and empty results complete',
    () async {
      final gelbooru = _ScriptedGalleryAdapter(
        GallerySourceId.gelbooru,
        (request, _) async => _page(request, const []),
      );
      final danbooru = _ScriptedGalleryAdapter(
        GallerySourceId.danbooru,
        (request, _) async => _page(request, const []),
      );
      final harness = _createHarness({
        GallerySourceId.gelbooru: gelbooru,
        GallerySourceId.danbooru: danbooru,
      });
      addTearDown(harness.container.dispose);

      final result = await harness.browse.execute('explicit-source', {
        'source': 'gelbooru',
        'mode': 'search',
        'query': 'nothing',
      });

      expect(result.isError, isFalse);
      expect(result.details['source'], 'gelbooru');
      expect(result.details['items'], isEmpty);
      expect(gelbooru.requests, hasLength(1));
      expect(danbooru.requests, isEmpty);
    },
  );

  test('network and parse errors complete with diagnostic result', () async {
    for (final code in [
      GallerySourceErrorCode.network,
      GallerySourceErrorCode.malformedResponse,
    ]) {
      final adapter = _ScriptedGalleryAdapter(
        GallerySourceId.aiTag,
        (_, __) => throw GallerySourceException(
          code,
          source: GallerySourceId.aiTag,
          message: 'diagnostic ${code.name}',
        ),
      );
      final harness = _createHarness({GallerySourceId.aiTag: adapter});
      addTearDown(harness.container.dispose);

      final result = await harness.browse.execute('error-${code.name}', {
        'source': 'ai_tag',
        'mode': 'search',
        'query': 'ibuki',
      });

      expect(result.isError, isTrue);
      expect(result.details['code'], code.name);
    }
  });

  test('stop cancels network, exits loading, and permits a new call', () async {
    final adapter = _CancellableGalleryAdapter();
    final harness = _createHarness({GallerySourceId.aiTag: adapter});
    addTearDown(harness.container.dispose);
    final firstAbort = AbortController();

    final first = harness.browse.execute('cancel-first', {
      'source': 'ai_tag',
      'mode': 'search',
      'query': 'ibuki blue archive',
    }, firstAbort.signal);
    await adapter.firstStarted.future;
    firstAbort.abort('user stopped');

    await expectLater(first, throwsA(anything));
    expect(adapter.cancelledRequests, 1);
    expect(
      harness.container.read(onlineGalleryNotifierProvider).isLoading,
      isFalse,
    );

    final second = await harness.browse.execute('after-stop', {
      'source': 'ai_tag',
      'mode': 'search',
      'query': 'second',
    });
    expect(second.isError, isFalse);
    expect((second.details['items'] as List).single['work_id'], '202');

    adapter.completeLateFirst();
    await Future<void>.delayed(Duration.zero);
    final state = harness.container.read(onlineGalleryNotifierProvider);
    expect(state.posts.single.id, 202);
  });

  test(
    'duplicate append page terminates and other source remains usable',
    () async {
      final item = _item(GallerySourceId.gelbooru, 303, const ['ibuki']);
      final adapter = _ScriptedGalleryAdapter(
        GallerySourceId.gelbooru,
        (request, _) async => GalleryPage(
          items: [item],
          cursor: request.cursor,
          nextCursor: '${int.parse(request.cursor) + 1}',
          hasMore: true,
          total: 10,
          rawItemCount: 1,
        ),
      );
      final harness = _createHarness({GallerySourceId.gelbooru: adapter});
      addTearDown(harness.container.dispose);

      final first = await harness.browse.execute('duplicate-first', {
        'source': 'gelbooru',
        'mode': 'search',
        'query': 'ibuki',
      });
      final second = await harness.browse.execute('duplicate-next', {
        'source': 'gelbooru',
        'mode': 'search',
        'query': 'ibuki',
        'load_more': true,
      });

      expect(first.isError, isFalse);
      expect(second.isError, isFalse);
      expect(second.details['has_more'], isFalse);
      expect(adapter.requests, hasLength(2));
    },
  );

  group('omitted filters use defaults instead of the visible gallery', () {
    late _ScriptedGalleryAdapter danbooru;
    late _ScriptedGalleryAdapter aiTag;
    late List<QuickTagCloudGalleryQuery> quickTagCloudQueries;
    late ProviderContainer gallery;
    late AgentTool browse;
    late OnlineGalleryNotifier notifier;

    setUp(() {
      danbooru = _emptyScriptedAdapter(GallerySourceId.danbooru);
      aiTag = _emptyScriptedAdapter(GallerySourceId.aiTag);
      quickTagCloudQueries = [];
      final harness = _createHarness({
        GallerySourceId.danbooru: danbooru,
        GallerySourceId.aiTag: aiTag,
        GallerySourceId.quickTagCloud: _ScriptedGalleryAdapter(
          GallerySourceId.quickTagCloud,
          (request, _) async {
            quickTagCloudQueries.add(gallery.read(quickTagCloudFilterProvider));
            return _page(request, const []);
          },
        ),
      });
      gallery = harness.container;
      browse = harness.browse;
      notifier = gallery.read(onlineGalleryNotifierProvider.notifier);
    });

    tearDown(() => gallery.dispose());

    test('search prompt', () async {
      await notifier.setSource(GallerySourceId.aiTag);
      await notifier.searchWithPrompt('', prompt: '2girls');
      expect(aiTag.requests.last.prompt, '2girls');

      final result = await browse.execute('stale-prompt', {
        'source': 'ai_tag',
        'mode': 'search',
        'query': 'insect',
      });

      expect(result.isError, isFalse);
      expect(aiTag.requests.last.query, 'insect');
      expect(aiTag.requests.last.prompt, isEmpty);
    });

    test('AI TAG time range', () async {
      await notifier.setSource(GallerySourceId.aiTag);
      await notifier.setAiTagTimeRange('week');
      expect(aiTag.requests.last.timeRange, 'week');

      final result = await browse.execute('stale-time-range', {
        'source': 'ai_tag',
        'mode': 'search',
        'query': 'insect',
      });

      expect(result.isError, isFalse);
      expect(aiTag.requests.last.timeRange, 'all');
    });

    test('date range on an unchanged source', () async {
      await notifier.setDateRange(DateTime(2026, 1, 1), DateTime(2026, 2, 1));
      expect(danbooru.requests.last.dateStart, DateTime(2026, 1, 1));

      final result = await browse.execute('stale-date-range', {
        'source': 'danbooru',
        'mode': 'search',
        'query': 'ibuki',
      });

      expect(result.isError, isFalse);
      expect(danbooru.requests.last.dateStart, isNull);
      expect(danbooru.requests.last.dateEnd, isNull);
    });

    test('artist hunt', () async {
      await notifier.setSource(GallerySourceId.aiTag);
      await notifier.setArtistHuntEnabled(true);
      expect(aiTag.requests.last.prompt, 'artist:');

      final result = await browse.execute('stale-artist-hunt', {
        'source': 'ai_tag',
        'mode': 'search',
        'query': 'insect',
      });

      expect(result.isError, isFalse);
      expect(aiTag.requests.last.prompt, isEmpty);
      expect(
        gallery.read(onlineGalleryNotifierProvider).artistHuntEnabled,
        isFalse,
      );
    });

    test('ranking scale', () async {
      await notifier.setPopularScale(PopularScale.month);

      final result = await browse.execute('stale-ranking-scale', {
        'source': 'danbooru',
        'mode': 'ranking',
      });

      expect(result.isError, isFalse);
      expect(danbooru.rankingRequests.single.kind, GalleryRankingKind.day);
    });

    test('ranking date', () async {
      await notifier.setPopularDate(DateTime(2026, 1, 1));

      final result = await browse.execute('stale-ranking-date', {
        'source': 'danbooru',
        'mode': 'ranking',
      });

      expect(result.isError, isFalse);
      expect(danbooru.rankingRequests.single.date, isNull);
    });

    test('AI TAG ranking period', () async {
      await notifier.setAiTagPopularPeriod('2026-10');

      final result = await browse.execute('stale-ranking-period', {
        'source': 'ai_tag',
        'mode': 'ranking',
      });

      expect(result.isError, isFalse);
      expect(aiTag.rankingRequests.single.period, 'current');
    });

    test('QuickTagCloud keeps the filters selected in the gallery', () async {
      final filters = gallery.read(quickTagCloudFilterProvider.notifier);
      await filters.initializeContentAccess();
      filters
        ..selectCodex('other')
        ..selectCategory(const ['clothing', 'kimono']);

      final result = await browse.execute('selected-codex-filters', {
        'source': 'quick_tag_cloud',
        'mode': 'search',
        'query': 'concept',
      });

      expect(result.isError, isFalse);
      expect(quickTagCloudQueries.last.codexId, 'other');
      expect(quickTagCloudQueries.last.categoryPath, ['clothing', 'kimono']);
    });

    test('explicit search filters still reach the adapter', () async {
      final result = await browse.execute('explicit-search', {
        'source': 'ai_tag',
        'mode': 'search',
        'query': 'insect',
        'prompt': '2girls',
        'ai_tag_time_range': 'week',
      });

      expect(result.isError, isFalse);
      expect(aiTag.requests.single.prompt, '2girls');
      expect(aiTag.requests.single.timeRange, 'week');
    });

    test('explicit ranking filters still reach the adapter', () async {
      final scaled = await browse.execute('explicit-ranking-scale', {
        'source': 'danbooru',
        'mode': 'ranking',
        'ranking_scale': 'week',
        'ranking_date': '2026-01-01',
      });
      final period = await browse.execute('explicit-ranking-period', {
        'source': 'ai_tag',
        'mode': 'ranking',
        'ai_tag_period': '2026-10',
      });

      expect(scaled.isError, isFalse);
      expect(period.isError, isFalse);
      expect(danbooru.rankingRequests.single.kind, GalleryRankingKind.week);
      expect(danbooru.rankingRequests.single.date, DateTime(2026, 1, 1));
      expect(aiTag.rankingRequests.single.period, '2026-10');
    });
  });

  group('load_more continues only the browse its parameters describe', () {
    const request = {'source': 'ai_tag', 'mode': 'search', 'query': 'ibuki'};
    late _ScriptedGalleryAdapter aiTag;
    late ProviderContainer gallery;
    late AgentTool browse;
    late OnlineGalleryNotifier notifier;

    setUp(() {
      aiTag = _ScriptedGalleryAdapter(GallerySourceId.aiTag, (request, _) {
        final page = int.parse(request.cursor);
        final hasMore = page < 3;
        return GalleryPage(
          items: [
            _item(GallerySourceId.aiTag, page, const ['ibuki']),
          ],
          cursor: request.cursor,
          nextCursor: hasMore ? '${page + 1}' : null,
          hasMore: hasMore,
          total: 3,
          rawItemCount: 1,
        );
      });
      final harness = _createHarness({
        GallerySourceId.aiTag: aiTag,
        GallerySourceId.danbooru: _emptyScriptedAdapter(
          GallerySourceId.danbooru,
        ),
      });
      gallery = harness.container;
      browse = harness.browse;
      notifier = gallery.read(onlineGalleryNotifierProvider.notifier);
    });

    tearDown(() => gallery.dispose());

    Future<void> expectScopeChanged(Map<String, dynamic> params) async {
      final requestsBefore = aiTag.requests.length;

      final result = await browse.execute('load-more', {
        ...params,
        'load_more': true,
      });

      expect(result.isError, isTrue);
      expect(result.details, containsPair('code', 'pagination_scope_changed'));
      expect(aiTag.requests, hasLength(requestsBefore));
    }

    test('repeating every filter unchanged loads the next page', () async {
      const filtered = {
        ...request,
        'prompt': '2girls',
        'ratings': ['g', 's'],
        'ai_tag_time_range': 'week',
      };
      final first = await browse.execute('first', filtered);
      final requestsBefore = aiTag.requests.length;

      final second = await browse.execute('load-more', {
        ...filtered,
        'load_more': true,
      });

      expect(first.isError, isFalse);
      expect(second.isError, isFalse);
      expect(aiTag.requests.length, greaterThan(requestsBefore));
      expect(aiTag.requests.last.prompt, '2girls');
      expect(aiTag.requests.last.timeRange, 'week');
    });

    final galleryChanges =
        <String, Future<void> Function(OnlineGalleryNotifier notifier)>{
          'search query': (notifier) => notifier.search('other'),
          'prompt': (notifier) =>
              notifier.searchWithPrompt('ibuki', prompt: '2girls'),
          'ratings': (notifier) => notifier.setRatings({'g'}),
          'fuzzy search': (notifier) => notifier.setFuzzySearchEnabled(true),
          'date range': (notifier) =>
              notifier.setDateRange(DateTime(2026, 1, 1), null),
          'AI TAG time range': (notifier) => notifier.setAiTagTimeRange('week'),
          'artist hunt': (notifier) => notifier.setArtistHuntEnabled(true),
          'source': (notifier) => notifier.setSource(GallerySourceId.danbooru),
        };
    for (final MapEntry(key: name, value: change) in galleryChanges.entries) {
      test('rejects after the gallery changed its $name', () async {
        await browse.execute('first', request);
        await change(notifier);

        await expectScopeChanged(request);
      });
    }

    test('rejects parameters that leave out the browsed query', () async {
      await browse.execute('first', request);

      await expectScopeChanged({'source': 'ai_tag', 'mode': 'search'});
    });

    test('rejects a random continuation of a plain browse', () async {
      await browse.execute('first', request);

      await expectScopeChanged({...request, 'random': true});
    });

    test('ranking continues', () async {
      const ranking = {'source': 'danbooru', 'mode': 'ranking'};
      final first = await browse.execute('first', ranking);

      final second = await browse.execute('load-more', {
        ...ranking,
        'load_more': true,
      });

      expect(first.isError, isFalse);
      expect(second.isError, isFalse);
    });
  });
}

_ScriptedGalleryAdapter _emptyScriptedAdapter(GallerySourceId source) =>
    _ScriptedGalleryAdapter(
      source,
      (request, _) async => _page(request, const []),
    );

({ProviderContainer container, AgentTool browse, AgentTool detail}) _createHarness(
  Map<GallerySourceId, GallerySourceAdapter> overrides, {
  List<String> blacklist = const [],
}) {
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(
        MemoryLocalStorage()
          ..values[StorageKeys.onlineGalleryBlacklistTags] = blacklist,
      ),
      onlineGalleryTagMetadataLoaderProvider.overrideWithValue(
        (_) async => const {},
      ),
      onlineGallerySourceAdaptersProvider.overrideWithValue({
        for (final source in GallerySourceId.values)
          source: overrides[source] ?? _EmptyGalleryAdapter(source),
      }),
    ],
  );
  final tools = OnlineGalleryToolbox(container.read(_refProvider)).tools();
  return (
    container: container,
    browse: tools.singleWhere((tool) => tool.name == 'browse_online_gallery'),
    detail: tools.singleWhere((tool) => tool.name == 'get_online_gallery_detail'),
  );
}

GalleryPage _page(GallerySearchRequest request, List<GalleryItem> items) =>
    GalleryPage(
      items: items,
      cursor: request.cursor,
      nextCursor: null,
      hasMore: false,
      total: items.length,
      rawItemCount: items.length,
    );

GalleryItem _item(GallerySourceId source, int id, List<String> tags) =>
    GalleryItem(
      id: id,
      sourceId: source,
      createdAt: '2026-08-30',
      uploaderId: 1,
      width: 768,
      height: 1024,
      rating: 'g',
      tags: tags,
      tagsComplete: true,
      cover: GalleryMedia(
        id: '$id',
        previewUrl: 'https://example.test/$id-preview.webp',
        displayUrl: 'https://example.test/$id.webp',
        downloadUrl: 'https://example.test/$id.webp',
        width: 768,
        height: 1024,
        extension: 'webp',
      ),
    );

GalleryItem _pendingAiTagItem(int id) => GalleryItem(
  id: id,
  sourceId: GallerySourceId.aiTag,
  createdAt: '2026-08-30',
  uploaderId: 1,
  tags: const ['ibuki'],
  tagsComplete: true,
  cover: GalleryMedia(id: '${id}_pending', mediaType: 'image'),
);

GalleryItem _textOnlyQuickTagCloudItem(int id) => GalleryItem(
  id: id,
  workId: 'codex-$id',
  sourceId: GallerySourceId.quickTagCloud,
  createdAt: 'v1',
  uploaderId: 0,
  tags: const ['abstract concept'],
  tagsComplete: true,
  cover: GalleryMedia.noImage,
);

class _ToolGalleryAdapter extends GallerySourceAdapter {
  final List<String> queries = [];

  @override
  GallerySourceId get sourceId => GallerySourceId.danbooru;

  @override
  Future<GalleryPage> search(
    GallerySearchRequest request, {
    CancelToken? cancelToken,
  }) async {
    queries.add(request.query);
    final item = GalleryItem(
      id: 1,
      sourceId: sourceId,
      createdAt: '2026-08-30',
      uploaderId: 1,
      width: 768,
      height: 1024,
      rating: 'g',
      tags: const ['blue_archive'],
      cover: const GalleryMedia(
        id: '1',
        previewUrl: 'https://example.test/preview.webp',
        displayUrl: 'https://example.test/image.webp',
        downloadUrl: 'https://example.test/image.webp',
        width: 768,
        height: 1024,
        extension: 'webp',
      ),
    );
    return GalleryPage(
      items: [item],
      cursor: request.cursor,
      nextCursor: null,
      hasMore: false,
      rawItemCount: 1,
    );
  }
}

class _ScriptedGalleryAdapter extends GallerySourceAdapter {
  _ScriptedGalleryAdapter(this.sourceId, this.handler);

  @override
  final GallerySourceId sourceId;
  final FutureOr<GalleryPage> Function(
    GallerySearchRequest request,
    CancelToken? cancelToken,
  )
  handler;
  final List<GallerySearchRequest> requests = [];
  final List<GalleryRankingRequest> rankingRequests = [];

  @override
  Future<GalleryPage> search(
    GallerySearchRequest request, {
    CancelToken? cancelToken,
  }) async {
    requests.add(request);
    return handler(request, cancelToken);
  }

  @override
  Future<GalleryPage> ranking(
    GalleryRankingRequest request, {
    CancelToken? cancelToken,
  }) async {
    rankingRequests.add(request);
    return GalleryPage(
      items: const [],
      cursor: request.cursor,
      nextCursor: null,
      hasMore: false,
      rawItemCount: 0,
    );
  }
}

class _DetailAdapter extends _EmptyGalleryAdapter {
  _DetailAdapter(super.sourceId, this.load);

  final Future<GalleryDetail> Function(GalleryItem, CancelToken?) load;

  @override
  Future<GalleryDetail> detail(GalleryItem item, {CancelToken? cancelToken}) =>
      load(item, cancelToken);
}

class _CancellableGalleryAdapter extends GallerySourceAdapter {
  final firstStarted = Completer<void>();
  final Completer<GalleryPage> _lateFirst = Completer<GalleryPage>();
  int calls = 0;
  int cancelledRequests = 0;

  @override
  GallerySourceId get sourceId => GallerySourceId.aiTag;

  @override
  Future<GalleryPage> search(
    GallerySearchRequest request, {
    CancelToken? cancelToken,
  }) async {
    calls++;
    if (calls > 1) {
      return _page(request, [
        _item(sourceId, 202, const ['second']),
      ]);
    }
    firstStarted.complete();
    return Future.any([
      _lateFirst.future,
      cancelToken!.whenCancel.then<GalleryPage>((error) {
        cancelledRequests++;
        throw error;
      }),
    ]);
  }

  void completeLateFirst() {
    _lateFirst.complete(
      _page(const GallerySearchRequest(cursor: '1', pageSize: 60), [
        _item(sourceId, 201, const ['ibuki', 'blue', 'archive']),
      ]),
    );
  }
}

class _EmptyGalleryAdapter extends GallerySourceAdapter {
  _EmptyGalleryAdapter(this.sourceId);

  @override
  final GallerySourceId sourceId;

  @override
  Future<GalleryPage> search(
    GallerySearchRequest request, {
    CancelToken? cancelToken,
  }) async => GalleryPage(
    items: const [],
    cursor: request.cursor,
    nextCursor: null,
    hasMore: false,
    rawItemCount: 0,
  );
}
