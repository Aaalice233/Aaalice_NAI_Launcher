enum GalleryMediaKind { staticImage, animatedImage, video, unknown }

/// Canonical media decision used before anything is handed to Flutter's image
/// codecs. A video signal always wins a conflicting image signal because the
/// safe failure mode is a stable placeholder, not decoding video bytes.
class GalleryMediaCapability {
  const GalleryMediaCapability({
    required this.kind,
    required this.previewKind,
    required this.previewUrl,
    required this.displayUrl,
    required this.downloadUrl,
  });

  final GalleryMediaKind kind;
  final GalleryMediaKind previewKind;
  final String previewUrl;
  final String displayUrl;
  final String downloadUrl;

  bool get isVideo => kind == GalleryMediaKind.video;
  bool get isAnimatedImage => kind == GalleryMediaKind.animatedImage;
  bool get isFlutterImage =>
      kind == GalleryMediaKind.staticImage ||
      kind == GalleryMediaKind.animatedImage;
  bool get hasStaticThumbnail =>
      previewUrl.isNotEmpty && previewKind == GalleryMediaKind.staticImage;
  bool get canPrefetchPreview =>
      previewUrl.isNotEmpty &&
      (previewKind == GalleryMediaKind.staticImage ||
          previewKind == GalleryMediaKind.animatedImage);

  static bool isKnownVideoUrl(String url) =>
      _kindForUrl(url) == GalleryMediaKind.video;

  String get imageDisplayUrl {
    if (isFlutterImage && displayUrl.isNotEmpty) {
      final displayKind = _kindForUrl(displayUrl);
      if (displayKind != GalleryMediaKind.video) return displayUrl;
    }
    if (canPrefetchPreview) return previewUrl;
    return '';
  }

  String get videoUrl {
    if (!isVideo) return '';
    final candidates = <String>[downloadUrl, displayUrl];
    for (final candidate in candidates) {
      if (_kindForUrl(candidate) == GalleryMediaKind.video) {
        return candidate.trim();
      }
    }
    for (final candidate in candidates) {
      if (candidate.trim().isNotEmpty &&
          _kindForUrl(candidate) == GalleryMediaKind.unknown) {
        return candidate.trim();
      }
    }
    return '';
  }

  static GalleryMediaCapability resolve({
    String? declaredType,
    String? extension,
    String? mimeType,
    String previewUrl = '',
    String displayUrl = '',
    String downloadUrl = '',
  }) {
    final declaredKind = _kindForDeclaredType(declaredType);
    final extensionKind = _kindForExtension(extension);
    final mimeKind = _kindForMime(mimeType);
    final primaryUrl = _firstNonEmpty(<String>[downloadUrl, displayUrl]);
    final urlKind = _kindForUrl(primaryUrl);
    final kind = _strongest(<GalleryMediaKind>[
      declaredKind,
      extensionKind,
      mimeKind,
      urlKind,
    ]);
    final detectedPreviewKind = _kindForUrl(previewUrl);
    final previewKind = detectedPreviewKind != GalleryMediaKind.unknown
        ? detectedPreviewKind
        : isImageKind(kind)
        ? kind
        : GalleryMediaKind.unknown;
    return GalleryMediaCapability(
      kind: kind,
      previewKind: previewKind,
      previewUrl: previewUrl.trim(),
      displayUrl: displayUrl.trim(),
      downloadUrl: downloadUrl.trim(),
    );
  }

  static GalleryMediaKind _kindForDeclaredType(String? value) {
    final normalized = value?.trim().toLowerCase();
    return switch (normalized) {
      'video' || 'movie' => GalleryMediaKind.video,
      'animation' || 'animated' || 'gif' => GalleryMediaKind.animatedImage,
      'image' || 'photo' || 'static' => GalleryMediaKind.staticImage,
      _ => GalleryMediaKind.unknown,
    };
  }

  static GalleryMediaKind _kindForMime(String? value) {
    final mime = value?.split(';').first.trim().toLowerCase() ?? '';
    if (mime.startsWith('video/')) return GalleryMediaKind.video;
    if (mime == 'image/gif') return GalleryMediaKind.animatedImage;
    if (mime.startsWith('image/')) return GalleryMediaKind.staticImage;
    return GalleryMediaKind.unknown;
  }

  static GalleryMediaKind _kindForUrl(String value) {
    if (value.trim().isEmpty) return GalleryMediaKind.unknown;
    final uri = Uri.tryParse(value.trim());
    return _kindForExtension(_pathExtension(uri?.path ?? value));
  }

  static GalleryMediaKind _kindForExtension(String? value) {
    final extension = value?.trim().toLowerCase().replaceFirst(
      RegExp(r'^\.'),
      '',
    );
    return switch (extension) {
      'webm' || 'mp4' || 'm4v' || 'mov' => GalleryMediaKind.video,
      'gif' => GalleryMediaKind.animatedImage,
      'jpg' ||
      'jpeg' ||
      'png' ||
      'webp' ||
      'bmp' ||
      'avif' => GalleryMediaKind.staticImage,
      _ => GalleryMediaKind.unknown,
    };
  }

  static GalleryMediaKind _strongest(Iterable<GalleryMediaKind> kinds) {
    if (kinds.contains(GalleryMediaKind.video)) return GalleryMediaKind.video;
    if (kinds.contains(GalleryMediaKind.animatedImage)) {
      return GalleryMediaKind.animatedImage;
    }
    if (kinds.contains(GalleryMediaKind.staticImage)) {
      return GalleryMediaKind.staticImage;
    }
    return GalleryMediaKind.unknown;
  }

  static String _pathExtension(String path) {
    final slash = path.lastIndexOf('/');
    final dot = path.lastIndexOf('.');
    if (dot <= slash || dot == path.length - 1) return '';
    return path.substring(dot + 1);
  }

  static bool isImageKind(GalleryMediaKind kind) =>
      kind == GalleryMediaKind.staticImage ||
      kind == GalleryMediaKind.animatedImage;

  static String _firstNonEmpty(Iterable<String> values) {
    for (final value in values) {
      if (value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }
}
