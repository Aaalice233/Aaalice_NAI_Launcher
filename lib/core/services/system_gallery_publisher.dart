import 'dart:typed_data';

import '../platform/platform_capabilities.dart';
import 'android_media_store_service.dart';

/// Mirrors images already saved to the app gallery into the system gallery,
/// honoring the user's sync preference. Explicit "save to system gallery"
/// exports call [AndroidMediaStoreService] directly and ignore the preference.
class SystemGalleryPublisher {
  SystemGalleryPublisher({
    required this.syncEnabled,
    PlatformCapabilities? capabilities,
    SystemGalleryImageWriter? writeImage,
    SystemGalleryFileWriter? writeFile,
  }) : capabilities = capabilities ?? PlatformCapabilities.current,
       _writeImage = writeImage ?? _writeImageToMediaStore,
       _writeFile = writeFile ?? _writeFileToMediaStore;

  final bool syncEnabled;
  final PlatformCapabilities capabilities;
  final SystemGalleryImageWriter _writeImage;
  final SystemGalleryFileWriter _writeFile;

  bool get isActive => capabilities.supportsSystemGalleryExport && syncEnabled;

  Future<SystemGalleryPublishOutcome> publishPng({
    required Uint8List bytes,
    required String fileName,
  }) => _publish(() => _writeImage(bytes, fileName, 'image/png'));

  Future<SystemGalleryPublishOutcome> publishFile({
    required String sourcePath,
    required String fileName,
    String? mimeType,
  }) => _publish(() => _writeFile(sourcePath, fileName, mimeType));

  Future<SystemGalleryPublishOutcome> _publish(
    Future<void> Function() write,
  ) async {
    if (!capabilities.supportsSystemGalleryExport) {
      return const SystemGalleryUnsupported();
    }
    if (!syncEnabled) return const SystemGallerySyncDisabled();
    try {
      await write();
      return const SystemGalleryPublished();
    } on Object catch (error, stackTrace) {
      return SystemGalleryPublishFailed(error, stackTrace);
    }
  }

  static Future<void> _writeImageToMediaStore(
    Uint8List bytes,
    String fileName,
    String mimeType,
  ) => AndroidMediaStoreService.saveImage(
    bytes: bytes,
    fileName: fileName,
    mimeType: mimeType,
  );

  static Future<void> _writeFileToMediaStore(
    String sourcePath,
    String fileName,
    String? mimeType,
  ) => AndroidMediaStoreService.saveImageFromPath(
    sourcePath: sourcePath,
    fileName: fileName,
    mimeType: mimeType,
  );
}

typedef SystemGalleryImageWriter =
    Future<void> Function(Uint8List bytes, String fileName, String mimeType);

typedef SystemGalleryFileWriter =
    Future<void> Function(String sourcePath, String fileName, String? mimeType);

sealed class SystemGalleryPublishOutcome {
  const SystemGalleryPublishOutcome();

  void throwIfFailed() {}
}

final class SystemGalleryUnsupported extends SystemGalleryPublishOutcome {
  const SystemGalleryUnsupported();
}

final class SystemGallerySyncDisabled extends SystemGalleryPublishOutcome {
  const SystemGallerySyncDisabled();
}

final class SystemGalleryPublished extends SystemGalleryPublishOutcome {
  const SystemGalleryPublished();
}

final class SystemGalleryPublishFailed extends SystemGalleryPublishOutcome {
  const SystemGalleryPublishFailed(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;

  @override
  void throwIfFailed() => Error.throwWithStackTrace(error, stackTrace);
}
