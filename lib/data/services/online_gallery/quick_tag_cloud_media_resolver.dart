import '../../models/online_gallery/quick_tag_cloud_catalog.dart';
import '../../models/online_gallery/quick_tag_cloud_codex.dart';

export '../../models/online_gallery/quick_tag_cloud_codex.dart'
    show QuickTagCloudEntry, QuickTagCloudImage;

enum QuickTagCloudMediaKind { image, original }

/// Resolves assets with the same path and revision rules as upstream media.js.
class QuickTagCloudMediaResolver {
  const QuickTagCloudMediaResolver({
    required this.media,
    this.isLocalOrigin = false,
  });

  final QuickTagCloudMediaConfig media;
  final bool isLocalOrigin;

  bool hasEntryImage(QuickTagCloudEntry entry) =>
      entry.images.isNotEmpty || entry.image.isNotEmpty;

  String mediaPath(
    QuickTagCloudMediaKind kind,
    QuickTagCloudEntry entry,
    QuickTagCloudCodex codex,
  ) {
    final file = kind == QuickTagCloudMediaKind.original
        ? entry.original
        : entry.image;
    if (file.isEmpty) return '';
    if (isAbsoluteUrl(file)) return file;
    if (codex.assetPathMode == 'relative') return encodeAssetPath(file);

    final prefix = kind == QuickTagCloudMediaKind.original
        ? media.originalPrefix
        : media.imagePrefix;
    final fallbackPrefix = kind == QuickTagCloudMediaKind.original
        ? 'originals'
        : 'images';
    final assetCodexId = entry.assetCodexId.isEmpty
        ? codex.id
        : entry.assetCodexId;
    return [
      prefix.isEmpty ? fallbackPrefix : prefix,
      assetCodexId,
      file,
    ].map(_encodePartPreservingSlashes).join('/');
  }

  String imageItemPath(
    QuickTagCloudMediaKind kind,
    QuickTagCloudEntry entry,
    QuickTagCloudImage item,
    QuickTagCloudCodex codex,
  ) {
    final file = kind == QuickTagCloudMediaKind.original
        ? (item.original.isEmpty ? item.path : item.original)
        : item.path;
    if (file.isEmpty) return '';
    if (isAbsoluteUrl(file)) return file;
    if (codex.assetPathMode == 'relative') return encodeAssetPath(file);
    return _codexAssetPath(kind, entry, codex, file);
  }

  String assetUrl(
    QuickTagCloudMediaKind kind,
    QuickTagCloudEntry entry,
    QuickTagCloudCodex codex,
  ) {
    final path = mediaPath(kind, entry, codex);
    return _resolvePath(path, entry.assetRev, codex);
  }

  String imageItemUrl(
    QuickTagCloudMediaKind kind,
    QuickTagCloudEntry entry,
    QuickTagCloudImage item,
    QuickTagCloudCodex codex,
  ) {
    final path = imageItemPath(kind, entry, item, codex);
    return _resolvePath(path, entry.assetRev, codex);
  }

  String thumbUrl(QuickTagCloudEntry entry, QuickTagCloudCodex codex) =>
      assetUrl(QuickTagCloudMediaKind.image, entry, codex);

  String originalUrl(QuickTagCloudEntry entry, QuickTagCloudCodex codex) =>
      assetUrl(QuickTagCloudMediaKind.original, entry, codex);

  String localAssetUrl(
    QuickTagCloudMediaKind kind,
    QuickTagCloudEntry entry,
    QuickTagCloudCodex codex,
  ) {
    if (codex.assetPathMode == 'relative') return '';
    return withRev(mediaPath(kind, entry, codex), entry.assetRev);
  }

  String withRev(String url, String assetRev) {
    if (url.isEmpty || assetRev.isEmpty) return url;
    final fragmentIndex = url.indexOf('#');
    final base = fragmentIndex < 0 ? url : url.substring(0, fragmentIndex);
    final fragment = fragmentIndex < 0 ? '' : url.substring(fragmentIndex);
    final separator = base.contains('?') ? '&' : '?';
    return '$base${separator}v=${Uri.encodeComponent(assetRev)}$fragment';
  }

  bool isAbsoluteUrl(String value) =>
      RegExp(r'^https://', caseSensitive: false).hasMatch(value);

  String encodeAssetPath(String value) {
    final fragmentIndex = value.indexOf('#');
    final withoutFragment = fragmentIndex < 0
        ? value
        : value.substring(0, fragmentIndex);
    final fragment = fragmentIndex < 0 ? '' : value.substring(fragmentIndex);
    final queryIndex = withoutFragment.indexOf('?');
    final path = queryIndex < 0
        ? withoutFragment
        : withoutFragment.substring(0, queryIndex);
    final query = queryIndex < 0 ? '' : withoutFragment.substring(queryIndex);
    return '${path.split('/').map(_encodePathSegment).join('/')}$query$fragment';
  }

  String _resolvePath(String path, String assetRev, QuickTagCloudCodex codex) {
    if (path.isEmpty) return '';
    if (isAbsoluteUrl(path)) {
      return withRev(Uri.parse(path).toString(), assetRev);
    }
    if (codex.assetPathMode == 'relative') {
      final base = codex.assetBaseUrl.replaceFirst(RegExp(r'/+$'), '');
      final relativePath = path.replaceFirst(RegExp(r'^/+'), '');
      return withRev(
        base.isEmpty ? relativePath : '$base/$relativePath',
        assetRev,
      );
    }
    if (isLocalOrigin && media.localFallback) return withRev(path, assetRev);
    final base = media.baseUrl.replaceFirst(RegExp(r'/+$'), '');
    return withRev(base.isEmpty ? path : '$base/$path', assetRev);
  }

  String _codexAssetPath(
    QuickTagCloudMediaKind kind,
    QuickTagCloudEntry entry,
    QuickTagCloudCodex codex,
    String file,
  ) {
    final prefix = kind == QuickTagCloudMediaKind.original
        ? media.originalPrefix
        : media.imagePrefix;
    final fallbackPrefix = kind == QuickTagCloudMediaKind.original
        ? 'originals'
        : 'images';
    final assetCodexId = entry.assetCodexId.isEmpty
        ? codex.id
        : entry.assetCodexId;
    return [
      prefix.isEmpty ? fallbackPrefix : prefix,
      assetCodexId,
      file,
    ].map(_encodePartPreservingSlashes).join('/');
  }

  String _encodePartPreservingSlashes(String value) =>
      value.split('/').map(_encodePathSegment).join('/');

  String _encodePathSegment(String value) {
    try {
      return Uri.encodeComponent(Uri.decodeComponent(value));
    } on FormatException {
      return Uri.encodeComponent(value);
    }
  }
}
