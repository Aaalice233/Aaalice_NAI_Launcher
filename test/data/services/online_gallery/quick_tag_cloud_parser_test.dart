import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/services/online_gallery/quick_tag_cloud_parser.dart';

void main() {
  group('QuickTagCloudParser bootstrap', () {
    test('parses schema v1 config, pointer, and manifest metadata', () {
      final config = QuickTagCloudParser.parseDataSource(const {
        'schemaVersion': 1,
        'baseUrl': 'https://assets.example/data/',
        'pointer': 'current.json',
      });
      const fileHash =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      final contentHash = QuickTagCloudParser.manifestContentHash(const [
        QuickTagCloudManifestFile(
          path: 'book.json',
          size: 12,
          sha256: fileHash,
        ),
      ]);
      final release = 'r-${contentHash.substring(0, 20)}';
      final pointer = QuickTagCloudParser.parseReleasePointer({
        'schemaVersion': 1,
        'release': release,
        'manifest': 'releases/$release/manifest.json',
        'contentHash': contentHash,
      });
      final manifest = QuickTagCloudParser.parseManifest(
        {
          'schemaVersion': 1,
          'release': release,
          'contentHash': contentHash,
          'files': {
            'book.json': {'size': 12, 'sha256': fileHash},
          },
        },
        expectedRelease: pointer.release,
        expectedContentHash: pointer.contentHash,
      );

      expect(config.baseUrl.toString(), 'https://assets.example/data');
      expect(config.pointer, 'current.json');
      expect(manifest.requireFile('book.json').size, 12);
    });

    test('rejects unsupported schemas, unsafe paths, and malformed releases', () {
      expect(
        () => QuickTagCloudParser.parseDataSource(const {
          'schemaVersion': 2,
          'baseUrl': 'https://assets.example/data',
        }),
        throwsFormatException,
      );
      expect(
        () => QuickTagCloudParser.parseReleasePointer(const {
          'schemaVersion': 1,
          'release': 'latest',
        }),
        throwsFormatException,
      );
      expect(
        () => QuickTagCloudParser.parseReleasePointer(const {
          'schemaVersion': 1,
          'release': 'r-0123456789abcdefabcd',
          'contentHash':
              'ffffffffffffffffffff00000000000000000000000000000000000000000000',
        }),
        throwsFormatException,
      );
      expect(
        () => QuickTagCloudParser.parseReleasePointer(const {
          'schemaVersion': 1,
          'release': 'r-0123456789abcdefabcd',
          'manifest': 'releases/r-ffffffffffffffffffff/manifest.json',
          'contentHash':
              '0123456789abcdefabcd00000000000000000000000000000000000000000000',
        }),
        throwsFormatException,
      );
      expect(
        () => QuickTagCloudParser.parseManifest(const {
          'schemaVersion': 1,
          'release': 'r-0123456789abcdefabcd',
          'contentHash':
              '0123456789abcdefabcd00000000000000000000000000000000000000000000',
          'files': {
            'book.json': {
              'size': 1,
              'sha256':
                  'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            },
          },
        }),
        throwsFormatException,
      );
      for (final path in [
        '../book.json',
        'nested//book.json',
        r'nested\book.json',
        'C:book.json',
        'book?.json',
        'book#.json',
      ]) {
        expect(
          () => QuickTagCloudParser.cleanRelativePath(path),
          throwsFormatException,
          reason: path,
        );
      }
    });
  });

  group('QuickTagCloudParser codex normalization', () {
    test('preserves string and structured attribution forms', () {
      final meta = QuickTagCloudParser.parseCodexes(const [
        {
          'id': 'book',
          'contributors': [
            'Alice',
            {'name': 'Bob', 'role': 'Editor'},
          ],
          'links': [
            'https://example.test/source',
            {'label': 'Home', 'url': 'https://example.test'},
            {'label': 'Unsafe', 'url': 'file:///etc/passwd'},
            {'label': 'Script', 'url': 'javascript:alert(1)'},
          ],
        },
      ]).single;

      expect(meta.contributors.map((item) => item.name), ['Alice', 'Bob']);
      expect(meta.contributors.last.role, 'Editor');
      expect(meta.links, hasLength(2));
      expect(meta.links.first.url, 'https://example.test/source');
      expect(meta.links.last.label, 'Home');
    });

    test('normalizes entries, images, prompts, dimensions, and raw tags', () {
      final meta = QuickTagCloudParser.parseCodexes(const [
        {'id': 'book', 'title': 'Book title', 'version': '2', 'nsfw': true},
      ]).single;
      final codex = QuickTagCloudParser.parseCodex({
        'id': 'book',
        'title': 'Ignored title',
        'entries': [
          {
            'title': 'Entry',
            'author': 'Entry Author',
            'credit': 'Image Credit',
            'path': ['R18G', '重口分类'],
            'rawTags': 'positive tags',
            'negative': 'bad',
            'note': 'note',
            'level': 'R18G',
            'isNew': true,
            'updateBatches': ['v1', 'v1', 2, ''],
            'characterPrompts': [
              'first prompt',
              {'positive': 'second prompt', 'uc': 'second negative'},
              {'prompt': '', 'negative': ''},
            ],
            'image': 'primary.jpg',
            'original': 'primary.png',
            'images': [
              {'path': 'secondary.jpg', 'rawTags': 'secondary raw'},
              {'path': 'primary.jpg', 'rawTag': 'primary raw'},
              {'path': 'secondary.jpg'},
            ],
            'assetRev': 'revision',
            'assetCodexId': 'shared-assets',
            'imageWidth': 832,
            'imageHeight': 1216,
          },
        ],
      }, meta);
      final entry = codex.entries.single;

      expect(codex.title, 'Book title');
      expect(codex.nsfw, isTrue);
      expect(entry.id, startsWith('generated-'));
      expect(entry.author, 'Entry Author');
      expect(entry.credit, 'Image Credit');
      expect(entry.tags, 'positive tags');
      expect(entry.rating, 'r18g');
      expect(entry.updateBatches, ['v1', '2']);
      expect(entry.characterPrompts, hasLength(2));
      expect(entry.characterPrompts.first.label, 'char1');
      expect(entry.images.map((image) => image.path), [
        'primary.jpg',
        'secondary.jpg',
      ]);
      expect(entry.images.first.original, 'primary.png');
      expect(entry.images.first.hasOriginal, isTrue);
      expect(entry.images.first.rawTag, 'primary raw');
      expect(entry.images.last.rawTag, 'secondary raw');
      expect(entry.assetRev, 'revision');
      expect(entry.assetCodexId, 'shared-assets');
      expect(entry.dimensions.width, 832);
      expect(entry.dimensions.height, 1216);
      expect(entry.rawTag, 'positive tags');
    });

    test(
      'generated entry ids survive reordering and duplicates are rejected',
      () {
        final meta = QuickTagCloudParser.parseCodexes(const [
          {'id': 'book', 'title': 'Book'},
        ]).single;
        final first = QuickTagCloudParser.parseCodex(const {
          'id': 'book',
          'entries': [
            {'title': 'Alpha', 'tags': '1girl'},
            {'title': 'Beta', 'tags': 'solo'},
          ],
        }, meta);
        final reordered = QuickTagCloudParser.parseCodex(const {
          'id': 'book',
          'entries': [
            {'title': 'Beta', 'tags': 'solo'},
            {'title': 'Alpha', 'tags': '1girl'},
          ],
        }, meta);

        expect(
          first.entries.map((entry) => entry.id).toSet(),
          reordered.entries.map((entry) => entry.id).toSet(),
        );
        expect(
          () => QuickTagCloudParser.parseCodex(const {
            'id': 'book',
            'entries': [
              {'id': 'same'},
              {'id': 'same'},
            ],
          }, meta),
          throwsFormatException,
        );
      },
    );

    test('live external metadata wins without escalating capabilities', () {
      final meta = QuickTagCloudParser.parseCodexes(const [
        {
          'id': 'external',
          'title': 'Published title',
          'author': 'Published author',
          'entryCount': 351,
          'imagedCount': 351,
          'hasOriginal': false,
          'dataUrl': 'https://external.example/book.json',
          'links': [
            {'label': 'Published source', 'url': 'https://external.example'},
          ],
        },
      ]).single;
      final codex = QuickTagCloudParser.parseCodex(
        const {
          'id': 'external-live-id',
          'title': 'Live title',
          'author': 'Live author',
          'entryCount': 1,
          'imagedCount': 1,
          'hasOriginal': true,
          'entries': [
            {
              'id': 'live-1',
              'image': 'live.png',
              'original': 'live-original.png',
            },
          ],
        },
        meta,
        loadSource: QuickTagCloudCodexLoadSource.external,
      );

      expect(codex.id, 'external');
      expect(codex.title, 'Live title');
      expect(codex.author, 'Live author');
      expect(codex.entryCount, 1);
      expect(codex.imagedCount, 1);
      expect(codex.hasOriginal, isFalse);
      expect(codex.metadata!.links.single.url, 'https://external.example');
    });

    test('fallback mode clears external asset settings', () {
      final meta = QuickTagCloudParser.parseCodexes(const [
        {
          'id': 'external',
          'title': 'External',
          'version': 'remote',
          'fallbackVersion': 'snapshot',
          'dataUrl': 'https://external.example/book.json',
          'fallbackDataUrl': 'data/external.json',
          'assetBaseUrl': 'https://external.example',
          'assetPathMode': 'relative',
        },
      ]).single;
      final codex = QuickTagCloudParser.parseCodex(
        const {'id': 'external', 'entries': []},
        meta,
        loadSource: QuickTagCloudCodexLoadSource.fallback,
      );

      expect(codex.loadSource, QuickTagCloudCodexLoadSource.fallback);
      expect(codex.version, 'snapshot');
      expect(codex.dataUrl, isEmpty);
      expect(codex.sourceDataUrl, meta.dataUrl);
      expect(codex.assetBaseUrl, isEmpty);
      expect(codex.assetPathMode, 'codex');
    });
  });
}
