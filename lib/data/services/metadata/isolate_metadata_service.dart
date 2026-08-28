import '../../models/gallery/nai_image_metadata.dart';
import 'isolate_metadata_protocol.dart';
import 'metadata_isolate_worker.dart';
import 'metadata_worker_pool.dart';

export 'isolate_metadata_protocol.dart'
    show
        metadataResponseMatchesActiveRequest,
        MetadataWorkerInitializer,
        MetadataWorkerEntrypoint,
        IsolateParseFailureKind,
        IsolateParseConfig,
        IsolateParseResult;

/// Backward-compatible facade over the metadata worker pool.
class IsolateMetadataService {
  IsolateMetadataService._(this._pool);

  static IsolateMetadataService? _instance;
  static IsolateMetadataService get instance =>
      _instance ??= IsolateMetadataService._(MetadataWorkerPool());

  factory IsolateMetadataService.forTesting({
    MetadataWorkerInitializer? workerInitializer,
    MetadataWorkerEntrypoint workerEntrypoint = metadataIsolateEntryPoint,
    Duration workerStartupTimeout = const Duration(seconds: 5),
    int maxWorkers = 2,
  }) => IsolateMetadataService._(
    MetadataWorkerPool(
      workerInitializer: workerInitializer,
      workerEntrypoint: workerEntrypoint,
      workerStartupTimeout: workerStartupTimeout,
      maxWorkers: maxWorkers,
    ),
  );

  final MetadataWorkerPool _pool;

  Future<void> initialize() => _pool.initialize();

  Future<IsolateParseResult> parseMetadata(
    String filePath, {
    IsolateParseConfig config = const IsolateParseConfig(),
  }) => _pool.parseMetadata(filePath, config: config);

  Future<NaiImageMetadata?> parseForDetailView(String filePath) =>
      _pool.parseForDetailView(filePath);

  Future<NaiImageMetadata?> parseForEdit(String filePath) =>
      _pool.parseForEdit(filePath);

  void cancelAll() => _pool.cancelAll();

  Map<String, dynamic> getStatistics() => _pool.getStatistics();

  void resetStatistics() => _pool.resetStatistics();

  void dispose() => _pool.dispose();
}
