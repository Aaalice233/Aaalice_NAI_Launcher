import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'cooccurrence_manifest_codec.dart';

enum CooccurrenceDataPackStatus {
  unavailable,
  checking,
  downloading,
  verifying,
  installing,
  ready,
  updateAvailable,
  error,
}

enum CooccurrenceDataPackError {
  manifest,
  network,
  diskFull,
  archiveIntegrity,
  databaseIntegrity,
  install,
  unknown,
}

class CooccurrenceDataPackState {
  const CooccurrenceDataPackState({
    this.status = CooccurrenceDataPackStatus.unavailable,
    this.totalBytes = 0,
    this.downloadedBytes = 0,
    this.bytesPerSecond = 0,
    this.installedVersion,
    this.availableVersion,
    this.relationCount = 0,
    this.diskBytes = 0,
    this.error,
    this.errorDetails,
  });

  final CooccurrenceDataPackStatus status;
  final int totalBytes;
  final int downloadedBytes;
  final int bytesPerSecond;
  final String? installedVersion;
  final String? availableVersion;
  final int relationCount;
  final int diskBytes;
  final CooccurrenceDataPackError? error;
  final String? errorDetails;

  double get progress =>
      totalBytes <= 0 ? 0 : (downloadedBytes / totalBytes).clamp(0, 1);
  bool get hasInstalledData => installedVersion != null && diskBytes > 0;

  CooccurrenceDataPackState copyWith({
    CooccurrenceDataPackStatus? status,
    int? totalBytes,
    int? downloadedBytes,
    int? bytesPerSecond,
    String? installedVersion,
    bool clearInstalledVersion = false,
    String? availableVersion,
    int? relationCount,
    int? diskBytes,
    CooccurrenceDataPackError? error,
    bool clearError = false,
    String? errorDetails,
  }) => CooccurrenceDataPackState(
    status: status ?? this.status,
    totalBytes: totalBytes ?? this.totalBytes,
    downloadedBytes: downloadedBytes ?? this.downloadedBytes,
    bytesPerSecond: bytesPerSecond ?? this.bytesPerSecond,
    installedVersion: clearInstalledVersion
        ? null
        : installedVersion ?? this.installedVersion,
    availableVersion: availableVersion ?? this.availableVersion,
    relationCount: relationCount ?? this.relationCount,
    diskBytes: diskBytes ?? this.diskBytes,
    error: clearError ? null : error ?? this.error,
    errorDetails: clearError ? null : errorDetails ?? this.errorDetails,
  );
}

typedef CooccurrenceManifestLoader =
    Future<CooccurrenceDataPackManifest> Function();
typedef ApplicationSupportDirectoryLoader = Future<Directory> Function();
typedef CooccurrenceDatabaseFactory = DatabaseFactory;
