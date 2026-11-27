import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:nai_launcher/core/database/datasources/gallery_data_source.dart';
import 'package:nai_launcher/core/utils/app_logger.dart';
import 'package:nai_launcher/data/services/gallery/gallery_filter_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

/// Category filtering is pure path matching against the gallery root, so these
/// cases need neither a database nor a real directory tree. The root still has
/// to resolve to the current platform's Documents directory, otherwise the
/// boundary comparison would mix path styles.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await AppLogger.initialize(isTestEnvironment: true);
  });

  group('GalleryFilterService category folder boundary', () {
    late Directory documents;
    late String root;
    late GalleryFilterService filterService;
    late PathProviderPlatform originalPathProvider;

    setUp(() async {
      documents = await Directory.systemTemp.createTemp('gallery-filter-');
      originalPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _DocumentsPathProvider(documents.path);
      root = p.join(documents.path, 'NAI_Launcher', 'images');
      filterService = GalleryFilterService(GalleryDataSource());
    });

    tearDown(() async {
      PathProviderPlatform.instance = originalPathProvider;
      if (await documents.exists()) await documents.delete(recursive: true);
    });

    Future<List<String>> filterBy(String category, List<String> paths) async {
      final result = await filterService.applyFilters(
        paths.map(File.new).toList(),
        FilterCriteria(categoryFolderPath: category),
      );
      return result.files.map((file) => file.path).toList();
    }

    test('a numeric folder does not match a date folder', () async {
      final target = p.join(root, '1', 'a.png');
      final matched = await filterBy('1', [
        target,
        p.join(root, '2026-10-31', 'x.png'),
        p.join(root, '11', 'y.png'),
      ]);

      expect(matched, [target]);
    });

    test('a folder name does not match a longer sibling name', () async {
      final target = p.join(root, 'a', 'x.png');
      final matched = await filterBy('a', [
        target,
        p.join(root, 'data_a', 'x.png'),
        p.join(root, 'a_2', 'x.png'),
      ]);

      expect(matched, [target]);
    });

    test('a folder includes its direct and nested files', () async {
      final direct = p.join(root, '1', 'x.png');
      final nested = p.join(root, '1', 'sub', 'y.png');
      final matched = await filterBy('1', [direct, nested]);

      expect(matched, [direct, nested]);
    });

    test('a nested category path keeps matching on both boundaries', () async {
      final direct = p.join(root, 'a', 'b', 'x.png');
      final nested = p.join(root, 'a', 'b', 'c', 'y.png');
      final matched = await filterBy(
        p.join('a', 'b'),
        [
          direct,
          nested,
          p.join(root, 'a', 'bc', 'x.png'),
          p.join(root, 'xa', 'b', 'x.png'),
        ],
      );

      expect(matched, [direct, nested]);
    });

    test('matching ignores case and accepts backslash separators', () async {
      if (p.context.style != p.Style.windows) {
        // 大小写不敏感与反斜杠分隔是 Windows 路径语义，其他平台按平台规则比较
        return;
      }
      final windowsRoot = root.replaceAll('/', r'\');
      final target = '$windowsRoot\\data\\x.png';
      final matched = await filterBy('Data', [
        target,
        '$windowsRoot\\Metadata\\x.png',
      ]);
      final nested = await filterBy(r'Data\Sub', [
        '$windowsRoot\\data\\SUB\\x.png',
        '$windowsRoot\\data\\Subset\\x.png',
      ]);

      expect(matched, [target]);
      expect(nested, ['$windowsRoot\\data\\SUB\\x.png']);
    });
  });
}

class _DocumentsPathProvider extends PathProviderPlatform {
  _DocumentsPathProvider(this.documentsPath);

  final String documentsPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;
}
