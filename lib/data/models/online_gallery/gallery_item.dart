import '../gallery/nai_image_metadata.dart';
import 'artist_chain.dart';
import 'gallery_media_capability.dart';
import 'gallery_source.dart';

class GalleryMedia {
  const GalleryMedia({
    required this.id,
    this.previewUrl = '',
    this.displayUrl = '',
    this.downloadUrl = '',
    this.width = 0,
    this.height = 0,
    this.extension,
    this.mimeType,
    this.rawMetadata,
    this.mediaType = 'unknown',
    this.prompt,
    this.negativePrompt,
    this.metadataFormat,
    this.metadataError,
    this.promptMetadata,
    this.metadata = const {},
  });

  final String id;
  final String previewUrl;
  final String displayUrl;
  final String downloadUrl;
  final int width;
  final int height;
  final String? extension;
  final String? mimeType;
  final String? rawMetadata;
  final String mediaType;
  final String? prompt;
  final String? negativePrompt;
  final String? metadataFormat;
  final String? metadataError;
  final NaiImageMetadata? promptMetadata;
  final Map<String, dynamic> metadata;

  bool get hasKnownDimensions => width > 0 && height > 0;
  double get aspectRatio => hasKnownDimensions ? width / height : 1;

  GalleryMediaCapability get capability => GalleryMediaCapability.resolve(
    declaredType: mediaType,
    extension: extension,
    mimeType: mimeType,
    previewUrl: previewUrl,
    displayUrl: displayUrl,
    downloadUrl: downloadUrl,
  );

  GalleryMedia copyWith({
    String? id,
    String? previewUrl,
    String? displayUrl,
    String? downloadUrl,
    int? width,
    int? height,
    String? extension,
    String? mimeType,
    String? rawMetadata,
    String? mediaType,
  }) {
    return GalleryMedia(
      id: id ?? this.id,
      previewUrl: previewUrl ?? this.previewUrl,
      displayUrl: displayUrl ?? this.displayUrl,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      width: width ?? this.width,
      height: height ?? this.height,
      extension: extension ?? this.extension,
      mimeType: mimeType ?? this.mimeType,
      rawMetadata: rawMetadata ?? this.rawMetadata,
      mediaType: mediaType ?? this.mediaType,
      prompt: prompt,
      negativePrompt: negativePrompt,
      metadataFormat: metadataFormat,
      metadataError: metadataError,
      promptMetadata: promptMetadata,
      metadata: metadata,
    );
  }
}

/// Source-neutral item used by every online gallery adapter.
///
/// Legacy booru constructor parameters remain available during the migration,
/// while all source identity and selection logic uses [sourceId]/[stableKey].
class GalleryItem {
  const GalleryItem({
    required this.id,
    this.workId,
    GallerySourceId? sourceId,
    this.site = 'danbooru',
    this.title,
    this.author,
    this.description,
    this.aiType,
    this.createdAt = '',
    this.uploaderId = 0,
    this.score,
    this.source = '',
    this.md5 = '',
    this.rating = 'g',
    int imageWidth = 0,
    int imageHeight = 0,
    int? width,
    int? height,
    this.tagString = '',
    List<String>? tags,
    this.searchTerms = const [],
    this.tagsComplete = true,
    this.tagStringGeneral = '',
    this.tagStringCharacter = '',
    this.tagStringCopyright = '',
    this.tagStringArtist = '',
    this.tagStringMeta = '',
    this.fileExt,
    this.fileSize,
    this.fileUrl,
    this.largeFileUrl,
    this.previewFileUrl,
    this.sampleUrl,
    this.sampleWidth,
    this.sampleHeight,
    GalleryMedia? cover,
    this.mediaCount = 1,
    this.viewCount,
    int? favoriteCount,
    int? favCount,
    this.rank,
    this.rankingName,
    this.focusedMediaId,
    this.focusedMediaIndex,
    this.artistChain,
    this.rawSourceMetadata = const {},
  }) : _sourceId = sourceId,
       imageWidth = width ?? imageWidth,
       imageHeight = height ?? imageHeight,
       _tags = tags,
       _cover = cover,
       favoriteCount = favoriteCount ?? favCount;

  /// Legacy numeric identifier used by booru APIs.
  final int id;

