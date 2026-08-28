import 'package:flutter/foundation.dart';

enum ZhDictionaryFailureStage { metadata, download, integrity, install }

enum ZhDictionaryFailureKind {
  rateLimited,
  accessDenied,
  network,
  integrity,
  invalidData,
  unknown,
}

class ZhDictionaryException implements Exception {
  const ZhDictionaryException({
    required this.stage,
    required this.kind,
    required this.diagnostic,
    this.statusCode,
  });

  final ZhDictionaryFailureStage stage;
  final ZhDictionaryFailureKind kind;
  final String diagnostic;
  final int? statusCode;

  @override
  String toString() {
    final status = statusCode == null ? '' : ' (HTTP $statusCode)';
    return 'ffdkj ${stage.name} failed$status';
  }
}

@immutable
class ZhDictionarySource {
  const ZhDictionarySource({
    required this.commitSha,
    required this.blobSha,
    required this.size,
    required this.downloadUri,
    this.sha256,
    this.etag,
  });

  final String commitSha;
  final String blobSha;
  final String? sha256;
  final int size;
  final Uri downloadUri;
  final String? etag;
}

class ZhDictionaryState {
  const ZhDictionaryState({
    this.isInstalled = false,
    this.isBusy = false,
    this.progress = 0,
    this.tagCount = 0,
    this.version,
    this.updateAvailable = false,
    this.lastCheckedAt,
    this.error,
    this.failureStage,
    this.failureKind,
  });

  final bool isInstalled;
  final bool isBusy;
  final double progress;
  final int tagCount;
  final String? version;
  final bool updateAvailable;
  final DateTime? lastCheckedAt;
  final String? error;
  final ZhDictionaryFailureStage? failureStage;
  final ZhDictionaryFailureKind? failureKind;

  ZhDictionaryState copyWith({
    bool? isInstalled,
    bool? isBusy,
    double? progress,
    int? tagCount,
    String? version,
    bool? updateAvailable,
    DateTime? lastCheckedAt,
    String? error,
    ZhDictionaryFailureStage? failureStage,
    ZhDictionaryFailureKind? failureKind,
    bool clearError = false,
  }) {
    return ZhDictionaryState(
      isInstalled: isInstalled ?? this.isInstalled,
      isBusy: isBusy ?? this.isBusy,
      progress: progress ?? this.progress,
      tagCount: tagCount ?? this.tagCount,
      version: version ?? this.version,
      updateAvailable: updateAvailable ?? this.updateAvailable,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      error: clearError ? null : error ?? this.error,
      failureStage: clearError ? null : failureStage ?? this.failureStage,
      failureKind: clearError ? null : failureKind ?? this.failureKind,
    );
  }
}
