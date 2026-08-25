import 'dart:collection';

import 'quick_tag_cloud_catalog.dart';

String quickTagCloudEntryWorkId(String codexId, String entryId) =>
    '${Uri.encodeComponent(codexId)}/${Uri.encodeComponent(entryId)}';

class QuickTagCloudDimensions {
  const QuickTagCloudDimensions({this.width = 0, this.height = 0});

  final int width;
  final int height;

  bool get isKnown => width > 0 && height > 0;
  double get aspectRatio => isKnown ? width / height : 1;
}

class QuickTagCloudCharacterPrompt {
  const QuickTagCloudCharacterPrompt({
    required this.label,
    required this.prompt,
    required this.negative,
  });

  final String label;
  final String prompt;
  final String negative;
}

class QuickTagCloudImage {
  QuickTagCloudImage({
    required this.path,
    required this.original,
    required this.hasOriginal,
    this.rawTag = '',
    this.dimensions = const QuickTagCloudDimensions(),
    Map<String, dynamic> raw = const {},
  }) : raw = UnmodifiableMapView(raw);

  final String path;
  final String original;
  final bool hasOriginal;
  final String rawTag;
  final QuickTagCloudDimensions dimensions;
  final Map<String, dynamic> raw;
}

class QuickTagCloudEntry {
  QuickTagCloudEntry({
    required this.id,
    required this.title,
    required List<String> path,
    required this.tags,
    required this.negative,
    required this.note,
    required this.author,
    required this.credit,
    required this.rating,
    required this.isNew,
    required List<String> updateBatches,
    required List<QuickTagCloudCharacterPrompt> characterPrompts,
    required List<QuickTagCloudImage> images,
    required this.image,
    required this.original,
    required this.assetRev,
    required this.dimensions,
    required this.rawTag,
    this.assetCodexId = '',
    Map<String, dynamic> raw = const {},
  }) : path = List.unmodifiable(path),
       updateBatches = List.unmodifiable(updateBatches),
       characterPrompts = List.unmodifiable(characterPrompts),
       images = List.unmodifiable(images),
       raw = UnmodifiableMapView(raw);

  final String id;
  final String title;
  final List<String> path;
  final String tags;
  final String negative;
  final String note;
  final String author;
  final String credit;
  final String rating;
  final bool isNew;
  final List<String> updateBatches;
  final List<QuickTagCloudCharacterPrompt> characterPrompts;
  final List<QuickTagCloudImage> images;
  final String image;
  final String original;
  final String assetRev;
  final QuickTagCloudDimensions dimensions;
  final String rawTag;
  final String assetCodexId;
  final Map<String, dynamic> raw;

  int get imageWidth => dimensions.width;
  int get imageHeight => dimensions.height;
  String get rawTags => rawTag;
  bool get hasImage => images.isNotEmpty || image.isNotEmpty;
}

enum QuickTagCloudCodexLoadSource {
  canonical,
  external,
  fallback,
  previousRelease,
}

class QuickTagCloudCodex {
  QuickTagCloudCodex({
    required this.id,
    required this.type,
    required this.title,
    required this.version,
    required this.author,
    required this.nsfw,
    required this.assetBaseUrl,
    required this.assetPathMode,
    required this.dataUrl,
    required this.sourceDataUrl,
    required this.fallbackDataUrl,
    required this.source,
    required List<String> aliases,
    required this.hasOriginal,
    required List<QuickTagCloudEntry> entries,
    required this.entryCount,
    required this.imagedCount,
    required List<dynamic> tree,
    required this.loadSource,
    this.metadata,
    this.mediaOverride,
    this.sourceRelease = '',
    this.externalError,
    Map<String, dynamic> raw = const {},
  }) : aliases = List.unmodifiable(aliases),
       entries = List.unmodifiable(entries),
       tree = List.unmodifiable(tree),
       raw = UnmodifiableMapView(raw);

  final String id;
  final String type;
  final String title;
  final String version;
  final String author;
  final bool nsfw;
  final String assetBaseUrl;
  final String assetPathMode;
  final String dataUrl;
  final String sourceDataUrl;
  final String fallbackDataUrl;
  final String source;
  final List<String> aliases;
  final bool hasOriginal;
  final List<QuickTagCloudEntry> entries;
  final int entryCount;
  final int imagedCount;
  final List<dynamic> tree;
  final QuickTagCloudCodexLoadSource loadSource;
  final QuickTagCloudCodexMeta? metadata;
  final QuickTagCloudMediaConfig? mediaOverride;
  final String sourceRelease;
  final Object? externalError;
  final Map<String, dynamic> raw;

  QuickTagCloudCodexMeta asMediaMeta() {
    final sourceMeta = metadata;
    return QuickTagCloudCodexMeta(
      id: id,
      title: title,
      type: type,
      version: version,
      author: author,
      entryCount: entryCount,
      imagedCount: imagedCount,
      hasOriginal: hasOriginal,
      nsfw: nsfw,
      dataUrl: dataUrl,
      fallbackDataUrl: fallbackDataUrl,
      fallbackVersion: sourceMeta?.fallbackVersion ?? '',
      assetBaseUrl: assetBaseUrl,
      assetPathMode: assetPathMode,
      source: source,
      cover: sourceMeta?.cover ?? '',
      coverRev: sourceMeta?.coverRev ?? '',
      coverCodexId: sourceMeta?.coverCodexId ?? '',
      newFilterLabel: sourceMeta?.newFilterLabel ?? '',
      aliases: aliases,
      contributors: sourceMeta?.contributors ?? const [],
      links: sourceMeta?.links ?? const [],
      updateFilters: sourceMeta?.updateFilters ?? const [],
      raw: raw,
    );
  }
}
