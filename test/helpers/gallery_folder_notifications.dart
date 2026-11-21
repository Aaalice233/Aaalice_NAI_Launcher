import 'package:nai_launcher/presentation/providers/gallery_category_provider.dart';

class RecordingGalleryFolders extends GalleryCategoryNotifier {
  RecordingGalleryFolders([this.initial = const GalleryCategoryState()]);
  final GalleryCategoryState initial;
  final notifications = <List<String>>[];
  int syncs = 0;

  @override
  GalleryCategoryState build() => initial;
  @override
  Future<void> updateForImagePaths(
    List<String> paths,
    int Function(String) countIn,
  ) async => notifications.add(paths);
  @override
  Future<void> syncWithFileSystem() async => syncs++;
}
