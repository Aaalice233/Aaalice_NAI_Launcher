import 'artist_chain.dart';
import 'gallery_item.dart';
import 'gallery_source.dart';

/// Versioned, source-neutral offline snapshot for one online gallery favorite.
class OnlineGalleryFavoriteRecord {
  const OnlineGalleryFavoriteRecord({
    required this.schemaVersion,
    required this.stableKey,
    required this.sourceId,
    required this.sourceWorkId,
    required this.savedAt,
    required this.detail,
  });

  static const int currentSchemaVersion = 1;

  final int schemaVersion;
  final String stableKey;
  final GallerySourceId sourceId;
  final String sourceWorkId;
  final DateTime savedAt;
  final GalleryDetail detail;

  GalleryItem get item => detail.item;

  factory OnlineGalleryFavoriteRecord.fromDetail(
    GalleryDetail detail, {
    DateTime? savedAt,
  }) {
    final item = detail.item;
    if (item.sourceWorkId.isEmpty) {
      throw const FormatException('A favorite must have a source work ID');
    }
    return OnlineGalleryFavoriteRecord(
      schemaVersion: currentSchemaVersion,
      stableKey: item.stableKey,
      sourceId: item.sourceId,
      sourceWorkId: item.sourceWorkId,
      savedAt: (savedAt ?? DateTime.now()).toUtc(),
      detail: detail,
    );
  }

  Map<String, dynamic> toMap() => {
    'version': schemaVersion,
    'stableKey': stableKey,
    'sourceId': sourceId.key,
    'sourceWorkId': sourceWorkId,
    'savedAt': savedAt.toUtc().toIso8601String(),
    'detail': _detailToMap(detail),
  };

  factory OnlineGalleryFavoriteRecord.fromMap(Map<dynamic, dynamic> map) {
    final version = _requiredInt(map, 'version');
    if (version != currentSchemaVersion) {
      throw FormatException('Unsupported favorite record version: $version');
    }
    final sourceKey = _requiredString(map, 'sourceId');
    final sourceId = GallerySourceId.values.cast<GallerySourceId?>().firstWhere(
      (source) => source?.key == sourceKey,
      orElse: () => null,
    );
    if (sourceId == null) {
      throw FormatException('Unknown gallery source: $sourceKey');
    }
    final sourceWorkId = _requiredString(map, 'sourceWorkId');
    final stableKey = _requiredString(map, 'stableKey');
    if (stableKey != sourceId.stableItemKey(sourceWorkId)) {
      throw const FormatException('Favorite stable key does not match source');
    }
    final savedAt = DateTime.tryParse(_requiredString(map, 'savedAt'))?.toUtc();
    if (savedAt == null) {
      throw const FormatException('Invalid favorite savedAt');
    }
    final detailMap = _requiredMap(map, 'detail');
    final detail = _detailFromMap(detailMap);
    if (detail.item.stableKey != stableKey) {
      throw const FormatException('Favorite snapshot identity does not match');
    }
    return OnlineGalleryFavoriteRecord(
      schemaVersion: version,
      stableKey: stableKey,
      sourceId: sourceId,
      sourceWorkId: sourceWorkId,
      savedAt: savedAt,
      detail: detail,
    );
  }
}

Map<String, dynamic> _detailToMap(GalleryDetail detail) => {
  'item': _itemToMap(detail.item),
  'media': detail.media.map(_mediaToMap).toList(growable: false),
  'prompt': detail.prompt,
  'negativePrompt': detail.negativePrompt,
  'description': detail.description,
  'categoryPath': detail.categoryPath,
  'note': detail.note,
  'rawTags': detail.rawTags,
  'characterPrompts': [
    for (final prompt in detail.characterPrompts)
      {
        'label': prompt.label,
        'prompt': prompt.prompt,
        'negativePrompt': prompt.negativePrompt,
      },
  ],
  'contributors': [
    for (final contributor in detail.contributors)
      {
        'name': contributor.name,
        'role': contributor.role,
        'url': contributor.url,
      },
  ],
  'sourceUrl': detail.sourceUrl,
  'rawSourceMetadata': _persistableMap(detail.rawSourceMetadata),
};

