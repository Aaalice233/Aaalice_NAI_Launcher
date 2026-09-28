import '../providers/generation/generation_models.dart';
import 'dropped_file_reader.dart';

Map<String, Object> buildHistoryInternalDragLocalData(String? imageId) {
  return {
    'source': 'history_internal',
    if (imageId != null && imageId.isNotEmpty) 'imageId': imageId,
  };
}

bool isGalleryInternalDragLocalData(Object? localData) {
  return localData is Map && localData['source'] == 'gallery_internal';
}

bool isHistoryInternalDragLocalData(Object? localData) {
  return localData is Map && localData['source'] == 'history_internal';
}

DroppedFileData? resolveInternalHistoryDropPayload(
  Object? localData,
  ImageGenerationState state,
) {
  if (!isHistoryInternalDragLocalData(localData)) return null;
  final data = localData as Map;
  final imageId = data['imageId'];
  if (imageId is! String || imageId.trim().isEmpty) return null;

  final image = state.findImageById(imageId);
  if (image == null || !image.canDrag) return null;
  return DroppedFileData(
    fileName: 'history_${image.id}.png',
    bytes: image.bytes,
  );
}
