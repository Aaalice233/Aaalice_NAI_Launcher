import '../derivatives/derivative_registry.dart';
import '../storage/local_storage_service.dart';

class WatermarkDerivativeRegistry extends DerivativeRegistry {
  WatermarkDerivativeRegistry(LocalStorageService storage)
    : super(storage, DerivativeKind.watermark);

  static bool looksLikeDerivativePath(String path) =>
      DerivativeKind.watermark.matchesFileName(path);
}
