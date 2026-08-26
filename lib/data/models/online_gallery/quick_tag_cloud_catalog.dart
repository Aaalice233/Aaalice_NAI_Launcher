import 'dart:collection';

/// Fixed QuickTagCloud bootstrap document.
class QuickTagCloudDataSourceConfig {
  const QuickTagCloudDataSourceConfig({
    required this.schemaVersion,
    required this.baseUrl,
    required this.pointer,
  });

  final int schemaVersion;
  final Uri baseUrl;
  final String pointer;
}

class QuickTagCloudReleasePointer {
  const QuickTagCloudReleasePointer({
    required this.schemaVersion,
    required this.release,
    required this.manifest,
    this.contentHash = '',
    this.publishedAt = '',
    this.previousRelease = '',
  });

  final int schemaVersion;
  final String release;
  final String manifest;
  final String contentHash;
  final String publishedAt;
  final String previousRelease;
}

class QuickTagCloudManifestFile {
  const QuickTagCloudManifestFile({
    required this.path,
    required this.size,
    required this.sha256,
  });

  final String path;
  final int size;
  final String sha256;
}

class QuickTagCloudReleaseManifest {
  QuickTagCloudReleaseManifest({
    required this.schemaVersion,
    required this.release,
    required Map<String, QuickTagCloudManifestFile> files,
    this.contentHash = '',
  }) : files = UnmodifiableMapView(files);

  final int schemaVersion;
  final String release;
  final String contentHash;
  final Map<String, QuickTagCloudManifestFile> files;

  QuickTagCloudManifestFile requireFile(String path) {
    final file = files[path];
    if (file == null) {
      throw FormatException('QuickTagCloud manifest does not contain $path');
    }
    return file;
  }
}

class QuickTagCloudMediaConfig {
  const QuickTagCloudMediaConfig({
    this.baseUrl = '',
    this.bucket = '',
    this.imagePrefix = 'images',
    this.originalPrefix = 'originals',
    this.localFallback = true,
  });

  final String baseUrl;
  final String bucket;
  final String imagePrefix;
  final String originalPrefix;
  final bool localFallback;
}

class QuickTagCloudContributor {
  const QuickTagCloudContributor({required this.name, required this.role});

  final String name;
  final String role;
}

class QuickTagCloudLink {
  const QuickTagCloudLink({required this.label, required this.url});

  final String label;
  final String url;
}

class QuickTagCloudUpdateFilter {
  const QuickTagCloudUpdateFilter({
    required this.id,
    required this.label,
    this.latest = false,
  });

  final String id;
  final String label;
  final bool latest;
}

class QuickTagCloudCodexMeta {
  QuickTagCloudCodexMeta({
    required this.id,
    required this.title,
    this.type = 'codex',
    this.version = '',
    this.author = '',
    this.entryCount = 0,
    this.imagedCount = 0,
    this.hasOriginal = false,
    this.nsfw = false,
    this.dataUrl = '',
    this.fallbackDataUrl = '',
    this.fallbackVersion = '',
    this.assetBaseUrl = '',
    this.assetPathMode = '',
    this.source = '',
    this.cover = '',
    this.coverRev = '',
    this.coverCodexId = '',
    this.newFilterLabel = '',
    List<String> aliases = const [],
    List<QuickTagCloudContributor> contributors = const [],
    List<QuickTagCloudLink> links = const [],
    List<QuickTagCloudUpdateFilter> updateFilters = const [],
    Map<String, dynamic> raw = const {},
  }) : aliases = List.unmodifiable(aliases),
       contributors = List.unmodifiable(contributors),
       links = List.unmodifiable(links),
       updateFilters = List.unmodifiable(updateFilters),
       raw = UnmodifiableMapView(raw);

  final String id;
  final String type;
  final String title;
  final String version;
  final String author;
  final int entryCount;
  final int imagedCount;
  final bool hasOriginal;
  final bool nsfw;
  final String dataUrl;
  final String fallbackDataUrl;
  final String fallbackVersion;
  final String assetBaseUrl;
  final String assetPathMode;
  final String source;
  final String cover;
  final String coverRev;
  final String coverCodexId;
  final String newFilterLabel;
  final List<String> aliases;
  final List<QuickTagCloudContributor> contributors;
  final List<QuickTagCloudLink> links;
  final List<QuickTagCloudUpdateFilter> updateFilters;
  final Map<String, dynamic> raw;

  bool get isExternal => dataUrl.isNotEmpty;
}

class QuickTagCloudCatalog {
  QuickTagCloudCatalog({
    required this.config,
    required this.pointer,
    required this.manifest,
    required List<QuickTagCloudCodexMeta> codexes,
    required this.media,
    this.isOffline = false,
    this.refreshError,
  }) : codexes = List.unmodifiable(codexes);

  final QuickTagCloudDataSourceConfig config;
  final QuickTagCloudReleasePointer pointer;
  final QuickTagCloudReleaseManifest manifest;
  final List<QuickTagCloudCodexMeta> codexes;
  final QuickTagCloudMediaConfig media;
  final bool isOffline;
  final Object? refreshError;

  String get release => pointer.release;

  Uri get releaseBaseUrl => Uri.parse(
    '${config.baseUrl.toString().replaceFirst(RegExp(r'/+$'), '')}'
    '/releases/${pointer.release}/',
  );

  QuickTagCloudCodexMeta? findCodex(String idOrAlias) {
    for (final codex in codexes) {
      if (codex.id == idOrAlias || codex.aliases.contains(idOrAlias)) {
        return codex;
      }
    }
    return null;
  }
}
