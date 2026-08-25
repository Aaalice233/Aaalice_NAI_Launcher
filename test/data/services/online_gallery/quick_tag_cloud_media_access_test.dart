import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/services/online_gallery/quick_tag_cloud_access.dart';
import 'package:nai_launcher/data/services/online_gallery/quick_tag_cloud_media_resolver.dart';
import 'package:nai_launcher/data/services/online_gallery/quick_tag_cloud_parser.dart';

void main() {
  group('QuickTagCloudMediaResolver', () {
    test('mirrors codex asset paths, encoding, and assetRev query strings', () {
      final codex = _codex({
        'image': 'folder/a b.jpg',
        'original': 'folder/a b.png',
        'assetRev': 'rev 1',
      });
      final entry = codex.entries.single;
      const resolver = QuickTagCloudMediaResolver(
        media: QuickTagCloudMediaConfig(
          baseUrl: 'https://assets.example',
          imagePrefix: 'images',
          originalPrefix: 'originals',
        ),
      );

      expect(
        resolver.thumbUrl(entry, codex),
        'https://assets.example/images/book/folder/a%20b.jpg?v=rev%201',
      );
      expect(
        resolver.originalUrl(entry, codex),
        'https://assets.example/originals/book/folder/a%20b.png?v=rev%201',
      );
    });

    test('preserves encoded paths, query strings, and fragments', () {
      final codex = _codex(
        {
          'image': 'folder/already%20encoded/a b.jpg?format=webp#preview',
          'original':
              'https://cdn.example/already%20encoded/full image.png?download=1#asset',
          'assetRev': 'abc',
        },
        dataUrl: 'https://external.example/book.json',
        assetBaseUrl: 'https://external.example/assets',
        assetPathMode: 'relative',
      );
      final entry = codex.entries.single;
      const resolver = QuickTagCloudMediaResolver(
        media: QuickTagCloudMediaConfig(baseUrl: 'https://assets.example'),
      );

      expect(
        resolver.thumbUrl(entry, codex),
        'https://external.example/assets/folder/already%20encoded/a%20b.jpg?format=webp&v=abc#preview',
      );
      expect(
        resolver.originalUrl(entry, codex),
        'https://cdn.example/already%20encoded/full%20image.png?download=1&v=abc#asset',
      );
    });

    test('image item original falls back to its thumbnail path', () {
      final codex = _codex({
        'images': [
          {'path': 'secondary.jpg'},
        ],
        'assetRev': '1',
      });
      final entry = codex.entries.single;
      final item = entry.images.single;
      const resolver = QuickTagCloudMediaResolver(
        media: QuickTagCloudMediaConfig(baseUrl: 'https://assets.example'),
      );

      expect(item.hasOriginal, isFalse);
      expect(
        resolver.imageItemUrl(
          QuickTagCloudMediaKind.original,
          entry,
          item,
          codex,
        ),
        'https://assets.example/originals/book/secondary.jpg?v=1',
      );
    });
  });

  group('QuickTagCloudAccess', () {
    test('uses book nsfw and upstream rating/path rules', () {
      final meta = QuickTagCloudParser.parseCodexes(const [
        {'id': 'book', 'title': 'Book', 'nsfw': true},
      ]).single;
      final safe = _codex({'rating': 'safe'}).entries.single;
      final restricted = _codex({'rating': 'restricted'}).entries.single;
      final pathOnly = _codex({
        'rating': 'safe',
        'path': ['NSFW', 'R18G heavy'],
      }).entries.single;
      final heavyChinese = _codex({
        'path': ['普通', '重口内容'],
      }).entries.single;

      expect(QuickTagCloudAccess.isNsfwCodex(meta), isTrue);
      expect(QuickTagCloudAccess.isCodexLocked(meta, allowNsfw: false), isTrue);
      expect(QuickTagCloudAccess.isEntryNsfw(restricted), isTrue);
      expect(QuickTagCloudAccess.isEntryNsfw(pathOnly), isTrue);
      expect(QuickTagCloudAccess.isR18gEntry(pathOnly), isTrue);
      expect(QuickTagCloudAccess.isR18gEntry(heavyChinese), isTrue);
      expect(
        QuickTagCloudAccess.isEntryAccessBlocked(
          pathOnly,
          allowNsfw: true,
          allowR18g: false,
        ),
        isTrue,
      );
      expect(
        QuickTagCloudAccess.isEntryAccessBlocked(
          restricted,
          allowNsfw: false,
          allowR18g: true,
        ),
        isTrue,
      );
      expect(QuickTagCloudAccess.isNsfwPathSegment('NSFW'), isTrue);
      expect(QuickTagCloudAccess.isNsfwPathSegment('my-nsfw'), isFalse);
      expect(QuickTagCloudAccess.galleryRating(safe), 'g');
      expect(QuickTagCloudAccess.galleryRating(restricted), 'q');
      expect(QuickTagCloudAccess.galleryRating(pathOnly), 'e');
      expect(
        QuickTagCloudAccess.matchesGalleryRatings(
          safe,
          codex: null,
          selectedRatings: const {'s'},
        ),
        isTrue,
      );
      expect(
        QuickTagCloudAccess.matchesGalleryRatings(
          restricted,
          codex: null,
          selectedRatings: const {'g'},
        ),
        isFalse,
      );
    });
  });
}

QuickTagCloudCodex _codex(
  Map<String, dynamic> entry, {
  String dataUrl = '',
  String assetBaseUrl = '',
  String assetPathMode = 'codex',
}) {
  final meta = QuickTagCloudParser.parseCodexes([
    {
      'id': 'book',
      'title': 'Book',
      'dataUrl': dataUrl,
      'assetBaseUrl': assetBaseUrl,
      'assetPathMode': assetPathMode,
    },
  ]).single;
  return QuickTagCloudParser.parseCodex({
    'id': 'book',
    'entries': [entry],
  }, meta);
}
