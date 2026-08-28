import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/skill_archive_service.dart';

void main() {
  late Directory temp;
  const service = SkillArchiveService();

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('agent-skill-archive-');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  test('exports and imports a selected Skill with nested assets', () async {
    final source = Directory('${temp.path}/source/demo');
    await source.create(recursive: true);
    final manifest = File('${source.path}/SKILL.md');
    await manifest.writeAsString(_skill('demo', 'Demo skill'));
    await Directory('${source.path}/references').create();
    await File('${source.path}/references/guide.txt').writeAsString('guide');

    final bytes = await service.exportSkills([
      (name: 'demo', manifest: manifest),
    ]);
    final target = Directory('${temp.path}/target');
    final preview = await service.previewImport(
      bytes: bytes,
      targetDirectory: target,
    );
    expect(preview.items.single.name, 'demo');
    expect(preview.items.single.fileCount, 2);

    await service.install(
      bytes: bytes,
      targetDirectory: target,
      replaceSkillNames: const {},
    );
    expect(
      await File('${target.path}/demo/SKILL.md').readAsString(),
      contains('Demo skill'),
    );
    expect(
      await File('${target.path}/demo/references/guide.txt').readAsString(),
      'guide',
    );
  });

  test(
    'exports a direct manifest without including neighboring Skills',
    () async {
      final source = Directory('${temp.path}/source');
      await source.create();
      final manifest = File('${source.path}/solo.md');
      await manifest.writeAsString(_skill('solo', 'Solo skill'));
      await File(
        '${source.path}/neighbor.md',
      ).writeAsString(_skill('neighbor', 'Neighbor skill'));

      final bytes = await service.exportSkills([
        (name: 'solo', manifest: manifest),
      ]);
      final archive = ZipDecoder().decodeBytes(bytes);

      expect(archive.files.map((file) => file.name), ['solo/SKILL.md']);
    },
  );

  test(
    'rejects traversal, symbolic links, corruption, and expansion bombs',
    () {
      final traversal = _zip([
        ArchiveFile.string('../escape/SKILL.md', _skill('escape', 'Escape')),
      ]);
      expect(
        () => service.previewImport(
          bytes: traversal,
          targetDirectory: Directory('${temp.path}/target'),
        ),
        throwsFormatException,
      );

      final symbolic = _markZipEntryAsSymbolicLink(
        _zip([ArchiveFile.string('demo/SKILL.md', _skill('demo', 'Demo'))]),
      );
      expect(
        () => service.previewImport(
          bytes: symbolic,
          targetDirectory: Directory('${temp.path}/target'),
        ),
        throwsFormatException,
      );

      expect(
        () => service.previewImport(
          bytes: Uint8List.fromList(utf8.encode('not a zip')),
          targetDirectory: Directory('${temp.path}/target'),
        ),
        throwsFormatException,
      );

      const constrained = SkillArchiveService(
        expandedBytesLimit: 32,
        fileBytesLimit: 64,
      );
      final oversized = _claimZipEntryExpandedSize(
        _zip([ArchiveFile.string('demo/SKILL.md', _skill('demo', 'Demo'))]),
        10 * 1024 * 1024,
      );
      expect(
        () => constrained.previewImport(
          bytes: oversized,
          targetDirectory: Directory('${temp.path}/target'),
        ),
        throwsFormatException,
      );

      final forgedSmall = _claimZipEntryExpandedSize(
        _zip([ArchiveFile.string('demo/SKILL.md', _skill('demo', 'Demo'))]),
        16,
      );
      expect(
        () => constrained.previewImport(
          bytes: forgedSmall,
          targetDirectory: Directory('${temp.path}/target'),
        ),
        throwsFormatException,
      );

      final colliding = _zip([
        ArchiveFile.string('collision/SKILL.md', _skill('collision', 'Demo')),
        ArchiveFile.string('collision/assets', 'file'),
        ArchiveFile.string('collision/assets/reference.txt', 'nested'),
      ]);
      expect(
        () => service.previewImport(
          bytes: colliding,
          targetDirectory: Directory('${temp.path}/target'),
        ),
        throwsFormatException,
      );
    },
  );

  test('reports every entity conflict before installing', () async {
    final target = Directory('${temp.path}/target');
    final existing = Directory('${target.path}/a');
    await existing.create(recursive: true);
    await File(
      '${existing.path}/SKILL.md',
    ).writeAsString(_skill('a', 'Original A'));
    await File('${target.path}/b').writeAsString('blocks directory install');
    final bytes = _zip([
      ArchiveFile.string('a/SKILL.md', _skill('a', 'Replacement A')),
      ArchiveFile.string('b/SKILL.md', _skill('b', 'Skill B')),
    ]);

    final preview = await service.previewImport(
      bytes: bytes,
      targetDirectory: target,
    );
    expect(preview.items.every((item) => item.conflicts), isTrue);
    expect(
      preview.items.firstWhere((item) => item.name == 'a').canReplace,
      isTrue,
    );
    expect(
      preview.items.firstWhere((item) => item.name == 'b').canReplace,
      isFalse,
    );
    await expectLater(
      service.install(
        bytes: bytes,
        targetDirectory: target,
        replaceSkillNames: const {'a'},
      ),
      throwsFormatException,
    );

    expect(
      await File('${target.path}/a/SKILL.md').readAsString(),
      contains('Original A'),
    );
    expect(
      await File('${target.path}/b').readAsString(),
      'blocks directory install',
    );
    expect(
      target.listSync().whereType<Directory>().any(
        (directory) => directory.path.contains('.skill-import-'),
      ),
      isFalse,
    );
  });

  test('rejects private text hidden in an ordinary asset name', () async {
    final source = Directory('${temp.path}/source/private-demo');
    await source.create(recursive: true);
    final manifest = File('${source.path}/SKILL.md');
    await manifest.writeAsString(_skill('private-demo', 'Private demo'));
    await File(
      '${source.path}/config.json',
    ).writeAsString('{"apiKey":"secret","workspace":"C:/Users/Alice/private"}');

    await expectLater(
      service.exportSkills([(name: 'private-demo', manifest: manifest)]),
      throwsFormatException,
    );
  });

  test('rejects generic secret and credential assignments', () async {
    final source = Directory('${temp.path}/source/private-demo');
    await source.create(recursive: true);
    final manifest = File('${source.path}/SKILL.md');
    await manifest.writeAsString(_skill('private-demo', 'Private demo'));
    for (final value in [
      '{"secret":"abcdefgh12345678"}',
      'credentials = abcdefgh12345678',
    ]) {
      final config = File('${source.path}/config.json');
      await config.writeAsString(value);
      await expectLater(
        service.exportSkills([(name: 'private-demo', manifest: manifest)]),
        throwsFormatException,
      );
    }
  });

  test('rejects sensitive paths instead of silently omitting them', () async {
    final source = Directory('${temp.path}/source/demo');
    await source.create(recursive: true);
    final manifest = File('${source.path}/SKILL.md');
    await manifest.writeAsString(_skill('demo', 'Demo'));
    await File('${source.path}/.env').writeAsString('SAFE_EXAMPLE=true');

    await expectLater(
      service.exportSkills([(name: 'demo', manifest: manifest)]),
      throwsFormatException,
    );
  });

  test('rejects linked manifests, directories, and nested entries', () async {
    final outside = Directory('${temp.path}/outside')..createSync();
    final outsideManifest = File('${outside.path}/SKILL.md')
      ..writeAsStringSync(_skill('demo', 'Demo'));
    final source = Directory('${temp.path}/source/demo')
      ..createSync(recursive: true);
    final linkedManifest = Link('${source.path}/SKILL.md');
    await linkedManifest.create(outsideManifest.path);
    await expectLater(
      service.exportSkills([
        (name: 'demo', manifest: File(linkedManifest.path)),
      ]),
      throwsFormatException,
    );

    await linkedManifest.delete();
    final manifest = File('${source.path}/SKILL.md')
      ..writeAsStringSync(_skill('demo', 'Demo'));
    await Link('${source.path}/linked.txt').create(outsideManifest.path);
    await expectLater(
      service.exportSkills([(name: 'demo', manifest: manifest)]),
      throwsFormatException,
    );

    final linkedDirectory = Link('${temp.path}/linked-skill');
    await linkedDirectory.create(source.path);
    await expectLater(
      service.exportSkills([
        (name: 'demo', manifest: File('${linkedDirectory.path}/SKILL.md')),
      ]),
      throwsFormatException,
    );
  });

  test('requires the exact frontmatter schema supported by the harness', () {
    final invalidManifests = [
      '''---\nname: demo\ndescription: Demo\nunknown: value\n---\nBody.''',
      '''---\nname: demo\nname: demo\ndescription: Demo\n---\nBody.''',
      '''---\nname: demo\ndescription: Demo\nbad line\n---\nBody.''',
      '''---\nname: demo\ndescription: Demo\ndisable-model-invocation: yes\n---\nBody.''',
      '''---\nname: demo\ndescription: Demo\ndisable-model-invocation: "true"\n---\nBody.''',
    ];
    for (final manifest in invalidManifests) {
      expect(
        () => service.previewImport(
          bytes: _zip([ArchiveFile.string('demo/SKILL.md', manifest)]),
          targetDirectory: Directory('${temp.path}/target'),
        ),
        throwsFormatException,
      );
    }
  });

  test('rejects sensitive files and private text during import', () async {
    for (final bytes in [
      _zip([
        ArchiveFile.string('demo/SKILL.md', _skill('demo', 'Demo')),
        ArchiveFile.string('demo/.env', 'TOKEN=secret'),
      ]),
      _zip([
        ArchiveFile.string('demo/SKILL.md', _skill('demo', 'Demo')),
        ArchiveFile.string('demo/config.json', '{"apiKey":"secret"}'),
      ]),
    ]) {
      await expectLater(
        service.previewImport(
          bytes: bytes,
          targetDirectory: Directory('${temp.path}/target'),
        ),
        throwsFormatException,
      );
    }
  });

  test('recovers an interrupted multi-Skill replacement on startup', () async {
    final target = Directory('${temp.path}/target')
      ..createSync(recursive: true);
    final transaction = Directory('${target.path}/.skill-import-interrupted');
    final backups = Directory('${transaction.path}/backups/a')
      ..createSync(recursive: true);
    File(
      '${backups.path}/SKILL.md',
    ).writeAsStringSync(_skill('a', 'Original A'));
    final replacement = Directory('${target.path}/a')
      ..createSync(recursive: true);
    File(
      '${replacement.path}/SKILL.md',
    ).writeAsStringSync(_skill('a', 'Replacement A'));
    final newlyInstalled = Directory('${target.path}/b')
      ..createSync(recursive: true);
    File(
      '${newlyInstalled.path}/SKILL.md',
    ).writeAsStringSync(_skill('b', 'New B'));
    File('${transaction.path}/transaction.json').writeAsStringSync(
      jsonEncode({
        'names': ['a', 'b'],
        'backedUpNames': ['a'],
      }),
    );

    await service.recoverInterruptedInstalls(target);

    expect(
      File('${target.path}/a/SKILL.md').readAsStringSync(),
      contains('Original A'),
    );
    expect(Directory('${target.path}/b').existsSync(), isFalse);
    expect(transaction.existsSync(), isFalse);
  });

  test('recovers interruptions before and after moving the original', () async {
    final target = Directory('${temp.path}/target')..createSync();
    final beforeMove = Directory('${target.path}/.skill-import-before')
      ..createSync();
    Directory('${beforeMove.path}/backups').createSync();
    final original = Directory('${target.path}/a')..createSync();
    File(
      '${original.path}/SKILL.md',
    ).writeAsStringSync(_skill('a', 'Original'));
    File('${beforeMove.path}/transaction.json').writeAsStringSync(
      jsonEncode({
        'names': ['a'],
        'backedUpNames': ['a'],
      }),
    );

    await service.recoverInterruptedInstalls(target);
    expect(
      File('${original.path}/SKILL.md').readAsStringSync(),
      contains('Original'),
    );

    final afterMove = Directory('${target.path}/.skill-import-after')
      ..createSync();
    final backup = Directory('${afterMove.path}/backups/a')
      ..createSync(recursive: true);
    File('${backup.path}/SKILL.md').writeAsStringSync(_skill('a', 'Original'));
    original.deleteSync(recursive: true);
    File('${afterMove.path}/transaction.json').writeAsStringSync(
      jsonEncode({
        'names': ['a'],
        'backedUpNames': ['a'],
      }),
    );

    await service.recoverInterruptedInstalls(target);
    expect(
      File('${original.path}/SKILL.md').readAsStringSync(),
      contains('Original'),
    );
  });

  test(
    'rejects links in interrupted transactions without touching target',
    () async {
      final target = Directory('${temp.path}/target')..createSync();
      final original = Directory('${target.path}/a')..createSync();
      final originalManifest = File('${original.path}/SKILL.md')
        ..writeAsStringSync(_skill('a', 'Original'));
      final transaction = Directory('${target.path}/.skill-import-malicious')
        ..createSync();
      final backups = Directory('${transaction.path}/backups')..createSync();
      await Link('${backups.path}/a').create(original.path);
      File('${transaction.path}/transaction.json').writeAsStringSync(
        jsonEncode({
          'names': ['a'],
          'backedUpNames': ['a'],
        }),
      );

      await expectLater(
        service.recoverInterruptedInstalls(target),
        throwsFormatException,
      );
      expect(originalManifest.readAsStringSync(), contains('Original'));
      expect(transaction.existsSync(), isTrue);
    },
  );
}

