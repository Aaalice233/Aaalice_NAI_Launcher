import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

import '../../../tool/database/build_cooccurrence_only.dart'
    as cooccurrence_builder;

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'cooccurrence_builder_test_',
    );
  });

  tearDown(() async {
    if (await temporaryDirectory.exists()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test(
    'builds symmetric compact data and reproduces identical hashes',
    () async {
      final fixture = await _writeFixture(
        temporaryDirectory,
        'tag_a,tag_b,count\n'
        'Alpha,Beta,10.0\n'
        'alpha,"tag,with,comma",7\n'
        'self,self,3\n',
        recordCount: 3,
      );

      await _runBuilder(fixture, updateLock: true);
      final lockAfterFirst =
          jsonDecode(await fixture.lock.readAsString()) as Map<String, dynamic>;
      final outputAfterFirst = Map<String, dynamic>.from(
        lockAfterFirst['output'] as Map,
      );

      final database = sqlite3.open(
        p.join(fixture.outputDirectory.path, 'cooccurrence-v2.db'),
        mode: OpenMode.readOnly,
      );
      try {
        expect(
          database
              .select('SELECT name FROM tags ORDER BY id')
              .map((row) => row['name']),
          ['alpha', 'beta', 'tag,with,comma', 'self'],
        );
        expect(
          database.select('''
          SELECT target.name, edge.count
          FROM tags source
          JOIN edges edge ON edge.source_tag_id = source.id
          JOIN tags target ON target.id = edge.target_tag_id
          WHERE source.name = 'beta'
        ''').single,
          containsPair('name', 'alpha'),
        );
        expect(
          database.select('SELECT COUNT(*) value FROM edges').single['value'],
          5,
        );
        expect(
          database
              .select(
                "SELECT value FROM metadata WHERE key='self_relation_count'",
              )
              .single['value'],
          '1',
        );
        expect(
          database
              .select(
                "SELECT value FROM metadata WHERE key='source_pair_count'",
              )
              .single['value'],
          '3',
        );
      } finally {
        database.dispose();
      }

      await _runBuilder(fixture);
      final lockAfterSecond =
          jsonDecode(await fixture.lock.readAsString()) as Map<String, dynamic>;
      expect(lockAfterSecond['output'], outputAfterFirst);
    },
  );

  test('rejects malformed counts and removes partial database', () async {
    final fixture = await _writeFixture(
      temporaryDirectory,
      'tag_a,tag_b,count\na,b,1.5\n',
      recordCount: 1,
    );

    await expectLater(
      _runBuilder(fixture, updateLock: true),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('positive integer'),
        ),
      ),
    );
    expect(
      await File(
        p.join(fixture.outputDirectory.path, 'cooccurrence-v2.db.building'),
      ).exists(),
      isFalse,
    );
  });

  test('rejects duplicate unordered relations after normalization', () async {
    final fixture = await _writeFixture(
      temporaryDirectory,
      'tag_a,tag_b,count\nAlpha,beta,10\nBETA,alpha,9\n',
      recordCount: 2,
    );

    await expectLater(
      _runBuilder(fixture, updateLock: true),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          contains('Duplicate unordered relation'),
        ),
      ),
    );
  });
}

Future<_Fixture> _writeFixture(
  Directory root,
  String csv, {
  required int recordCount,
}) async {
  final input = File(p.join(root.path, 'source.csv'));
  await input.writeAsString(csv, encoding: utf8);
  final sourceBytes = await input.readAsBytes();
  final lock = File(p.join(root.path, 'lock.json'));
  final outputDirectory = Directory(p.join(root.path, 'output'));
  final clientManifest = File(p.join(root.path, 'client-manifest.json'));
  await lock.writeAsString(
    jsonEncode({
      'schemaVersion': 2,
      'toolVersion': 2,
      'dataVersion': 'fixture-v2',
      'source': {
        'dataset': 'fixture/test',
        'revision': '0123456789012345678901234567890123456789',
        'file': 'source.csv',
        'url':
            'https://huggingface.co/datasets/fixture/test/resolve/'
            '0123456789012345678901234567890123456789/source.csv',
        'sha256': sha256.convert(sourceBytes).toString(),
        'size': sourceBytes.length,
        'recordCount': recordCount,
      },
      'release': {
        'tag': 'autocomplete-data-fixture-v2',
        'asset': 'cooccurrence-v2.db.gz',
        'url':
            'https://github.com/Aaalice233/Aaalice_NAI_Launcher/releases/'
            'download/autocomplete-data-fixture-v2/cooccurrence-v2.db.gz',
        'prerelease': true,
        'makeLatest': false,
      },
      'limits': {'databaseSize': 10485760, 'archiveSize': 10485760},
      'output': {
        'databaseSha256': '',
        'databaseSize': 0,
        'archiveSha256': '',
        'archiveSize': 0,
        'tagCount': 0,
        'pairCount': 0,
        'selfRelationCount': 0,
        'directedEdgeCount': 0,
      },
    }),
    encoding: utf8,
  );
  return _Fixture(
    input: input,
    lock: lock,
    outputDirectory: outputDirectory,
    clientManifest: clientManifest,
  );
}

Future<void> _runBuilder(_Fixture fixture, {bool updateLock = false}) {
  return cooccurrence_builder.buildCooccurrenceDataPack([
    '--input=${fixture.input.path}',
    '--lock=${fixture.lock.path}',
    '--output-dir=${fixture.outputDirectory.path}',
    '--client-manifest=${fixture.clientManifest.path}',
    if (updateLock) '--update-lock',
  ]);
}

class _Fixture {
  const _Fixture({
    required this.input,
    required this.lock,
    required this.outputDirectory,
    required this.clientManifest,
  });

  final File input;
  final File lock;
  final Directory outputDirectory;
  final File clientManifest;
}
