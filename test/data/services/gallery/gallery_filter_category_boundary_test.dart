import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:nai_launcher/core/database/datasources/gallery_data_source.dart';
import 'package:nai_launcher/core/utils/app_logger.dart';
import 'package:nai_launcher/data/services/gallery/gallery_filter_service.dart';

/// Category filtering is pure path matching, so these cases need neither a
/// database nor a real directory tree.
const String _root = '/gallery/images';

void main() {
  setUpAll(() async {
    await AppLogger.initialize(isTestEnvironment: true);
  });

  group('GalleryFilterService category folder boundary', () {
    late GalleryFilterService filterService;

    setUp(() {
      filterService = GalleryFilterService(GalleryDataSource());
    });

    Future<List<String>> filterBy(String category, List<String> paths) async {
      final result = await filterService.applyFilters(
        paths.map(File.new).toList(),
        FilterCriteria(categoryFolderPath: category),
      );
      return result.files.map((file) => file.path).toList();
    }

    test('a numeric folder does not match a date folder', () async {
      final matched = await filterBy('1', [
        '$_root/1/a.png',
        '$_root/2026-10-31/x.png',
        '$_root/11/y.png',
      ]);

      expect(matched, ['$_root/1/a.png']);
    });

    test('a folder name does not match a longer sibling name', () async {
      final matched = await filterBy('a', [
        '$_root/a/x.png',
        '$_root/data_a/x.png',
        '$_root/a_2/x.png',
      ]);

      expect(matched, ['$_root/a/x.png']);
    });

    test('a folder includes its direct and nested files', () async {
      final matched = await filterBy('1', [
        '$_root/1/x.png',
        '$_root/1/sub/y.png',
      ]);

      expect(matched, ['$_root/1/x.png', '$_root/1/sub/y.png']);
    });

    test('a nested category path keeps matching on both boundaries', () async {
      final matched = await filterBy('a/b', [
        '$_root/a/b/x.png',
        '$_root/a/b/c/y.png',
        '$_root/a/bc/x.png',
        '$_root/xa/b/x.png',
      ]);

      expect(matched, ['$_root/a/b/x.png', '$_root/a/b/c/y.png']);
    });

    test('matching ignores case and accepts backslash separators', () async {
      final windowsPath = r'C:\Gallery\Images\Data\x.png';
      final matched = await filterBy('Data', [
        windowsPath,
        r'C:\Gallery\Images\Metadata\x.png',
      ]);
      final nested = await filterBy(r'Data\Sub', [
        r'C:\Gallery\Images\data\SUB\x.png',
        r'C:\Gallery\Images\data\Subset\x.png',
      ]);

      expect(matched, [windowsPath]);
      expect(nested, [r'C:\Gallery\Images\data\SUB\x.png']);
    });
  });
}