  /// Source-native work identifier. Non-numeric sources must set this value.
  final String? workId;
  final GallerySourceId? _sourceId;
  final String site;
  final String? title;
  final String? author;
  final String? description;
  final String? aiType;
  final String createdAt;
  final int uploaderId;
  final int? score;
  final String source;
  final String md5;
  final String? rating;
  final int imageWidth;
  final int imageHeight;
  final String tagString;
  final List<String>? _tags;

  /// Source-defined searchable text that is not necessarily a display tag.
  final List<String> searchTerms;
  final bool tagsComplete;
  final String tagStringGeneral;
  final String tagStringCharacter;
  final String tagStringCopyright;
  final String tagStringArtist;
  final String tagStringMeta;
  final String? fileExt;
  final int? fileSize;
  final String? fileUrl;
  final String? largeFileUrl;
  final String? previewFileUrl;
  final String? sampleUrl;
  final int? sampleWidth;
  final int? sampleHeight;
  final GalleryMedia? _cover;
  final int mediaCount;
  final int? viewCount;
  final int? favoriteCount;
  final int? rank;
  final String? rankingName;

  /// Optional representative media selected inside a multi-media work.
  final String? focusedMediaId;
  final int? focusedMediaIndex;
  final ArtistChainExtraction? artistChain;
  final Map<String, dynamic> rawSourceMetadata;

  GallerySourceId get sourceId => _sourceId ?? GallerySourceId.fromKey(site);
  String get sourceWorkId => workId ?? id.toString();
  String get stableKey => sourceId.stableItemKey(sourceWorkId);
  String get detailStableKey {
    final revision = rawSourceMetadata['detailRevision']?.toString() ?? '';
    return sourceId == GallerySourceId.quickTagCloud && revision.isNotEmpty
        ? '$stableKey@$revision'
        : stableKey;
  }

  int? get favCount => favoriteCount;
  int get width => _cover?.width ?? imageWidth;
  int get height => _cover?.height ?? imageHeight;
  String get postUrl => sourceId.itemPageUrl(sourceWorkId);
  List<String> get tags => List.unmodifiable(
    _tags ??
        tagString
            .split(RegExp(r'\s+'))
            .where((tag) => tag.isNotEmpty)
            .toList(growable: false),
  );

  GalleryMedia get cover {
    final providedCover = _cover;
    if (providedCover != null) return providedCover;
    final preview = previewFileUrl ?? sampleUrl ?? fileUrl ?? '';
    final display =
        sampleUrl ?? largeFileUrl ?? fileUrl ?? previewFileUrl ?? '';
    final download =
        fileUrl ?? largeFileUrl ?? sampleUrl ?? previewFileUrl ?? '';
    return GalleryMedia(
      id: '$id:0',
      previewUrl: preview,
      displayUrl: display,
      downloadUrl: download,
      width: imageWidth,
      height: imageHeight,
      extension: fileExt,
    );
  }

  List<String> get generalTags => _splitTags(tagStringGeneral);
  List<String> get characterTags => _splitTags(tagStringCharacter);
  List<String> get copyrightTags => _splitTags(tagStringCopyright);
  List<String> get artistTags => _splitTags(tagStringArtist);
  List<String> get metaTags => _splitTags(tagStringMeta);
  String get downloadUrl => cover.downloadUrl;

  GalleryMediaCapability get mediaCapability => cover.capability;
  bool get isVideo => mediaCapability.isVideo;
  bool get isAnimated => mediaCapability.isAnimatedImage;

  bool get hasValidPreview => previewUrl.isNotEmpty;
  bool get hasFile => downloadUrl.isNotEmpty;
  bool get hasLarge => (largeFileUrl ?? '').isNotEmpty;
  String? get mediaTypeLabel {
    if (mediaCapability.isVideo) return 'Video';
    if (mediaCapability.isAnimatedImage) return 'GIF';
    return null;
  }

  String get previewUrl => cover.previewUrl;
  String get bestQualityUrl => cover.downloadUrl.isNotEmpty
      ? cover.downloadUrl
      : (cover.displayUrl.isNotEmpty ? cover.displayUrl : cover.previewUrl);

  List<String> _splitTags(String value) {
    return value
        .split(RegExp(r'\s+'))
        .where((tag) => tag.isNotEmpty)
        .toList(growable: false);
  }

