import 'dart:io';

import 'package:path/path.dart' as p;

import 'gallery_path_utils.dart';

class GalleryFolderCounts {
  final _totals = <String, int>{};

  void replaceFiles(Iterable<File> files) {
    _totals.clear();
    final direct = <String, int>{};
    for (final file in files) {
      direct.update(p.dirname(file.path), (n) => n + 1, ifAbsent: () => 1);
    }
    direct.forEach(addToFolder);
  }

  void addToFolder(String folder, int change) {
    var key = galleryFilePathKey(p.normalize(folder));
    while (!p.basename(key).startsWith('.')) {
      _totals.update(key, (n) => n + change, ifAbsent: () => change);
      final parent = p.dirname(key);
      if (parent == key) break;
      key = parent;
    }
  }

  int countIn(String folder) =>
      _totals[galleryFilePathKey(p.normalize(folder))] ?? 0;
}
