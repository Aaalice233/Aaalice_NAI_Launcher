import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/database/datasources/gallery_data_source.dart';
import 'package:nai_launcher/core/utils/app_logger.dart';
import 'package:nai_launcher/data/services/gallery/gallery_filter_service.dart';
import 'package:nai_launcher/data/services/gallery/local_gallery_query.dart';
import 'package:nai_launcher/data/services/gallery/local_gallery_repository.dart';

const String _root = '/gallery_remove_paths';

File _file(String relative) => File('$_root/$relative');

List<String> _paths(Iterable<File> files) => [
  for (final file in files) file.path,
];

void main() {
  setUpAll(() async {
    await AppLogger.initialize(isTestEnvironment: true);
  });

  late LocalGalleryQuery query;

  setUp(() {
    final dataSource = GalleryDataSource();
    query = LocalGalleryQuery(
      repository: LocalGalleryRepository(dataSource: dataSource),
      filterService: GalleryFilterService(
        dataSource,
        getRootPath: () async => _root,
      ),
    );
  });

  test('移除后保持剩余顺序、推进列表世代，并返回被移除的跟踪写法', () {
    query.replaceAll([_file('a.png'), _file('b.png'), _file('c.png')]);
    final generation = query.fileListGeneration;

    final removed = query.removePaths(['$_root/b.png']);

    expect(removed, ['$_root/b.png']);
    expect(_paths(query.allFiles), ['$_root/a.png', '$_root/c.png']);
    expect(_paths(query.effectiveFiles), ['$_root/a.png', '$_root/c.png']);
    expect(query.totalCount, 2);
    expect(query.fileListGeneration, generation + 1);
  });

  test('路径按图库键匹配，分隔符与大小写不同也能移除', () {
    query.replaceAll([_file('a.png'), _file('b.png')]);

    final removed = query.removePaths([r'\GALLERY_REMOVE_PATHS\a.png']);

    expect(removed, ['$_root/a.png']);
    expect(_paths(query.allFiles), ['$_root/b.png']);
  }, skip: Platform.isWindows ? false : '只有 Windows 路径不区分分隔符与大小写');

  test('不在列表里的路径不改动列表与世代', () {
    query.replaceAll([_file('a.png')]);
    final generation = query.fileListGeneration;

    expect(query.removePaths(['$_root/unknown.png']), isEmpty);
    expect(query.fileListGeneration, generation);
    expect(_paths(query.allFiles), ['$_root/a.png']);
  });

  test('筛选中同时从筛选结果移除，不需要重跑筛选', () async {
    query.replaceAll([
      _file('tracked/a.png'),
      _file('other/b.png'),
      _file('tracked/c.png'),
    ]);
    await query.applyFilter(
      const FilterCriteria(categoryFolderPath: 'tracked'),
    );
    expect(query.filteredCount, 2);

    query.removePaths(['$_root/tracked/a.png']);

    expect(_paths(query.effectiveFiles), ['$_root/tracked/c.png']);
    expect(query.filteredCount, 1);
    expect(query.totalCount, 2);
  });

  test('删除期间才完成的筛选不能把已删的路径放回列表', () async {
    final source = GalleryDataSource();
    final delayed = _DelayedFilter(source);
    final query = LocalGalleryQuery(
      repository: LocalGalleryRepository(dataSource: source),
      filterService: delayed,
    );
    final files = [_file('tracked/a.png'), _file('tracked/b.png')];
    query.replaceAll(files);
    const criteria = FilterCriteria(categoryFolderPath: 'tracked');
    final pending = query.applyFilter(criteria);
    query.removePaths([files.first.path]);
    delayed.result.complete(
      FilterResult(
        files: files,
        totalCount: 2,
        executionTime: Duration.zero,
        criteria: criteria,
      ),
    );
    await pending;
    expect(query.effectiveFiles, [files.last]);
    expect(query.filteredCount, 1);
  });
}

class _DelayedFilter extends GalleryFilterService {
  _DelayedFilter(super.dataSource);
  final result = Completer<FilterResult>();
  @override
  Future<FilterResult> applyFilters(
    List<File> allFiles,
    FilterCriteria criteria, {
    String? operationId,
    int fileListGeneration = 0,
  }) => result.future;
}
