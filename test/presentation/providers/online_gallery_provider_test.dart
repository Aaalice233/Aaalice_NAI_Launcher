import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/online_gallery/gelbooru_post_parser.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_provider.dart';

void main() {
  group('Gelbooru post parsing', () {
    test('normalizes API rating and opens the Gelbooru post page', () {
      final posts = parsePostsInIsolate({
        'source': 'gelbooru',
        'rawList': [
          {
            'id': 14416915,
            'score': 12,
            'source': 'https://example.test/source',
            'md5': '51d1078614b5849302fd803294a9abdf',
            'rating': 'general',
            'width': 826,
            'height': 826,
            'tags': 'solo pokemon',
            'file_url':
                'https://img4.gelbooru.com/images/51/d1/51d1078614b5849302fd803294a9abdf.jpeg',
            'preview_url':
                'https://img4.gelbooru.com/thumbnails/51/d1/thumbnail_51d1078614b5849302fd803294a9abdf.jpg',
          },
        ],
      });

      expect(posts, hasLength(1));
      expect(posts.single.rating, 'g');
      expect(
        posts.single.postUrl,
        'https://gelbooru.com/index.php?page=post&s=view&id=14416915',
      );
    });

    test('parses thumbnail posts from Gelbooru HTML fallback', () {
      const html = '''
<div class="thumbnail-container">
  <article class="thumbnail-preview">
    <a id="p14416915" href="https://gelbooru.com/index.php?page=post&amp;s=view&amp;id=14416915&amp;tags=rating%3Ageneral">
      <img src="https://img4.gelbooru.com/thumbnails/51/d1/thumbnail_51d1078614b5849302fd803294a9abdf.jpg" title="solo pokemon score:12 rating:general" alt="Rule 34 | solo, pokemon" />
    </a>
  </article>
  <article class="thumbnail-preview">
    <a id="p14416910" href="https://gelbooru.com/index.php?page=post&amp;s=view&amp;id=14416910&amp;tags=rating%3Aquestionable">
      <img src="https://img4.gelbooru.com/thumbnails/70/d9/thumbnail_70d9cf32878fc8ab8f9c451bbde38c07.jpg" title="bang_dream!_it&amp;#039;s_mygo!!!!! score:-1 rating:questionable" />
    </a>
  </article>
</div>
''';

      final posts = parseGelbooruHtmlPosts(html);

      expect(posts, hasLength(2));
      expect(posts.first.id, 14416915);
      expect(posts.first.previewUrl, contains('thumbnail_51d107'));
      expect(posts.first.rating, 'g');
      expect(posts.first.score, 12);
      expect(posts.first.tags, ['solo', 'pokemon']);
      expect(posts.last.rating, 'q');
      expect(posts.last.score, -1);
      expect(posts.last.tags, ["bang_dream!_it's_mygo!!!!!"]);
    });

    test(
      'classifies Gelbooru HTML video and animated posts from title tags',
      () {
        const html = '''
<article class="thumbnail-preview">
  <a id="p14416916" href="https://gelbooru.com/index.php?page=post&amp;s=view&amp;id=14416916">
    <img src="https://img4.gelbooru.com/thumbnails/aa/bb/thumbnail_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.jpg" title="video solo score:1 rating:general" />
  </a>
</article>
<article class="thumbnail-preview">
  <a id="p14416917" href="https://gelbooru.com/index.php?page=post&amp;s=view&amp;id=14416917">
    <img src="https://img4.gelbooru.com/thumbnails/cc/dd/thumbnail_bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb.jpg" title="animated blinking score:2 rating:sensitive" />
  </a>
</article>
''';

        final posts = parseGelbooruHtmlPosts(html);

        expect(posts, hasLength(2));
        expect(posts.first.fileExt, 'mp4');
        expect(posts.first.isVideo, isTrue);
        expect(posts.last.fileExt, 'gif');
        expect(posts.last.isAnimated, isTrue);
      },
    );

    test('keeps parsing when Gelbooru title has invalid html entity', () {
      const html = '''
<article class="thumbnail-preview">
  <a id="p14416918" href="https://gelbooru.com/index.php?page=post&amp;s=view&amp;id=14416918">
    <img src="https://img4.gelbooru.com/thumbnails/ee/ff/thumbnail_cccccccccccccccccccccccccccccccc.jpg" title="solo &#xFFFFFFFF; score:3 rating:questionable" />
  </a>
</article>
''';

      final posts = parseGelbooruHtmlPosts(html);

      expect(posts, hasLength(1));
      expect(posts.single.id, 14416918);
      expect(posts.single.tags, contains('solo'));
      expect(posts.single.score, 3);
      expect(posts.single.rating, 'q');
    });

    test('decodes dimensions from Gelbooru JPEG thumbnails', () {
      final bytes = _minimalJpegBytes(width: 320, height: 180);

      final size = decodeJpegDimensions(bytes);

      expect(size, isNotNull);
      expect(size!.width, 320);
      expect(size.height, 180);
    });

    test('ignores non-JPEG or truncated thumbnail bytes', () {
      expect(
        decodeJpegDimensions(Uint8List.fromList('<html>'.codeUnits)),
        null,
      );
      expect(
        decodeJpegDimensions(Uint8List.fromList([0xff, 0xd8, 0xff])),
        null,
      );
    });
  });
}

Uint8List _minimalJpegBytes({required int width, required int height}) {
  return Uint8List.fromList([
    0xff, 0xd8, // SOI
    0xff, 0xe0, 0x00, 0x04, 0x00, 0x00, // APP0 segment
    0xff, 0xc0, 0x00, 0x11, 0x08, // SOF0, length, precision
    (height >> 8) & 0xff, height & 0xff,
    (width >> 8) & 0xff, width & 0xff,
    0x03, // components
    0x01, 0x11, 0x00,
    0x02, 0x11, 0x00,
    0x03, 0x11, 0x00,
    0xff, 0xd9, // EOI
  ]);
}
