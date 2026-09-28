import 'dart:async';
import 'dart:isolate';

import '../../models/gallery/nai_image_metadata.dart';

bool metadataResponseMatchesActiveRequest({
  required int? activeRequestId,
  required int responseRequestId,
}) {
  return activeRequestId != null && activeRequestId == responseRequestId;
}

typedef MetadataWorkerInitializer =
    Future<void> Function(
      int workerId,
      Future<void> Function() initializeWorker,
    );

typedef MetadataWorkerEntrypoint = void Function(Object? message);

enum IsolateParseFailureKind { definitive, infrastructure, cancelled }

/// Isolate 解析配置
class IsolateParseConfig {
  final Duration timeout;
  final bool useGradualRead;
  final bool useCache;

  const IsolateParseConfig({
    this.timeout = const Duration(seconds: 5),
    this.useGradualRead = true,
    this.useCache = true,
  });
}

/// Isolate 解析结果
class IsolateParseResult {
  final NaiImageMetadata? metadata;
  final String? error;
  final Duration parseTime;
  final int? bytesRead;
  final bool wasCancelled;
  final bool wasTimeout;
  final IsolateParseFailureKind? failureKind;

  const IsolateParseResult({
    this.metadata,
    this.error,
    required this.parseTime,
    this.bytesRead,
    this.wasCancelled = false,
    this.wasTimeout = false,
    this.failureKind,
  });

  bool get success => metadata != null;
  bool get retryable =>
      failureKind == IsolateParseFailureKind.infrastructure ||
      failureKind == IsolateParseFailureKind.cancelled;

  factory IsolateParseResult.success(
    NaiImageMetadata metadata, {
    required Duration parseTime,
    int? bytesRead,
  }) {
    return IsolateParseResult(
      metadata: metadata,
      parseTime: parseTime,
      bytesRead: bytesRead,
    );
  }

  factory IsolateParseResult.error(
    String error, {
    required Duration parseTime,
    bool wasCancelled = false,
    bool wasTimeout = false,
    IsolateParseFailureKind failureKind = IsolateParseFailureKind.definitive,
  }) {
    return IsolateParseResult(
      error: error,
      parseTime: parseTime,
      wasCancelled: wasCancelled,
      wasTimeout: wasTimeout,
      failureKind: failureKind,
    );
  }
}

class MetadataWorkerReservation {
  const MetadataWorkerReservation({
    required this.workerId,
    required this.preferredIndex,
    required this.generation,
  });

  final int workerId;
  final int preferredIndex;
  final int generation;
}

/// 无空闲工作线程异常
class NoIdleMetadataWorkerException implements Exception {}

/// 解析任务
class MetadataParseTask {
  final int requestId;
  final String filePath;
  final IsolateParseConfig config;
  final DateTime startTime;
  final Completer<IsolateParseResult> completer;

  MetadataParseTask({
    required this.requestId,
    required this.filePath,
    required this.config,
    required this.startTime,
  }) : completer = Completer<IsolateParseResult>();
}

/// 解析工作线程
class MetadataWorkerInitMessage {
  final SendPort sendPort;
  final int workerId;

  MetadataWorkerInitMessage({required this.sendPort, required this.workerId});
}

/// 解析请求
class MetadataParseRequest {
  final int requestId;
  final String filePath;
  final IsolateParseConfig config;

  MetadataParseRequest({
    required this.requestId,
    required this.filePath,
    required this.config,
  });
}

/// 解析响应
class MetadataParseResponse {
  final int requestId;
  final NaiImageMetadata? metadata;
  final String? error;
  final Duration parseTime;
  final int? bytesRead;
  final bool wasCancelled;
  final IsolateParseFailureKind failureKind;

  // ignore: unused_element
  MetadataParseResponse({
    required this.requestId,
    this.metadata,
    this.error,
    required this.parseTime,
    this.bytesRead,
    this.wasCancelled = false,
    this.failureKind = IsolateParseFailureKind.definitive,
  });
}