Uint8List _zip(List<ArchiveFile> files) {
  final archive = Archive();
  for (final file in files) {
    archive.addFile(file);
  }
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

Uint8List _markZipEntryAsSymbolicLink(Uint8List bytes) {
  const centralDirectorySignature = <int>[0x50, 0x4b, 0x01, 0x02];
  for (var index = 0; index <= bytes.length - 46; index++) {
    if (bytes[index] != centralDirectorySignature[0] ||
        bytes[index + 1] != centralDirectorySignature[1] ||
        bytes[index + 2] != centralDirectorySignature[2] ||
        bytes[index + 3] != centralDirectorySignature[3]) {
      continue;
    }
    bytes[index + 5] = 3; // ZIP creator OS: Unix.
    const attributes = (0xA000 | 511) << 16;
    for (var byte = 0; byte < 4; byte++) {
      bytes[index + 38 + byte] = (attributes >> (byte * 8)) & 0xff;
    }
    return bytes;
  }
  throw StateError('Central directory was not found.');
}

Uint8List _claimZipEntryExpandedSize(Uint8List bytes, int size) {
  const centralDirectorySignature = <int>[0x50, 0x4b, 0x01, 0x02];
  for (var index = 0; index <= bytes.length - 46; index++) {
    if (bytes[index] != centralDirectorySignature[0] ||
        bytes[index + 1] != centralDirectorySignature[1] ||
        bytes[index + 2] != centralDirectorySignature[2] ||
        bytes[index + 3] != centralDirectorySignature[3]) {
      continue;
    }
    for (var byte = 0; byte < 4; byte++) {
      bytes[index + 24 + byte] = (size >> (byte * 8)) & 0xff;
    }
    return bytes;
  }
  throw StateError('Central directory was not found.');
}

String _skill(String name, String description) =>
    '''
---
name: $name
description: $description
---
Instructions.
''';