GalleryDetail _detailFromMap(Map<dynamic, dynamic> map) {
  final media = _mapList(map['media'], _mediaFromMap);
  return GalleryDetail(
    item: _itemFromMap(_requiredMap(map, 'item')),
    media: List.unmodifiable(media),
    prompt: _nullableString(map['prompt']),
    negativePrompt: _nullableString(map['negativePrompt']),
    description: _nullableString(map['description']),
    categoryPath: _stringList(map['categoryPath']),
    note: _nullableString(map['note']),
    rawTags: _stringList(map['rawTags']),
    characterPrompts: _mapList(
      map['characterPrompts'],
      (value) => GalleryCharacterPrompt(
        label: _requiredString(value, 'label'),
        prompt: _requiredString(value, 'prompt'),
        negativePrompt: _string(value['negativePrompt']),
      ),
    ),
    contributors: _mapList(
      map['contributors'],
      (value) => GalleryContributor(
        name: _requiredString(value, 'name'),
        role: _string(value['role']),
        url: _nullableString(value['url']),
      ),
    ),
    sourceUrl: _nullableString(map['sourceUrl']),
    rawSourceMetadata: _dynamicMap(map['rawSourceMetadata']),
  );
}

Map<String, dynamic> _itemToMap(GalleryItem item) => {
  'id': item.id,
  'workId': item.workId,
  'sourceId': item.sourceId.key,
  'site': item.site,
  'title': item.title,
  'author': item.author,
  'description': item.description,
  'aiType': item.aiType,
  'createdAt': item.createdAt,
  'uploaderId': item.uploaderId,
  'score': item.score,
  'source': item.source,
  'md5': item.md5,
  'rating': item.rating,
  'imageWidth': item.imageWidth,
  'imageHeight': item.imageHeight,
  'tagString': item.tagString,
  'tags': item.tags,
  'tagStringGeneral': item.tagStringGeneral,
  'tagStringCharacter': item.tagStringCharacter,
  'tagStringCopyright': item.tagStringCopyright,
  'tagStringArtist': item.tagStringArtist,
  'tagStringMeta': item.tagStringMeta,
  'fileExt': item.fileExt,
  'fileSize': item.fileSize,
  'fileUrl': item.fileUrl,
  'largeFileUrl': item.largeFileUrl,
  'previewFileUrl': item.previewFileUrl,
  'sampleUrl': item.sampleUrl,
  'sampleWidth': item.sampleWidth,
  'sampleHeight': item.sampleHeight,
  'cover': _mediaToMap(item.cover),
  'mediaCount': item.mediaCount,
  'viewCount': item.viewCount,
  'favoriteCount': item.favoriteCount,
  'rank': item.rank,
  'rankingName': item.rankingName,
  'focusedMediaId': item.focusedMediaId,
  'focusedMediaIndex': item.focusedMediaIndex,
  'artistChain': item.artistChain == null
      ? null
      : {
          'formattedText': item.artistChain!.formattedText,
          'rawFragments': item.artistChain!.rawFragments,
          'artistNames': item.artistChain!.artistNames,
        },
  'rawSourceMetadata': _persistableMap(item.rawSourceMetadata),
};

GalleryItem _itemFromMap(Map<dynamic, dynamic> map) {
  final sourceKey = _requiredString(map, 'sourceId');
  final sourceId = GallerySourceId.values.firstWhere(
    (source) => source.key == sourceKey,
    orElse: () => throw FormatException('Unknown gallery source: $sourceKey'),
  );
  final artistMap = map['artistChain'];
  return GalleryItem(
    id: _requiredInt(map, 'id'),
    workId: _nullableString(map['workId']),
    sourceId: sourceId,
    site: _string(map['site'], sourceId.key),
    title: _nullableString(map['title']),
    author: _nullableString(map['author']),
    description: _nullableString(map['description']),
    aiType: _nullableString(map['aiType']),
    createdAt: _string(map['createdAt']),
    uploaderId: _int(map['uploaderId']),
    score: _nullableInt(map['score']),
    source: _string(map['source']),
    md5: _string(map['md5']),
    rating: _nullableString(map['rating']),
    imageWidth: _int(map['imageWidth']),
    imageHeight: _int(map['imageHeight']),
    tagString: _string(map['tagString']),
    tags: _stringList(map['tags']),
    tagStringGeneral: _string(map['tagStringGeneral']),
    tagStringCharacter: _string(map['tagStringCharacter']),
    tagStringCopyright: _string(map['tagStringCopyright']),
    tagStringArtist: _string(map['tagStringArtist']),
    tagStringMeta: _string(map['tagStringMeta']),
    fileExt: _nullableString(map['fileExt']),
    fileSize: _nullableInt(map['fileSize']),
    fileUrl: _nullableString(map['fileUrl']),
    largeFileUrl: _nullableString(map['largeFileUrl']),
    previewFileUrl: _nullableString(map['previewFileUrl']),
    sampleUrl: _nullableString(map['sampleUrl']),
    sampleWidth: _nullableInt(map['sampleWidth']),
    sampleHeight: _nullableInt(map['sampleHeight']),
    cover: _mediaFromMap(_requiredMap(map, 'cover')),
    mediaCount: _int(map['mediaCount'], 1),
    viewCount: _nullableInt(map['viewCount']),
    favoriteCount: _nullableInt(map['favoriteCount']),
    rank: _nullableInt(map['rank']),
    rankingName: _nullableString(map['rankingName']),
    focusedMediaId: _nullableString(map['focusedMediaId']),
    focusedMediaIndex: _nullableInt(map['focusedMediaIndex']),
    artistChain: artistMap is Map
        ? ArtistChainExtraction(
            formattedText: _string(artistMap['formattedText']),
            rawFragments: _stringList(artistMap['rawFragments']),
            artistNames: _stringList(artistMap['artistNames']),
          )
        : null,
    rawSourceMetadata: _dynamicMap(map['rawSourceMetadata']),
  );
}

