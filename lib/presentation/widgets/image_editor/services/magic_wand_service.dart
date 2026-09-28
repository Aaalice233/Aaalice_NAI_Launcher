import '../../../../core/utils/contiguous_region_selector.dart';
import '../../../../core/utils/editor_compression_utils.dart';
import '../../../../data/services/efficient_vit_sam_service.dart';

class MagicWandService {
  MagicWandService({EfficientVitSamService? service})
    : _service = service ?? EfficientVitSamService();

  final EfficientVitSamService _service;

  Future<ContiguousRegionSelection> select({
    required EditorRawRgbaImage source,
    required int startX,
    required int startY,
    required bool invert,
    EfficientVitSamProgressCallback? onProgress,
  }) => _service.selectRgba(
    rgba: source.bytes,
    width: source.width,
    height: source.height,
    startX: startX,
    startY: startY,
    invert: invert,
    onProgress: onProgress,
  );

  void dispose() => _service.dispose();
}
