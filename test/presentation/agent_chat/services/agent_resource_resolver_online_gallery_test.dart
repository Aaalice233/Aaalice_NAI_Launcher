import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/datasources/remote/online_gallery/gallery_source_adapter.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_resource_resolver.dart';
import 'package:nai_launcher/presentation/agent_chat/services/online_gallery_toolbox.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_provider.dart';

final _refProvider = Provider<Ref>((ref) => ref);

void main() {
  late _AiTagAdapter adapter;
  late ProviderContainer container;
  late AgentResourceResolver resolver;

  setUp(() {
    adapter = _AiTagAdapter();
    container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(_MemoryStorage()),
        onlineGalleryTagMetadataLoaderProvider.overrideWithValue(
          (_) async => const {},
        ),
        onlineGallerySourceAdaptersProvider.overrideWithValue({
          for (final source in GallerySourceId.values)
            source: source == GallerySourceId.aiTag
                ? adapter
                : _EmptyAdapter(source),
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

class _EmptyAdapter extends GallerySourceAdapter {
  _EmptyAdapter(this.sourceId);

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

class _MemoryStorage extends LocalStorageService {
  final Map<String, Object?> _values = {};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      (_values[key] ?? defaultValue) as T?;

  @override
  Future<void> setSetting<T>(String key, T value) async {
    _values[key] = value;
  }

  @override
  Future<void> deleteSetting(String key) async {
    _values.remove(key);
  }
}
