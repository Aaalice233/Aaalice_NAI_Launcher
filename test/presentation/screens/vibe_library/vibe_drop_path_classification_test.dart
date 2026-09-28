import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/vibe_import_controller.dart';

void main() {
  test('isolates path type errors and classifies later drop items', () async {
    final result = await classifyVibeDropPaths(
      const ['unavailable.png', 'folder', 'image.webp', 'entry.naiv4vibe'],
      typeReader: (path) async {
        if (path == 'unavailable.png') {
          throw const FileSystemException('Path is unavailable');
        }
        return path == 'folder'
            ? FileSystemEntityType.directory
            : FileSystemEntityType.file;
      },
    );

    expect(result.folders, ['folder']);
    expect(result.images, ['image.webp']);
    expect(result.vibes, ['entry.naiv4vibe']);
  });

  test('keeps files yielded before a folder traversal error', () async {
    Stream<FileSystemEntity> listFolder(String _) async* {
      yield File('first.png');
      yield File('second.naiv4vibebundle');
      throw const FileSystemException('Folder became unavailable');
    }

    final result = await scanVibeDropFolder(
      'folder',
      existsReader: (_) async => true,
      folderLister: listFolder,
    );

    expect(result.images, ['first.png']);
    expect(result.vibes, ['second.naiv4vibebundle']);
  });
}
