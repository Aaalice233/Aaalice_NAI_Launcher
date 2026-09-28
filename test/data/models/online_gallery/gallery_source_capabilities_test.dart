import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';

void main() {
  test('only Danbooru advertises remote blacklist synchronization', () {
    expect(
      gallerySourceCapabilities[GallerySourceId.danbooru]?.remoteBlacklist,
      GalleryRemoteBlacklistCapability.readWrite,
    );
    for (final source in GallerySourceId.values.where(
      (source) => source != GallerySourceId.danbooru,
    )) {
      expect(
        gallerySourceCapabilities[source]?.remoteBlacklist,
        GalleryRemoteBlacklistCapability.none,
        reason: source.key,
      );
    }
  });
}
