import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/online_gallery/artist_chain.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';
import 'package:nai_launcher/data/models/online_gallery/online_gallery_favorite_record.dart';

void main() {
  test('通用快照完整往返 GalleryItem、多媒体与 prompt 语义', () {
    final detail = _detail();
    final record = OnlineGalleryFavoriteRecord.fromDetail(
      detail,
      savedAt: DateTime.utc(2025, 3, 4, 5, 6),
    );

    final restored = OnlineGalleryFavoriteRecord.fromMap(record.toMap());

    expect(restored.schemaVersion, 1);
    expect(restored.stableKey, 'ai_tag:work/42');
    expect(restored.sourceId, GallerySourceId.aiTag);
    expect(restored.savedAt, DateTime.utc(2025, 3, 4, 5, 6));
    expect(restored.item.title, 'Offline title');
    expect(restored.item.tags, ['blue_hair', 'solo']);
    expect(restored.item.artistChain?.artistNames, ['alice', 'bob']);
    expect(restored.item.rawSourceMetadata['nested'], {'value': 3});
    expect(restored.detail.media, hasLength(2));
    expect(restored.detail.media.last.mediaType, 'video');
    expect(restored.detail.media.last.prompt, 'media prompt');
    expect(restored.detail.media.last.negativePrompt, 'media negative');
    expect(restored.detail.media.last.metadata['frames'], 12);
    expect(restored.detail.prompt, 'main prompt');
    expect(restored.detail.negativePrompt, 'main negative');
    expect(restored.detail.characterPrompts.single.prompt, 'character prompt');
    expect(restored.detail.contributors.single.url, 'https://example.com/user');
    expect(restored.detail.rawSourceMetadata['detail'], isTrue);
  });

  test('拒绝版本、stableKey 或快照身份不一致的记录', () {
    final map = OnlineGalleryFavoriteRecord.fromDetail(_detail()).toMap();

    expect(
      () => OnlineGalleryFavoriteRecord.fromMap({...map, 'version': 99}),
      throwsFormatException,
    );
    expect(
      () => OnlineGalleryFavoriteRecord.fromMap({
        ...map,
        'stableKey': 'ai_tag:other',
      }),
      throwsFormatException,
    );
    expect(
      () => OnlineGalleryFavoriteRecord.fromMap({...map, 'sourceId': 'future'}),
      throwsFormatException,
    );
    final damagedDetail = Map<String, dynamic>.from(
      map['detail']! as Map<String, dynamic>,
    )..['media'] = ['invalid'];
    expect(
      () => OnlineGalleryFavoriteRecord.fromMap({
        ...map,
        'detail': damagedDetail,
      }),
      throwsFormatException,
    );
  });
}

GalleryDetail _detail() {
  const cover = GalleryMedia(
    id: 'cover',
    previewUrl: 'https://example.com/preview.webp',
    displayUrl: 'https://example.com/display.webp',
    downloadUrl: 'https://example.com/original.webp',
    width: 1024,
    height: 1536,
    extension: 'webp',
    mimeType: 'image/webp',
    rawMetadata: 'raw cover',
    prompt: 'cover prompt',
    negativePrompt: 'cover negative',
    metadataFormat: 'nai',
    metadata: {'seed': 7},
  );
  final item = GalleryItem(
    id: 42,
    workId: 'work/42',
    sourceId: GallerySourceId.aiTag,
    site: 'ai_tag',
    title: 'Offline title',
    author: 'Author',
    description: 'Description',
    aiType: 'nai',
    createdAt: '2025-03-04',
    uploaderId: 9,
    score: 10,
    source: 'https://example.com/source',
    md5: 'abc',
    rating: 'q',
    imageWidth: 1024,
    imageHeight: 1536,
    tagString: 'blue_hair solo',
    tags: const ['blue_hair', 'solo'],
    tagStringGeneral: 'blue_hair solo',
    tagStringCharacter: 'alice_(series)',
    tagStringCopyright: 'series',
    tagStringArtist: 'artist_name',
    tagStringMeta: 'highres',
    fileExt: 'webp',
    fileSize: 100,
    fileUrl: cover.downloadUrl,
    largeFileUrl: cover.displayUrl,
    previewFileUrl: cover.previewUrl,
    sampleUrl: cover.displayUrl,
    sampleWidth: 512,
    sampleHeight: 768,
    cover: cover,
    mediaCount: 2,
    viewCount: 20,
    favoriteCount: 30,
    rank: 2,
    rankingName: 'daily',
    focusedMediaId: 'video',
    focusedMediaIndex: 1,
    artistChain: const ArtistChainExtraction(
      formattedText: 'artist:alice, artist:bob',
      rawFragments: ['artist:alice', 'artist:bob'],
      artistNames: ['alice', 'bob'],
    ),
    rawSourceMetadata: const {
      'nested': {'value': 3},
    },
  );
  return GalleryDetail(
    item: item,
    media: const [
      cover,
      GalleryMedia(
        id: 'video',
        previewUrl: 'https://example.com/video-preview.webp',
        displayUrl: 'https://example.com/video.mp4',
        downloadUrl: 'https://example.com/video.mp4',
        width: 1920,
        height: 1080,
        extension: 'mp4',
        mimeType: 'video/mp4',
        mediaType: 'video',
        prompt: 'media prompt',
        negativePrompt: 'media negative',
        metadataFormat: 'nai',
        metadataError: 'partial',
        metadata: {'frames': 12},
      ),
    ],
    prompt: 'main prompt',
    negativePrompt: 'main negative',
    description: 'Detail description',
    categoryPath: const ['People', 'Original'],
    note: 'Note',
    rawTags: const ['raw_tag'],
    characterPrompts: const [
      GalleryCharacterPrompt(
        label: 'Character',
        prompt: 'character prompt',
        negativePrompt: 'character negative',
      ),
    ],
    contributors: const [
      GalleryContributor(
        name: 'Contributor',
        role: 'Artist',
        url: 'https://example.com/user',
      ),
    ],
    sourceUrl: 'https://example.com/work/42',
    rawSourceMetadata: const {'detail': true},
  );
}
