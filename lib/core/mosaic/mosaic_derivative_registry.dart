import '../derivatives/derivative_registry.dart';
import '../storage/local_storage_service.dart';

class MosaicDerivativeRegistry extends DerivativeRegistry {
  MosaicDerivativeRegistry(LocalStorageService storage)
    : super(storage, DerivativeKind.mosaic);

  static bool looksLikeDerivativePath(String path) =>
      DerivativeKind.mosaic.matchesFileName(path);
}
