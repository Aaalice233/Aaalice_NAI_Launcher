import '../../core/utils/app_logger.dart';
import '../../data/models/gallery/local_image_record.dart';
import '../../data/models/gallery/nai_image_metadata.dart';
import '../../data/services/image_metadata_service.dart';

typedef LocalGalleryMetadataLoader =
    Future<NaiImageMetadata?> Function(String path);

Future<NaiImageMetadata?> resolveLocalGalleryMetadata(
  LocalImageRecord record, {
  LocalGalleryMetadataLoader? loadFromFile,
}) async {
  try {
    final parsed = await (loadFromFile ?? _loadMetadataFromFile)(record.path);
    if (parsed?.hasData == true) {
      return parsed!.upgradeFromRawJsonIfNeeded();
    }
  } catch (error) {
    AppLogger.w(
      'Failed to refresh local gallery metadata for ${record.path}: $error',
      'LocalGalleryMetadata',
    );
  }

  final indexed = record.metadata?.upgradeFromRawJsonIfNeeded();
  return indexed?.hasData == true ? indexed : null;
}

Future<NaiImageMetadata?> _loadMetadataFromFile(String path) {
  return ImageMetadataService().getMetadataImmediate(path);
}
