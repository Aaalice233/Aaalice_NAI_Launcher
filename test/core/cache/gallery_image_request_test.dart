// ignore_for_file: prefer_const_constructors

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/cache/gallery_image_request.dart';
import 'package:nai_launcher/data/models/online_gallery/gallery_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('GalleryImageTier', () {
    test('has correct enum values', () {
      expect(GalleryImageTier.values.length, 3);
      expect(GalleryImageTier.thumbnail.name, 'thumbnail');
      expect(GalleryImageTier.sample.name, 'sample');
      expect(GalleryImageTier.original.name, 'original');
    });
  });

  group('GalleryImagePriority', () {
    test('has correct enum values', () {
      expect(GalleryImagePriority.values.length, 4);
      expect(GalleryImagePriority.interactiveDetail.name, 'interactiveDetail');
      expect(GalleryImagePriority.hover.name, 'hover');
      expect(GalleryImagePriority.visible.name, 'visible');
      expect(GalleryImagePriority.lookahead.name, 'lookahead');
    });
  });

  group('GalleryImageSizing', () {
    test('gridTargetWidth respects layout, DPR and 1600px cap', () {
      expect(
        GalleryImageSizing.gridTargetWidth(
          layoutWidth: 320,
          devicePixelRatio: 1,
        ),
        320,
      );
      expect(
        GalleryImageSizing.gridTargetWidth(
          layoutWidth: 900,
          devicePixelRatio: 2,
        ),
        1600,
      );
      expect(
        GalleryImageSizing.gridTargetWidth(
          layoutWidth: 500,
          devicePixelRatio: 2,
          naturalWidth: 800,
        ),
        800,
      );
    });

    test('hoverTargetWidth respects DPR and max dimension', () {
      // Standard DPR
      expect(GalleryImageSizing.hoverTargetWidth(1.0), 320);

      // High DPR, but under max
      expect(GalleryImageSizing.hoverTargetWidth(3.0), 960);

      // Very high DPR, capped at max
      expect(GalleryImageSizing.hoverTargetWidth(5.0), 1280);

      // With natural width smaller than target
      expect(GalleryImageSizing.hoverTargetWidth(2.0, naturalWidth: 400), 400);

      // With natural width larger than target
      expect(GalleryImageSizing.hoverTargetWidth(1.0, naturalWidth: 500), 320);
    });

    test(
      'detailViewportTargetWidth respects viewport, DPR and max dimension',
      () {
        // Standard viewport and DPR
        expect(GalleryImageSizing.detailViewportTargetWidth(1.0, 800.0), 800);

        // High DPR
        expect(GalleryImageSizing.detailViewportTargetWidth(2.0, 800.0), 1600);

        // Large viewport, capped at max
        expect(GalleryImageSizing.detailViewportTargetWidth(2.0, 2000.0), 2560);

        // With natural width smaller than target
        expect(
          GalleryImageSizing.detailViewportTargetWidth(
            1.5,
            1000.0,
            naturalWidth: 1200,
          ),
          1200,
        );

        // With natural width larger than target
        expect(
          GalleryImageSizing.detailViewportTargetWidth(
            1.0,
            1000.0,
            naturalWidth: 1500,
          ),
          1000,
        );
      },
    );

    test('originalTargetWidth respects viewport, DPR*2 and max dimension', () {
      // Standard viewport and DPR
      expect(GalleryImageSizing.originalTargetWidth(1.0, 800.0), 1600);

      // High DPR
      expect(GalleryImageSizing.originalTargetWidth(1.5, 800.0), 2400);

      // Large viewport, capped at max
      expect(GalleryImageSizing.originalTargetWidth(2.0, 1500.0), 4096);

      // With natural width smaller than target
      expect(
        GalleryImageSizing.originalTargetWidth(1.0, 1000.0, naturalWidth: 1500),
        1500,
      );

      // With natural width larger than target
      expect(
        GalleryImageSizing.originalTargetWidth(1.0, 800.0, naturalWidth: 2000),
        1600,
      );
    });
  });

  group('GalleryImageRequest', () {
    test('generates consistent stable request keys', () {
      final request1 = GalleryImageRequest(
        sourceId: 'test',
        url: 'https://example.com/image.jpg',
        cacheKey: 'custom-key',
        tier: GalleryImageTier.thumbnail,
        targetDecodeWidth: 320,
      );

      final request2 = GalleryImageRequest(
        sourceId: 'test',
        url: 'https://example.com/image.jpg',
        cacheKey: 'custom-key',
        tier: GalleryImageTier.thumbnail,
        targetDecodeWidth: 320,
      );

      expect(request1.stableRequestKey, request2.stableRequestKey);
      expect(request1.stableRequestKey, 'test:custom-key:thumbnail:320');
    });

    test('uses URL as canonical cache key when cacheKey is null', () {
      final request = GalleryImageRequest(
        sourceId: 'test',
        url: 'https://example.com/image.jpg',
        tier: GalleryImageTier.sample,
        targetDecodeWidth: 640,
      );

      expect(
        request.stableRequestKey,
        'test:https://example.com/image.jpg:sample:640',
      );
    });

    test('handles null targetDecodeWidth in stable key', () {
      final request = GalleryImageRequest(
        sourceId: 'test',
        url: 'https://example.com/image.jpg',
        tier: GalleryImageTier.original,
      );

      expect(
        request.stableRequestKey,
        'test:https://example.com/image.jpg:original:auto',
      );
    });

    test('transport identity ignores tier and decode width', () {
      const url = 'https://example.com/image.webp';
      final thumbnail = GalleryImageRequest(
        sourceId: 'ai_tag',
        url: url,
        tier: GalleryImageTier.thumbnail,
        targetDecodeWidth: 320,
      );
      final sample = GalleryImageRequest(
        sourceId: 'ai_tag',
        url: url,
        tier: GalleryImageTier.sample,
        targetDecodeWidth: 960,
      );

      expect(thumbnail.transportKey, sample.transportKey);
      expect(thumbnail.stableRequestKey, isNot(sample.stableRequestKey));
    });

    test('provider identity is stable and decode width remains bounded', () {
      final request = GalleryImageRequest(
        sourceId: 'ai_tag',
        url: 'https://example.com/image.webp',
        tier: GalleryImageTier.thumbnail,
        targetDecodeWidth: 960,
      );
      final cacheManager = _NoopCacheManager();
      final first = request.createImageProvider(cacheManager);
      final second = request.createImageProvider(cacheManager);

      expect(first, isA<ResizeImage>());
      expect(first, second);
      final resized = first as ResizeImage;
      expect(resized.width, 960);
      expect(resized.imageProvider, isA<CachedNetworkImageProvider>());
    });

    test('equality is based on stable request key', () {
      final request1 = GalleryImageRequest(
        sourceId: 'test',
        url: 'https://example.com/image.jpg',
        tier: GalleryImageTier.thumbnail,
        targetDecodeWidth: 320,
      );

      final request2 = GalleryImageRequest(
        sourceId: 'test',
        url: 'https://example.com/image.jpg',
        tier: GalleryImageTier.thumbnail,
        targetDecodeWidth: 320,
        headers: {
          'Custom': 'Header',
        }, // Different headers shouldn't affect equality
      );

      final request3 = GalleryImageRequest(
        sourceId: 'test',
        url: 'https://example.com/image.jpg',
        tier: GalleryImageTier.sample, // Different tier
        targetDecodeWidth: 320,
      );

      expect(request1, equals(request2));
      expect(request1.hashCode, equals(request2.hashCode));
      expect(request1, isNot(equals(request3)));
    });

    test(
      'source URLs retain their transport identity and header contracts',
      () {
        const cases = <(GallerySourceId, String)>[
          (GallerySourceId.danbooru, 'https://cdn.donmai.us/a.jpg'),
          (GallerySourceId.safebooru, 'https://safebooru.org/a.jpg'),
          (GallerySourceId.gelbooru, 'https://img4.gelbooru.com/a.jpg'),
          (GallerySourceId.quickTagCloud, 'https://codex.example/a.webp'),
        ];
        for (final (sourceId, url) in cases) {
          final request = GalleryImageRequest.forUrl(
            sourceId: sourceId,
            url: url,
            tier: GalleryImageTier.thumbnail,
            targetDecodeWidth: 320,
          );
          expect(request.sourceId, sourceId);
          expect(request.url, url);
          if (sourceId == GallerySourceId.gelbooru) {
            expect(request.headers['Referer'], 'https://gelbooru.com/');
            expect(request.cacheKey, 'gelbooru-image-v2:$url');
          } else {
            expect(request.headers, isEmpty);
            expect(request.cacheKey, isNull);
          }
        }

        final aiTag = GalleryImageRequest.forUrl(
          sourceId: GallerySourceId.aiTag,
          url: 'https://ai-img.10118899.xyz/NAI/1/work.webp',
          tier: GalleryImageTier.thumbnail,
          targetDecodeWidth: 320,
        );
        expect(aiTag.headers['Referer'], 'https://aitag.win/');
        expect(aiTag.headers['Accept'], contains('image/webp'));
        expect(aiTag.cacheKey, isNull);
      },
    );

    test('creates Gelbooru requests with correct headers and cache keys', () {
      const gelbooruUrl =
          'https://img4.gelbooru.com/thumbnails/51/d1/thumbnail_image.jpg';

      final request = GalleryImageRequest.gelbooru(
        url: gelbooruUrl,
        tier: GalleryImageTier.thumbnail,
        targetDecodeWidth: 320,
      );

      expect(request.sourceId, 'gelbooru');
      expect(request.url, gelbooruUrl);
      expect(request.cacheKey, 'gelbooru-image-v2:$gelbooruUrl');
      expect(request.headers['Referer'], 'https://gelbooru.com/');
      expect(request.headers['Cookie'], 'fringeBenefits=yup');
      expect(request.headers['User-Agent'], contains('Mozilla/5.0'));
      expect(request.headers['Accept'], contains('image/'));
      expect(request.tier, GalleryImageTier.thumbnail);
      expect(request.targetDecodeWidth, 320);
    });

    test(
      'Gelbooru requests use empty headers and null cache key for non-Gelbooru URLs',
      () {
        const nonGelbooruUrl = 'https://cdn.donmai.us/sample/test.jpg';

        final request = GalleryImageRequest.gelbooru(
          url: nonGelbooruUrl,
          tier: GalleryImageTier.sample,
        );

        expect(request.sourceId, 'gelbooru');
        expect(request.url, nonGelbooruUrl);
        expect(request.cacheKey, isNull);
        expect(request.headers, isEmpty);
        expect(request.tier, GalleryImageTier.sample);
      },
    );

    test('known video URLs are rejected before image provider creation', () {
      final generic = GalleryImageRequest.forUrl(
        url: 'https://example.com/clip.WEBM?token=secret',
        tier: GalleryImageTier.thumbnail,
        targetDecodeWidth: 320,
      );
      final gelbooru = GalleryImageRequest.gelbooru(
        url: 'https://img4.gelbooru.com/video/clip.mp4',
        tier: GalleryImageTier.sample,
      );

      expect(generic.url, isEmpty);
      expect(generic.cacheKey, isNull);
      expect(generic.headers, isEmpty);
      expect(gelbooru.url, isEmpty);
      expect(gelbooru.cacheKey, isNull);
      expect(gelbooru.headers, isEmpty);
    });

    test('toString returns readable representation', () {
      final request = GalleryImageRequest(
        sourceId: 'test',
        url: 'https://example.com/image.jpg',
        tier: GalleryImageTier.thumbnail,
        targetDecodeWidth: 320,
      );

      expect(
        request.toString(),
        'GalleryImageRequest(source=test, tier=thumbnail, targetWidth=320)',
      );
    });
  });
}

class _NoopCacheManager implements BaseCacheManager {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
