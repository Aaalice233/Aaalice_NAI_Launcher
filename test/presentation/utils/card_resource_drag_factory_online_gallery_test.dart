import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/datasources/remote/online_gallery/gallery_source_adapter.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/data/models/online_gallery/quick_tag_cloud_codex.dart';
import 'package:nai_launcher/presentation/agent_chat/services/online_gallery_resource_identity.dart';
import 'package:nai_launcher/presentation/agent_chat/services/online_gallery_toolbox.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_provider.dart';
import 'package:nai_launcher/presentation/utils/card_resource_drag_factory.dart';

import '../../helpers/empty_gallery_source_adapter.dart';
import '../../helpers/memory_local_storage.dart';

final _refProvider = Provider<Ref>((ref) => ref);

void main() {
  late ProviderContainer container;

  setUp(() async {
    container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(MemoryLocalStorage()),
        onlineGalleryTagMetadataLoaderProvider.overrideWithValue(
          (_) async => const {},
        ),
        onlineGallerySourceAdaptersProvider.overrideWithValue({
          for (final source in GallerySourceId.values)
            source: switch (source) {
              GallerySourceId.aiTag => _AiTagAdapter(),
              GallerySourceId.quickTagCloud => _QuickTagCloudAdapter(),
              _ => EmptyGallerySourceAdapter(source),
            },
        }),
      ],
    );
    final browse = OnlineGalleryToolbox(
      container.read(_refProvider),
    ).tools().singleWhere((tool) => tool.name == 'browse_online_gallery');
    final result = await browse.execute('browse', {
      'source': 'ai_tag',
      'mode': 'search',
      'query': 'ibuki',
    });
    expect(result.isError, isFalse);
  });

  tearDown(() => container.dispose());

  String dragFileName(String? mediaId) =>
      CardResourceDragFactory(container.read(_refProvider))
          .create(
            AgentChatResourceReference(
              kind: AgentChatResourceKind.onlineGalleryMedia,
              source: GallerySourceId.aiTag.key,
              resourceId: '101',
              mediaId: mediaId,
              display: const {'title': 'work'},
            ),
          )
          .fileName;

  test('drag-out keeps the format of the dragged media', () async {
    final notifier = container.read(onlineGalleryNotifierProvider.notifier);
    await notifier.loadDetail(
      container.read(onlineGalleryNotifierProvider).posts.single,
    );

    expect(dragFileName('101_p0'), 'work.webp');
    expect(dragFileName('101_p1'), 'work.jpg');
    expect(dragFileName(null), 'work.webp');
  });

  test('unresolved placeholder cover falls back to png', () {
    expect(dragFileName(null), 'work.png');
  });

  test('QuickTagCloud drag-out finds the work behind its encoded id', () async {
    final browse = OnlineGalleryToolbox(
      container.read(_refProvider),
    ).tools().singleWhere((tool) => tool.name == 'browse_online_gallery');
    final result = await browse.execute('browse', {
      'source': 'quick_tag_cloud',
      'mode': 'search',
      'query': 'concept',
    });
    expect(result.isError, isFalse);
    final reference = OnlineGalleryResourceIdentity(
      source: GallerySourceId.quickTagCloud,
      workId: _quickTagCloudWorkId,
      mediaId: '$_quickTagCloudWorkId:0',
    ).toReference(display: const {'title': 'work'});

    expect(
      CardResourceDragFactory(
        container.read(_refProvider),
      ).create(reference).fileName,
      'work.webp',
    );
  });
}

final _quickTagCloudWorkId = quickTagCloudEntryWorkId('codex', 'entry/1');

GalleryMedia _media(int index, String extension) => GalleryMedia(
  id: '101_p$index',
  previewUrl: 'https://example.test/101_p$index.$extension',
  displayUrl: 'https://example.test/101_p$index.$extension',
  downloadUrl: 'https://example.test/101_p$index.$extension',
  extension: extension,
  mediaType: 'image',
);

class _AiTagAdapter extends GallerySourceAdapter {
  @override
  GallerySourceId get sourceId => GallerySourceId.aiTag;

  @override
  Future<GalleryPage> search(
    GallerySearchRequest request, {
    CancelToken? cancelToken,
  }) async => GalleryPage(
    items: [
      const GalleryItem(
        id: 101,
        sourceId: GallerySourceId.aiTag,
        tags: ['ibuki'],
        tagsComplete: true,
        mediaCount: 2,
        cover: GalleryMedia(id: '101_pending', mediaType: 'image'),
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
    final media = [_media(0, 'webp'), _media(1, 'jpg')];
    return GalleryDetail(
      item: item.copyWith(cover: media.first),
      media: media,
    );
  }
}

class _QuickTagCloudAdapter extends GallerySourceAdapter {
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
        tags: const ['concept'],
        tagsComplete: true,
        cover: GalleryMedia(
          id: '$_quickTagCloudWorkId:0',
          previewUrl: 'https://example.test/qtc.webp',
          displayUrl: 'https://example.test/qtc.webp',
          downloadUrl: 'https://example.test/qtc.webp',
          extension: 'webp',
          mediaType: 'image',
        ),
      ),
    ],
    cursor: request.cursor,
    nextCursor: null,
    hasMore: false,
    total: 1,
    rawItemCount: 1,
  );
}
