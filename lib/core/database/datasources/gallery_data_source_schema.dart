import '../base_data_source.dart';
import '../data_source.dart' show DataSourceHealth;
import 'gallery_database_gateway.dart';
import 'gallery_schema.dart';
import 'gallery_store_context.dart';

export 'gallery_schema.dart';

/// Compatibility adapter for callers that composed the former schema mixin.
///
/// New code should compose [GallerySchema] directly. The adapter preserves the
/// old mixin contract while delegating all behavior to the repository-era
/// schema object.
@Deprecated('Compose GallerySchema instead')
mixin GalleryDataSourceSchema on EnhancedBaseDataSource {
  late final GalleryStoreContext _compatGalleryContext = GalleryStoreContext();
  late final GallerySchema _compatGallerySchema = GallerySchema(
    gateway: EnhancedGalleryDatabaseGateway(this),
    context: _compatGalleryContext,
  );

  @override
  Future<void> doInitialize() => _compatGallerySchema.initialize();

  @override
  Future<DataSourceHealth> doCheckHealth() =>
      _compatGallerySchema.checkHealth();

  @override
  Future<void> doClear() => _compatGallerySchema.clear();

  @override
  Future<void> doRestore() => _compatGallerySchema.restore();
}
