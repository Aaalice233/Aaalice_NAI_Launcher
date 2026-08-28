import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/database/datasources/danbooru_tag_data_source.dart';
import 'package:nai_launcher/core/services/danbooru_tags_lazy_service.dart';
import 'package:nai_launcher/core/services/danbooru_tags_meta_repository.dart';
import 'package:nai_launcher/core/services/danbooru_tags_protocol.dart';

class _MockDanbooruTagDataSource extends Mock
    implements DanbooruTagDataSource {}

class _MockDio extends Mock implements Dio {}

class _PendingMetaLoad {
  _PendingMetaLoad(this.state);

  final DanbooruTagsState state;
  final Completer<void> completer = Completer<void>();
}

class _ControlledMetaRepository extends DanbooruTagsMetaRepository {
  final List<_PendingMetaLoad> loads = [];

  @override
  Future<void> loadInto(DanbooruTagsState state) {
    final load = _PendingMetaLoad(state);
    loads.add(load);
    return load.completer.future;
  }

  void succeed(int index, DateTime lastUpdate) {
    final load = loads[index];
    load.state.lastUpdate = lastUpdate;
    load.completer.complete();
  }

  void fail(int index, Object error) {
    loads[index].completer.completeError(error);
  }
}

DanbooruTagsLazyService _createService(DanbooruTagsMetaRepository repository) =>
    DanbooruTagsLazyService(
      dataSource: _MockDanbooruTagDataSource(),
      dio: _MockDio(),
      metaRepository: repository,
    );

void main() {
  group('DanbooruTagsLazyService metadata loading', () {
    test('同一 service 的并发加载合并为一次', () async {
      final repository = _ControlledMetaRepository();
      final service = _createService(repository);

      final first = service.shouldRefreshInBackground();
      final second = service.shouldRefreshInBackground();

      expect(repository.loads, hasLength(1));
      final loadedAt = DateTime.now();
      repository.succeed(0, loadedAt);

      expect(await Future.wait([first, second]), [isFalse, isFalse]);
      expect(service.lastUpdate, loadedAt);
    });

    test('共享 repository 的不同 service 分别填充各自 state', () async {
      final repository = _ControlledMetaRepository();
      final firstService = _createService(repository);
      final secondService = _createService(repository);

      final first = firstService.shouldRefreshInBackground();
      final second = secondService.shouldRefreshInBackground();

      expect(repository.loads, hasLength(2));
      final firstLoadedAt = DateTime.now().subtract(const Duration(days: 1));
      final secondLoadedAt = DateTime.now().subtract(const Duration(days: 2));
      repository
        ..succeed(0, firstLoadedAt)
        ..succeed(1, secondLoadedAt);

      await Future.wait([first, second]);
      expect(firstService.lastUpdate, firstLoadedAt);
      expect(secondService.lastUpdate, secondLoadedAt);
    });

    test('加载失败后清除合并中的 Future 并允许重试', () async {
      final repository = _ControlledMetaRepository();
      final service = _createService(repository);

      final failedLoad = service.shouldRefreshInBackground();
      expect(repository.loads, hasLength(1));
      final failureExpectation = expectLater(failedLoad, throwsStateError);
      repository.fail(0, StateError('load failed'));
      await failureExpectation;

      final retry = service.shouldRefreshInBackground();
      expect(repository.loads, hasLength(2));
      final loadedAt = DateTime.now();
      repository.succeed(1, loadedAt);

      expect(await retry, isFalse);
      expect(service.lastUpdate, loadedAt);
    });
  });
}