  factory GalleryItem.fromDanbooruJson(
    Map<String, dynamic> json, {
    GallerySourceId sourceId = GallerySourceId.danbooru,
  }) {
    final id = _galleryInt(json['id']);
    final width = _galleryInt(json['image_width']);
    final height = _galleryInt(json['image_height']);
    final preview = json['preview_file_url']?.toString() ?? '';
    final sample =
        json['large_file_url']?.toString() ??
        json['sample_url']?.toString() ??
        '';
    final file = json['file_url']?.toString() ?? '';
    final tagString = json['tag_string']?.toString() ?? '';
    return GalleryItem(
      id: id,
      sourceId: sourceId,
      site: sourceId.key,
      createdAt: json['created_at']?.toString() ?? '',
      uploaderId: _galleryInt(json['uploader_id']),
      score: _galleryNullableInt(json['score']),
      source: json['source']?.toString() ?? '',
      md5: json['md5']?.toString() ?? '',
      rating: json['rating']?.toString(),
      imageWidth: width,
      imageHeight: height,
      tagString: tagString,
      tags: tagString
          .split(RegExp(r'\s+'))
          .where((tag) => tag.isNotEmpty)
          .toList(growable: false),
      tagStringGeneral: json['tag_string_general']?.toString() ?? '',
      tagStringCharacter: json['tag_string_character']?.toString() ?? '',
      tagStringCopyright: json['tag_string_copyright']?.toString() ?? '',
      tagStringArtist: json['tag_string_artist']?.toString() ?? '',
      tagStringMeta: json['tag_string_meta']?.toString() ?? '',
      fileExt: json['file_ext']?.toString(),
      fileSize: _galleryNullableInt(json['file_size']),
      fileUrl: file.isEmpty ? null : file,
      largeFileUrl: sample.isEmpty ? null : sample,
      previewFileUrl: preview.isEmpty ? null : preview,
      sampleUrl: json['sample_url']?.toString(),
      sampleWidth: _galleryNullableInt(json['sample_width']),
      sampleHeight: _galleryNullableInt(json['sample_height']),
      favoriteCount: _galleryNullableInt(json['fav_count']),
      cover: GalleryMedia(
        id: '$id:0',
        previewUrl: preview,
        displayUrl: sample.isNotEmpty ? sample : file,
        downloadUrl: file.isNotEmpty ? file : sample,
        width: width,
        height: height,
        extension: json['file_ext']?.toString(),
      ),
      rawSourceMetadata: Map.unmodifiable(json),
    );
  }

  factory GalleryItem.fromJson(Map<String, dynamic> json) {
    return GalleryItem.fromDanbooruJson(json);
  }

