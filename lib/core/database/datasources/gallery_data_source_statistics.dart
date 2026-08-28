import '../../../data/models/gallery/gallery_dashboard_snapshot.dart';
import 'gallery_data_source.dart';

/// Compatibility extension retained for the former direct import path.
///
/// Statistics are now implemented by the query repository and exposed by the
/// [GalleryDataSource] facade.
@Deprecated('Use GalleryDataSource.getDashboardStatistics directly')
extension GalleryDataSourceStatistics on GalleryDataSource {
  Future<GalleryDashboardSnapshot> getDashboardStatistics() =>
      this.getDashboardStatistics();
}
