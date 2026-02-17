import 'dart:async';
import 'dart:isolate';

import 'package:dio/dio.dart';

import '../utils/app_logger.dart';

/// 画师标签Isolate拉取服务
///
/// 特点：
/// - 在后台Isolate中运行
/// - 多线程并发拉取
/// - 不阻塞主线程和UI
class ArtistTagsIsolateService {
  static const int _isolateCount = 8; // 8个Isolate并发
  static const int _pagesPerIsolate = 10; // 每个Isolate拉取10页
  static const int _pageSize = 1000;
  static const String _baseUrl = 'https://danbooru.donmai.us';
  static const String _tagsEndpoint = '/tags.json';

  /// 开始后台拉取画师标签
  static Future<void> fetchInBackground({
    required void Function(double progress, String message) onProgress,
    required void Function() onComplete,
    required void Function(String error) onError,
  }) async {
    try {
      AppLogger.i(
        'Starting artist tags background fetch with $_isolateCount isolates',
        'ArtistIsolate',
      );

      // 创建接收端口
      final receivePort = ReceivePort();
      final progressPort = ReceivePort();

      // 启动多个Isolate
      final isolates = <Isolate>[];
      for (var i = 0; i < _isolateCount; i++) {
        final isolate = await Isolate.spawn(
          _isolateEntryPoint,
          _IsolateParams(
            isolateId: i,
            totalIsolates: _isolateCount,
            sendPort: receivePort.sendPort,
            progressPort: progressPort.sendPort,
          ),
        );
        isolates.add(isolate);
      }

      // 监听进度
      var completedIsolates = 0;
      var totalFetched = 0;

      progressPort.listen((message) {
        if (message is Map) {
          final count = message['count'] as int;
          totalFetched += count;
          onProgress(
            completedIsolates / _isolateCount,
            '已拉取 $totalFetched 条画师标签',
          );
        }
      });

      // 等待所有Isolate完成
      await for (final message in receivePort) {
        if (message == 'done') {
          completedIsolates++;
          if (completedIsolates >= _isolateCount) {
            break;
          }
        } else if (message is Map && message.containsKey('error')) {
          final error = message['error'] as String;
          AppLogger.e('Isolate error: $error', 'ArtistIsolate');
        }
      }

      // 清理
      for (final isolate in isolates) {
        isolate.kill();
      }
      receivePort.close();
      progressPort.close();

      AppLogger.i('Artist tags background fetch completed', 'ArtistIsolate');
      onComplete();
    } catch (e, stack) {
      AppLogger.e('Artist tags fetch failed', e, stack, 'ArtistIsolate');
      onError(e.toString());
    }
  }

  /// Isolate入口点
  static void _isolateEntryPoint(_IsolateParams params) async {
    final receivePort = ReceivePort();
    params.sendPort.send(receivePort.sendPort);

    try {
      // 每个Isolate负责一部分页面
      final startPage = params.isolateId * _pagesPerIsolate + 1;
      final endPage = startPage + _pagesPerIsolate;

      // ignore: unused_local_variable
      var fetchedCount = 0;
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 10),
          headers: {
            'Accept': 'application/json',
            'User-Agent': 'NAI-Launcher/1.0',
          },
        ),
      );

      for (var page = startPage; page < endPage; page++) {
        // 拉取画师标签
        final tags = await _fetchArtistTagsPage(dio, page);
        if (tags != null) {
          fetchedCount += tags.length;

          // 报告进度
          params.progressPort.send({'count': tags.length});

          // TODO: 批量写入数据库（需要通过主Isolate通信或使用共享数据库连接）
          // 当前版本仅拉取数据，实际导入逻辑需要后续实现
        }

        // 避免限流
        await Future.delayed(const Duration(milliseconds: 100));
      }

      params.sendPort.send('done');
    } catch (e) {
      params.sendPort.send({'error': e.toString()});
    }
  }

  /// 拉取画师标签页
  static Future<List<Map<String, dynamic>>?> _fetchArtistTagsPage(
    Dio dio,
    int page,
  ) async {
    try {
      final response = await dio.get(
        '$_baseUrl$_tagsEndpoint',
        queryParameters: {
          'page': page,
          'limit': _pageSize,
          'search[order]': 'count',
          'search[category]': '1', // category=1 表示画师标签
          // 不设置阈值，拉取全部画师标签
        },
      );

      if (response.data is List) {
        return (response.data as List)
            .whereType<Map<String, dynamic>>()
            .cast<Map<String, dynamic>>()
            .toList();
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        return [];
      }
      AppLogger.w('Failed to fetch artist tags page $page: $e', 'ArtistIsolate');
    } catch (e) {
      AppLogger.w('Failed to fetch artist tags page $page: $e', 'ArtistIsolate');
    }
    return null;
  }
}

/// Isolate参数
class _IsolateParams {
  final int isolateId;
  final int totalIsolates;
  final SendPort sendPort;
  final SendPort progressPort;

  _IsolateParams({
    required this.isolateId,
    required this.totalIsolates,
    required this.sendPort,
    required this.progressPort,
  });
}
