import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../tool/tag_catalog/build_tag_catalog.dart' as builder;

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('tag_catalog_builder_test_');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('filters non-Danbooru categories and deduplicates aliases', () async {
    final input = File('${temp.path}/tags.csv');
    await input.writeAsString(
      [
        'tag_name,category,post_count,aliases',
        'blue_eyes,0,100,"aqua_eyes,aqua_eyes,blue_eyes"',
        'artist_name,1,20,"artist_alias"',
        'e621_only,7,999,"furry_alias"',
        'invalid_category,nope,10,"alias"',
        ',0,10,"empty"',
        'bad,0,not_a_number,""',
      ].join('\n'),
    );
    final hash = await sha256.bind(input.openRead()).first;
    final lock = File('${temp.path}/lock.json');
    await lock.writeAsString(
      jsonEncode({
        'commit': '1234567890abcdef',
        'url': 'https://example.invalid/tags.csv',
        'sha256': hash.toString(),
      }),
    );
    final manifest = File('${temp.path}/manifest.json');
    await manifest.writeAsString(
      jsonEncode({'databases': <String, dynamic>{}}),
    );
    final output = '${temp.path}/catalog.db';

    await builder.main([
      '--input=${input.path}',
      '--output=$output',
      '--lock=${lock.path}',
      '--manifest=${manifest.path}',
    ]);

    final db = sqlite3.open(output, mode: OpenMode.readOnly);
    try {
      expect(
        db
            .select('SELECT name FROM tags ORDER BY name')
            .map((row) => row['name']),
        ['artist_name', 'blue_eyes'],
      );
      expect(
        db
            .select('SELECT alias FROM aliases ORDER BY alias')
            .map((row) => row['alias']),
        ['aqua_eyes', 'artist_alias'],
      );
      expect(db.select('PRAGMA quick_check').first.values.first, 'ok');
      expect(
        db
            .select("SELECT value FROM metadata WHERE key='source_sha256'")
            .single['value'],
        hash.toString(),
      );
    } finally {
      db.dispose();
    }
  });

  test('rejects a source whose hash does not match the lock', () async {
    final input = File('${temp.path}/tags.csv')
      ..writeAsStringSync('tag,0,1,""');
    final lock = File('${temp.path}/lock.json')
      ..writeAsStringSync(
        jsonEncode({
          'commit': '1234567890abcdef',
          'url': 'https://example.invalid/tags.csv',
          'sha256': List.filled(64, '0').join(),
        }),
      );
    final manifest = File('${temp.path}/manifest.json')
      ..writeAsStringSync(jsonEncode({'databases': <String, dynamic>{}}));

    expect(
      () => builder.main([
        '--input=${input.path}',
        '--output=${temp.path}/catalog.db',
        '--lock=${lock.path}',
        '--manifest=${manifest.path}',
      ]),
      throwsStateError,
    );
  });
}
