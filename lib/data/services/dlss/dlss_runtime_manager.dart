import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:synchronized/synchronized.dart';

import '../../../core/utils/app_logger.dart';
import 'dlss_release.dart';
import 'dlss_runtime_archive.dart';

enum DlssInstallPhase { downloading, extracting, probing, activating }

class DlssInstallation {
  const DlssInstallation(
    this.release,
    this.directory,
    this.hashes, {
    this.installedBytes = 0,
  });
  final DlssRelease release;
  final Directory directory;
  final Map<String, String> hashes;
  final int installedBytes;
}

/// Runtime files and the active pointer are device-local, outside cloud settings.
class DlssRuntimeManager {
  DlssRuntimeManager({
    required this.dio,
    Future<Directory> Function()? directory,
  }) : _directory = directory ?? _defaultDirectory;
  final Dio dio;
  final Future<Directory> Function() _directory;
  final Lock lock = Lock();

  static Future<Directory> _defaultDirectory() async => Directory(
    p.join((await getApplicationSupportDirectory()).path, 'runtimes', 'dlss'),
  );

  Future<List<DlssInstallation>> installed() async {
    final root = await _directory();
    if (!await root.exists()) return [];
    final result = <DlssInstallation>[];
    await for (final entry in root.list(followLinks: false)) {
      if (entry is! Directory || p.basename(entry.path).startsWith('.')) {
        continue;
      }
      final manifest = File(p.join(entry.path, 'runtime.json'));
      if (!await manifest.exists()) continue;
      final json =
          jsonDecode(await manifest.readAsString()) as Map<String, dynamic>;
      final release = DlssRelease.fromJson(
        json['release'] as Map<String, dynamic>,
      );
      if (p.basename(entry.path) != release.directoryName) {
        throw FormatException('Invalid runtime directory: ${entry.path}');
      }
      result.add(
        DlssInstallation(
          release,
          entry,
          Map<String, String>.from(json['hashes'] as Map),
          installedBytes: json['installedBytes'] as int? ?? 0,
        ),
      );
    }
    result.sort(
      (a, b) => b.release.publishedAt.compareTo(a.release.publishedAt),
    );
    return result;
  }

  Future<DlssInstallation?> active() async {
    final file = File(p.join((await _directory()).path, 'active.json'));
    if (!await file.exists()) return null;
    final name = (jsonDecode(await file.readAsString()) as Map)['directory'];
    for (final item in await installed()) {
      if (item.release.directoryName == name) return item;
    }
    throw StateError('Active DLSS runtime is missing: $name');
  }

  Future<void> verify(DlssInstallation installation) async {
    if (installation.hashes.length != dlssRuntimeFiles.length) {
      throw const FormatException('Incomplete DLSS runtime manifest');
    }
    final directory = installation.directory.path;
    final hashes = installation.hashes;
    await Isolate.run(() async {
      for (final name in dlssRuntimeFiles) {
        final file = File(p.join(directory, name));
        if ((await sha256.bind(file.openRead()).first).toString() !=
            hashes[name]) {
          throw FormatException('Installed DLSS file changed: $name');
        }
      }
    });
  }

  Future<void> activate(
    DlssInstallation installation,
    Future<void> Function(Directory) probe,
  ) => lock.synchronized(() async {
    await verify(installation);
    await probe(installation.directory);
    await _writeActive(installation);
  });

  Future<void> _writeActive(DlssInstallation installation) async {
    final root = await _directory();
    final staging = File(p.join(root.path, '.active.json'));
    await staging.writeAsString(
      jsonEncode({'directory': installation.release.directoryName}),
      flush: true,
    );
    await staging.rename(p.join(root.path, 'active.json'));
  }

  Future<void> install(
    DlssRelease release, {
    required Future<void> Function(Directory) probe,
    required CancelToken cancelToken,
    required void Function(double? progress) onProgress,
    void Function(DlssInstallPhase phase)? onPhase,
    void Function(int received, int total)? onDownload,
  }) => lock.synchronized(() async {
    final root = await _directory();
    await root.create(recursive: true);
    final target = Directory(p.join(root.path, release.directoryName));
    final staging = await root.createTemp('.install-');
    final archive = File(p.join(staging.path, 'release.zip'));
    final files = Directory(p.join(staging.path, 'files'));
    await files.create();
    var failed = false;
    try {
      onPhase?.call(DlssInstallPhase.downloading);
      await dio.download(
        release.url,
        archive.path,
        cancelToken: cancelToken,
        onReceiveProgress: (received, _) {
          onProgress(received / release.bytes);
          onDownload?.call(received, release.bytes);
        },
      );
      if (cancelToken.isCancelled) throw cancelToken.cancelError!;
      onProgress(null);
      onPhase?.call(DlssInstallPhase.extracting);
      final zipPath = archive.path;
      final outputPath = files.path;
      final bytes = release.bytes;
      final hash = release.digest;
      final hashes = await extractDlssRuntimeIsolated(
        zipPath,
        outputPath,
        bytes,
        hash,
      );
      if (cancelToken.isCancelled) throw cancelToken.cancelError!;
      onPhase?.call(DlssInstallPhase.probing);
      await probe(files);
      if (cancelToken.isCancelled) throw cancelToken.cancelError!;
      onPhase?.call(DlssInstallPhase.activating);
      var installedBytes = 0;
      for (final name in dlssRuntimeFiles) {
        installedBytes += await File(p.join(files.path, name)).length();
      }
      await File(p.join(files.path, 'runtime.json')).writeAsString(
        jsonEncode({
          'release': release.toJson(),
          'hashes': hashes,
          'architecture': 'windows-x64',
          'source': dlssRepositoryUrl,
          'installedBytes': installedBytes,
        }),
        flush: true,
      );
      final backup = Directory(p.join(staging.path, 'previous'));
      final hadTarget = await target.exists();
      if (hadTarget) await target.rename(backup.path);
      try {
        await files.rename(target.path);
        await _writeActive(DlssInstallation(release, target, hashes));
      } catch (_) {
        if (await target.exists()) await target.delete(recursive: true);
        if (await backup.exists()) await backup.rename(target.path);
        rethrow;
      }
    } catch (_) {
      failed = true;
      rethrow;
    } finally {
      try {
        await staging.delete(recursive: true);
      } catch (error, stack) {
        // Cleanup must not replace the download, verification or activation error.
        if (!failed) rethrow;
        AppLogger.e(
          'DLSSNR staging cleanup failed: ${staging.path}',
          error,
          stack,
          'DLSSNR',
        );
      }
    }
  });

  Future<void> remove(DlssInstallation installation) =>
      lock.synchronized(() async {
        if ((await active())?.release.directoryName ==
            installation.release.directoryName) {
          throw StateError(
            'Switch away from the active DLSS runtime before removing it',
          );
        }
        final root = await _directory();
        final target = Directory(
          p.join(root.path, installation.release.directoryName),
        );
        await target.delete(recursive: true);
      });
}
