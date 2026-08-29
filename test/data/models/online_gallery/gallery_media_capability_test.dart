import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_item.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_media_capability.dart';

void main() {
  group('GalleryMediaCapability', () {
    test('video metadata wins a misleading image URL', () {
      final capability = GalleryMediaCapability.resolve(
        declaredType: 'video',
        mimeType: 'video/webm',
        extension: 'jpg',
        previewUrl: 'https://cdn.example/thumb.jpg?size=small',
        displayUrl: 'https://cdn.example/not-a-frame.jpg',
        downloadUrl: 'https://cdn.example/movie.WEBM?token=secret',
      );

      expect(capability.kind, GalleryMediaKind.video);
      expect(capability.hasStaticThumbnail, isTrue);
      expect(capability.imageDisplayUrl, capability.previewUrl);
      expect(capability.videoUrl, contains('movie.WEBM'));
    });

    test('mixed-case URL path and query classify without using query text', () {
      expect(
        GalleryMediaCapability.resolve(
          displayUrl: 'https://cdn.example/a/b/IMAGE.JpG?format=mp4',
        ).kind,
        GalleryMediaKind.staticImage,
      );
      expect(
        GalleryMediaCapability.resolve(
          displayUrl: 'https://cdn.example/a/b/CLIP.MP4?format=jpg',
        ).kind,
        GalleryMediaKind.video,
      );
    });

    test('video preview is never exposed to Flutter image decoding', () {
      final capability = GalleryMediaCapability.resolve(
        declaredType: 'video',
        previewUrl: 'https://cdn.example/preview.webm',
        downloadUrl: 'https://cdn.example/original.webm',
      );

      expect(capability.canPrefetchPreview, isFalse);
      expect(capability.hasStaticThumbnail, isFalse);
      expect(capability.imageDisplayUrl, isEmpty);
    });

    test('unknown extension remains unknown instead of guessing image', () {
      final capability = GalleryMediaCapability.resolve(
        displayUrl: 'https://cdn.example/blob?id=1',
      );
      expect(capability.kind, GalleryMediaKind.unknown);
      expect(capability.isFlutterImage, isFalse);
    });

    test('media without source declarations defaults to unknown', () {
      const media = GalleryMedia(
        id: 'unknown',
        displayUrl: 'https://cdn.example/blob?id=1',
      );

      expect(media.capability.kind, GalleryMediaKind.unknown);
      expect(media.capability.isFlutterImage, isFalse);
    });

    test('declared images may use extensionless CDN URLs', () {
      final capability = GalleryMediaCapability.resolve(
        declaredType: 'image',
        previewUrl: 'https://cdn.example/preview?id=1',
        displayUrl: 'https://cdn.example/display?id=1',
      );

      expect(capability.canPrefetchPreview, isTrue);
      expect(capability.imageDisplayUrl, capability.displayUrl);
    });

    test('extensionless video previews remain placeholders', () {
      final capability = GalleryMediaCapability.resolve(
        declaredType: 'video',
        previewUrl: 'https://cdn.example/preview?id=1',
        downloadUrl: 'https://cdn.example/video?id=1',
      );

      expect(capability.canPrefetchPreview, isFalse);
      expect(capability.imageDisplayUrl, isEmpty);
      expect(capability.videoUrl, capability.downloadUrl);
    });

    test('video metadata never sends a known static URL to the player', () {
      final capability = GalleryMediaCapability.resolve(
        declaredType: 'video',
        displayUrl: 'https://cdn.example/fallback.jpg',
      );

      expect(capability.kind, GalleryMediaKind.video);
      expect(capability.videoUrl, isEmpty);
      expect(capability.imageDisplayUrl, isEmpty);
    });
  });
}