Map<String, dynamic> _mediaToMap(GalleryMedia media) => {
  'id': media.id,
  'previewUrl': media.previewUrl,
  'displayUrl': media.displayUrl,
  'downloadUrl': media.downloadUrl,
  'width': media.width,
  'height': media.height,
  'extension': media.extension,
  'mimeType': media.mimeType,
  'rawMetadata': media.rawMetadata,
  'mediaType': media.mediaType,
  'prompt': media.prompt,
  'negativePrompt': media.negativePrompt,
  'metadataFormat': media.metadataFormat,
  'metadataError': media.metadataError,
  'metadata': _persistableMap(media.metadata),
};

GalleryMedia _mediaFromMap(Map<dynamic, dynamic> map) => GalleryMedia(
  id: _requiredString(map, 'id'),
  previewUrl: _string(map['previewUrl']),
  displayUrl: _string(map['displayUrl']),
  downloadUrl: _string(map['downloadUrl']),
  width: _int(map['width']),
  height: _int(map['height']),
  extension: _nullableString(map['extension']),
  mimeType: _nullableString(map['mimeType']),
  rawMetadata: _nullableString(map['rawMetadata']),
  mediaType: _string(map['mediaType'], 'image'),
  prompt: _nullableString(map['prompt']),
  negativePrompt: _nullableString(map['negativePrompt']),
  metadataFormat: _nullableString(map['metadataFormat']),
  metadataError: _nullableString(map['metadataError']),
  metadata: _dynamicMap(map['metadata']),
);

Map<String, dynamic> _persistableMap(Map<String, dynamic> value) => {
  for (final entry in value.entries) entry.key: _persistableValue(entry.value),
};

Object? _persistableValue(Object? value) {
  if (value == null || value is bool || value is num || value is String) {
    return value;
  }
  if (value is DateTime) return value.toUtc().toIso8601String();
  if (value is Map) {
    return {
      for (final entry in value.entries)
        entry.key.toString(): _persistableValue(entry.value),
    };
  }
  if (value is Iterable) {
    return value.map(_persistableValue).toList(growable: false);
  }
  return value.toString();
}

Map<String, dynamic> _dynamicMap(Object? value) => value is Map
    ? {
        for (final entry in value.entries)
          entry.key.toString(): _persistableValue(entry.value),
      }
    : const {};

Map<dynamic, dynamic> _requiredMap(Map<dynamic, dynamic> map, String key) {
  final value = map[key];
  if (value is! Map) throw FormatException('Missing favorite field: $key');
  return value;
}

List<T> _mapList<T>(Object? value, T Function(Map<dynamic, dynamic>) decode) {
  if (value is! List) throw const FormatException('Expected a snapshot list');
  return [
    for (final item in value)
      if (item is Map)
        decode(item)
      else
        throw const FormatException('Invalid snapshot list entry'),
  ];
}

List<String> _stringList(Object? value) {
  if (value is! List) throw const FormatException('Expected a string list');
  return value.map((item) => item.toString()).toList(growable: false);
}

String _requiredString(Map<dynamic, dynamic> map, String key) {
  final value = map[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing favorite field: $key');
  }
  return value;
}

int _requiredInt(Map<dynamic, dynamic> map, String key) {
  final value = _nullableInt(map[key]);
  if (value == null) throw FormatException('Missing favorite field: $key');
  return value;
}

String _string(Object? value, [String fallback = '']) =>
    value?.toString() ?? fallback;
String? _nullableString(Object? value) => value?.toString();
int _int(Object? value, [int fallback = 0]) => _nullableInt(value) ?? fallback;
int? _nullableInt(Object? value) => switch (value) {
  final int number => number,
  final num number => number.toInt(),
  final String text => int.tryParse(text),
  _ => null,
};
