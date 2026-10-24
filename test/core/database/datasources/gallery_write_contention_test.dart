import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';

import '../../../helpers/gallery_database_sandbox.dart';
import '../../../helpers/log_capture.dart';

// 撞上一次跨消息写锁就要卡满 busy_timeout 的 5 秒
const _stallBudget = Duration(seconds: 2);
const _rounds = 3;
const _imagesPerRound = 20;
const _singleWrites = 24;

void main() {
  final sandbox = useGalleryDatabaseSandbox('gallery_write_contention_');

  Future<int> addImage(String name) => sandbox.dataSource.upsertImage(
    filePath: 'G:/gallery/$name.png',
    fileName: '$name.png',
    fileSize: 1,
    createdAt: DateTime(2026),
    modifiedAt: DateTime(2026),
  );

  Future<List<int>> seedImages(String prefix) async => [
    for (var i = 0; i < _rounds * _imagesPerRound; i++)
      await addImage('${prefix}_$i'),
  ];

  List<T> roundSlice<T>(List<T> values, int round) =>
      values.sublist(round * _imagesPerRound, (round + 1) * _imagesPerRound);

  /// 批量操作与另一条连接上连续的单条写入并发。
  Future<void> expectNoLockStall(
    Future<void> Function(int round) batchOperation,
  ) async {
    final stopwatch = Stopwatch()..start();
    final logs = await captureLogs(
      () => Future.wait([
        () async {
          for (var round = 0; round < _rounds; round++) {
            await batchOperation(round);
          }
        }(),
        () async {
          for (var i = 0; i < _singleWrites; i++) {
            await addImage('single_$i');
          }
        }(),
      ]),
    );
    stopwatch.stop();

    expect(
      logs.where((line) => line.contains('retrying')),
      isEmpty,
      reason: '撞锁后网关会按 BUSY 重试',
    );
    expect(stopwatch.elapsed, lessThan(_stallBudget));
  }

  test('批量标记删除不卡住并发的单条写入', () async {
    await seedImages('deleted');

    await expectNoLockStall(
      (round) => sandbox.dataSource.batchMarkAsDeleted([
        for (var i = 0; i < _imagesPerRound; i++)
          'G:/gallery/deleted_${round * _imagesPerRound + i}.png',
      ]),
    );

    expect(await sandbox.dataSource.countImages(), _singleWrites);
  });

  test('批量写元数据不卡住并发的单条写入', () async {
    final imageIds = await seedImages('meta');

    await expectNoLockStall(
      (round) => sandbox.dataSource.batchUpsertMetadata([
        for (final imageId in roundSlice(imageIds, round))
          MapEntry(imageId, NaiImageMetadata(prompt: 'prompt $imageId')),
      ]),
    );

    final stored = await sandbox.dataSource.getMetadataByImageIds(imageIds);
    expect(stored.values.map((record) => record?.prompt), [
      for (final imageId in imageIds) 'prompt $imageId',
    ]);
  });

  test('批量加入相簿不卡住并发的单条写入', () async {
    final imageIds = await seedImages('album');
    final albumId = await sandbox.dataSource.albums.createAlbum(name: '收录');

    await expectNoLockStall(
      (round) => sandbox.dataSource.albums.addImagesToAlbum(
        albumId,
        roundSlice(imageIds, round),
      ),
    );

    expect(
      await sandbox.dataSource.albums.getAlbumImageIdsWithDescendants(albumId),
      imageIds.toSet(),
    );
  });

  test('整体替换图片标签不卡住并发的单条写入', () async {
    final imageIds = await seedImages('tagged');

    await expectNoLockStall((round) async {
      for (final imageId in roundSlice(imageIds, round)) {
        await sandbox.dataSource.setImageTags(imageId, ['shared', 'r$round']);
      }
    });

    expect(await sandbox.dataSource.getImageTags(imageIds.last), [
      'r${_rounds - 1}',
      'shared',
    ]);
  });

  test('统计面板的只读聚合不卡住并发的单条写入', () async {
    await seedImages('stats');

    await expectNoLockStall((_) => sandbox.dataSource.getDashboardStatistics());

    final snapshot = await sandbox.dataSource.getDashboardStatistics();
    expect(snapshot.totalImages, _rounds * _imagesPerRound + _singleWrites);
  });
}
