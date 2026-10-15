import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference_codec.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/datasources/remote/online_gallery/gallery_source_adapter.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/data/models/online_gallery/quick_tag_cloud_codex.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_resource_resolver.dart';
import 'package:nai_launcher/presentation/agent_chat/services/online_gallery_resource_identity.dart';
import 'package:nai_launcher/presentation/agent_chat/services/online_gallery_toolbox.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_provider.dart';

import '../../../helpers/empty_gallery_source_adapter.dart';
import '../../../helpers/memory_local_storage.dart';

final _refProvider = Provider<Ref>((ref) => ref);

void main() {
  late _AiTagAdapter adapter;
  late _QuickTagCloudAdapter quickTagCloud;
  late ProviderContainer container;
  late AgentResourceResolver resolver;

  setUp(() {
    adapter = _AiTagAdapter();
    quickTagCloud = _QuickTagCloudAdapter();
    container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(MemoryLocalStorage()),
        onlineGalleryTagMetadataLoaderProvider.overrideWithValue(
          (_) async => const {},
        ),
        onlineGallerySourceAdaptersProvider.overrideWithValue({
          for (final source in GallerySourceId.values)
            source: switch (source) {
              GallerySourceId.aiTag => adapter,
              GallerySourceId.quickTagCloud => quickTagCloud,
              _ => EmptyGallerySourceAdapter(source),
            },
        }),
      ],
    );
    resolver = AgentResourceResolver(container.read(_refProvider));
  });

  tearDown(() => container.dispose());

  Future<void> browseAiTag() async {
    final browse = OnlineGalleryToolbox(
      container.read(_refProvider),
    ).tools().singleWhere((tool) => tool.name == 'browse_online_gallery');
    final result = await browse.execute('browse', {
      'source': 'ai_tag',
      'mode': 'search',
      'query': 'ibuki',
    });
    expect(result.isError, isFalse);
  }

  AgentChatResourceReference reference(String? mediaId) =>
      AgentChatResourceReference(
        kind: AgentChatResourceKind.onlineGalleryMedia,
        source: GallerySourceId.aiTag.key,
        resourceId: '101',
        mediaId: mediaId,
      );

  test('legacy placeholder media id resolves the work', () async {
    expect(await resolver.exists(reference('101_pending')), isTrue);
    expect(adapter.detailRequests, 1);
  });

  test('legacy no-image placeholder media id resolves the work', () async {
    expect(await resolver.exists(reference(GalleryMedia.noImageId)), isTrue);
  });

  test('unknown media of a loaded work is reported missing', () async {
    expect(await resolver.exists(reference('101_p9')), isFalse);
  });

  test(
    'non-cover media of a visible work is not flagged before its detail loads',
    () async {
      await browseAiTag();

      expect(
        await resolver.existsWithoutExternalResolution(reference('101_p1')),
        isTrue,
      );
      expect(adapter.detailRequests, 0);
    },
  );

  test(
    'cached detail decides media existence without another request',
    () async {
      await browseAiTag();
      final notifier = container.read(onlineGalleryNotifierProvider.notifier);
      final item = container.read(onlineGalleryNotifierProvider).posts.single;
      await notifier.loadDetail(item);
      final requests = adapter.detailRequests;

      expect(
        await resolver.existsWithoutExternalResolution(reference('101_p1')),
        isTrue,
      );
      expect(
        await resolver.existsWithoutExternalResolution(reference('101_p9')),
        isFalse,
      );
      expect(adapter.detailRequests, requests);
    },
  );

  group('QuickTagCloud path-like work ids', () {
    AgentChatResourceReference quickTagCloudReference(String? mediaId) =>
        OnlineGalleryResourceIdentity(
          source: GallerySourceId.quickTagCloud,
          workId: _quickTagCloudWorkId,
          mediaId: mediaId,
        ).toReference();

    test('browsed reference validates and resolves the visible work', () async {
      final browse = OnlineGalleryToolbox(
        container.read(_refProvider),
      ).tools().singleWhere((tool) => tool.name == 'browse_online_gallery');
      final result = await browse.execute('browse', {
        'source': 'quick_tag_cloud',
        'mode': 'search',
        'query': 'concept',
      });
      expect(result.isError, isFalse);
      final item = (result.details['items'] as List).single as Map;

      final reference = resolver.decode(item['resource_ref']);

      expect(await resolver.existsWithoutExternalResolution(reference), isTrue);
      expect(await resolver.exists(reference), isTrue);
      expect(quickTagCloud.detailWorkIds, isEmpty);
    });

    test(
      'persisted reference queries the source with the original work id',
      () async {
        final payload = AgentChatResourceReferenceCodec.encodeJson(
          quickTagCloudReference('$_quickTagCloudWorkId:1'),
        );
        final reference = AgentChatResourceReferenceCodec.decodeJson(payload);

        expect(await resolver.exists(reference), isTrue);
        expect(quickTagCloud.detailWorkIds, [_quickTagCloudWorkId]);
        expect(
          await resolver.exists(
            quickTagCloudReference('$_quickTagCloudWorkId:9'),
          ),
          isFalse,
        );
      },
    );

    test('malformed encoded ids resolve nothing', () async {
      final reference = AgentChatResourceReference(
        kind: AgentChatResourceKind.onlineGalleryMedia,
        source: GallerySourceId.quickTagCloud.key,
        resourceId: 'enc.codex+2fentry',
      );

      expect(await resolver.exists(reference), isFalse);
      expect(await resolver.resolve(reference), isNull);
      expect(quickTagCloud.detailWorkIds, isEmpty);
    });
  });
}