  GalleryItem copyWith({
    int? id,
    String? workId,
    GallerySourceId? sourceId,
    String? site,
    String? title,
    String? author,
    String? description,
    String? aiType,
    String? createdAt,
    int? uploaderId,
    int? score,
    String? source,
    String? md5,
    String? rating,
    int? imageWidth,
    int? imageHeight,
    String? tagString,
    List<String>? tags,
    List<String>? searchTerms,
    bool? tagsComplete,
    String? tagStringGeneral,
    String? tagStringCharacter,
    String? tagStringCopyright,
    String? tagStringArtist,
    String? tagStringMeta,
    String? fileExt,
    int? fileSize,
    String? fileUrl,
    String? largeFileUrl,
    String? previewFileUrl,
    String? sampleUrl,
    int? sampleWidth,
    int? sampleHeight,
    GalleryMedia? cover,
    int? mediaCount,
    int? viewCount,
    int? favoriteCount,
    int? favCount,
    int? rank,
    String? rankingName,
    String? focusedMediaId,
    int? focusedMediaIndex,
    ArtistChainExtraction? artistChain,
    Map<String, dynamic>? rawSourceMetadata,
  }) {
    return GalleryItem(
      id: id ?? this.id,
      workId: workId ?? this.workId,
      sourceId: sourceId ?? _sourceId,
      site: site ?? this.site,
      title: title ?? this.title,
      author: author ?? this.author,
      description: description ?? this.description,
      aiType: aiType ?? this.aiType,
      createdAt: createdAt ?? this.createdAt,
      uploaderId: uploaderId ?? this.uploaderId,
      score: score ?? this.score,
      source: source ?? this.source,
      md5: md5 ?? this.md5,
      rating: rating ?? this.rating,
      imageWidth: imageWidth ?? this.imageWidth,
      imageHeight: imageHeight ?? this.imageHeight,
      tagString: tagString ?? this.tagString,
      tags: tags ?? _tags,
      searchTerms: searchTerms ?? this.searchTerms,
      tagsComplete: tagsComplete ?? this.tagsComplete,
      tagStringGeneral: tagStringGeneral ?? this.tagStringGeneral,
      tagStringCharacter: tagStringCharacter ?? this.tagStringCharacter,
      tagStringCopyright: tagStringCopyright ?? this.tagStringCopyright,
      tagStringArtist: tagStringArtist ?? this.tagStringArtist,
      tagStringMeta: tagStringMeta ?? this.tagStringMeta,
      fileExt: fileExt ?? this.fileExt,
      fileSize: fileSize ?? this.fileSize,
      fileUrl: fileUrl ?? this.fileUrl,
      largeFileUrl: largeFileUrl ?? this.largeFileUrl,
      previewFileUrl: previewFileUrl ?? this.previewFileUrl,
      sampleUrl: sampleUrl ?? this.sampleUrl,
      sampleWidth: sampleWidth ?? this.sampleWidth,
      sampleHeight: sampleHeight ?? this.sampleHeight,
      cover: cover ?? _cover,
      mediaCount: mediaCount ?? this.mediaCount,
      viewCount: viewCount ?? this.viewCount,
      favoriteCount: favoriteCount ?? favCount ?? this.favoriteCount,
      rank: rank ?? this.rank,
      rankingName: rankingName ?? this.rankingName,
      focusedMediaId: focusedMediaId ?? this.focusedMediaId,
      focusedMediaIndex: focusedMediaIndex ?? this.focusedMediaIndex,
      artistChain: artistChain ?? this.artistChain,
      rawSourceMetadata: rawSourceMetadata ?? this.rawSourceMetadata,
    );
  }
}

int _galleryInt(Object? value) => switch (value) {
  final int number => number,
  final num number => number.toInt(),
  final String text => int.tryParse(text) ?? 0,
  _ => 0,
};

int? _galleryNullableInt(Object? value) {
  if (value == null) return null;
  return _galleryInt(value);
}

class GalleryCharacterPrompt {
  const GalleryCharacterPrompt({
    required this.label,
    required this.prompt,
    this.negativePrompt = '',
    this.positionX,
    this.positionY,
  });

  final String label;
  final String prompt;
  final String negativePrompt;
  final double? positionX;
  final double? positionY;

  bool get hasCustomPosition => positionX != null && positionY != null;
}

class GalleryContributor {
  const GalleryContributor({required this.name, this.role = '', this.url});

  final String name;
  final String role;
  final String? url;
}

class GalleryDetail {
  const GalleryDetail({
    required this.item,
    required this.media,
    this.prompt,
    this.negativePrompt,
    this.description,
    this.categoryPath = const [],
    this.note,
    this.rawTags = const [],
    this.characterPrompts = const [],
    this.contributors = const [],
    this.sourceUrl,
    this.rawSourceMetadata = const {},
  });

  final GalleryItem item;
  final List<GalleryMedia> media;
  final String? prompt;
  final String? negativePrompt;
  final String? description;
  final List<String> categoryPath;
  final String? note;
  final List<String> rawTags;
  final List<GalleryCharacterPrompt> characterPrompts;
  final List<GalleryContributor> contributors;
  final String? sourceUrl;
  final Map<String, dynamic> rawSourceMetadata;
}

class GalleryPage {
  const GalleryPage({
    required this.items,
    required this.cursor,
    required this.nextCursor,
    required this.hasMore,
    this.total,
    this.rawItemCount = 0,
    this.rawPageIdentity,
  });

  final List<GalleryItem> items;
  final String cursor;
  final String? nextCursor;
  final bool hasMore;
  final int? total;
  final int rawItemCount;

  /// Stable identity of the upstream page before adapter-side filtering.
  final String? rawPageIdentity;
}