final _quickTagCloudWorkId = quickTagCloudEntryWorkId(
  'community:codex',
  'entry/1 中',
);

GalleryMedia _quickTagCloudMedia(int index) => GalleryMedia(
  id: '$_quickTagCloudWorkId:$index',
  previewUrl: 'https://example.test/qtc-$index.webp',
  displayUrl: 'https://example.test/qtc-$index.webp',
  downloadUrl: 'https://example.test/qtc-$index.webp',
  mediaType: 'image',
);

class _QuickTagCloudAdapter extends GallerySourceAdapter {
  final List<String> detailWorkIds = [];

  @override
  GallerySourceId get sourceId => GallerySourceId.quickTagCloud;

  @override
  Future<GalleryPage> search(
    GallerySearchRequest request, {
    CancelToken? cancelToken,
  }) async => GalleryPage(
    items: [
      GalleryItem(
        id: 7,
        workId: _quickTagCloudWorkId,
        sourceId: sourceId,
        createdAt: 'v1',
        uploaderId: 0,
        tags: const ['abstract concept'],
        tagsComplete: true,
        mediaCount: 2,
        cover: _quickTagCloudMedia(0),
      ),
    ],
    cursor: request.cursor,
    nextCursor: null,
    hasMore: false,
    total: 1,
    rawItemCount: 1,
  );

  @override
  Future<GalleryDetail> detail(
    GalleryItem item, {
    CancelToken? cancelToken,
  }) async {
    detailWorkIds.add(item.sourceWorkId);
    return GalleryDetail(
      item: item,
      media: [_quickTagCloudMedia(0), _quickTagCloudMedia(1)],
    );
  }
}

const _media = [
  GalleryMedia(
    id: '101_p0',
    previewUrl: 'https://example.test/101_p0.webp',
    displayUrl: 'https://example.test/101_p0.webp',
    downloadUrl: 'https://example.test/101_p0.webp',
    mediaType: 'image',
  ),
  GalleryMedia(
    id: '101_p1',
    previewUrl: 'https://example.test/101_p1.webp',
    displayUrl: 'https://example.test/101_p1.webp',
    downloadUrl: 'https://example.test/101_p1.webp',
    mediaType: 'image',
  ),
];

GalleryItem _listItem() => const GalleryItem(
  id: 101,
  sourceId: GallerySourceId.aiTag,
  createdAt: '2026-08-30',
  uploaderId: 1,
  tags: ['ibuki'],
  tagsComplete: true,
  mediaCount: 2,
  cover: GalleryMedia(id: '101_pending', mediaType: 'image'),
);

class _AiTagAdapter extends GallerySourceAdapter {
  int detailRequests = 0;

  @override
  GallerySourceId get sourceId => GallerySourceId.aiTag;

  @override
  Future<GalleryPage> search(
    GallerySearchRequest request, {
    CancelToken? cancelToken,
  }) async => GalleryPage(
    items: [_listItem()],
    cursor: request.cursor,
    nextCursor: null,
    hasMore: false,
    total: 1,
    rawItemCount: 1,
  );

  @override
  Future<GalleryDetail> detail(
    GalleryItem item, {
    CancelToken? cancelToken,
  }) async {
    detailRequests++;
    return GalleryDetail(
      item: item.copyWith(cover: _media.first),
      media: _media,
    );
  }
}
