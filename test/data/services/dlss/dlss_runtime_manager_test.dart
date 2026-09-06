import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/services/dlss/dlss_release.dart';
import 'package:nai_launcher/data/services/dlss/dlss_runtime_archive.dart';
import 'package:nai_launcher/data/services/dlss/dlss_runtime_manager.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory directory;
  late Dio dio;
  late DlssRuntimeManager manager;
  late List<int> archive;
  setUp(() async {
    final parent = await Directory(
      'tool/.tmp/dlss-tests',
    ).create(recursive: true);
    directory = await parent.createTemp('runtime-');
    archive = runtimeZip();
    dio = Dio()..httpClientAdapter = _ArchiveAdapter(archive);
    manager = DlssRuntimeManager(dio: dio, directory: () async => directory);
  });
  tearDown(() async {
    dio.close();
    await directory.delete(recursive: true);
  });

  Future<void> install(
    DlssRelease release, {
    Future<void> Function(Directory)? probe,
  }) => manager.install(
    release,
    probe: probe ?? (_) async {},
    cancelToken: CancelToken(),
    onProgress: (_) {},
  );

  test(
    'extracts four Windows x64 components and activates only after probe',
    () async {
      await install(
        release(1, archive),
        probe: (staged) async {
          expect(await manager.active(), isNull);
          expect(
            await File(p.join(staged.path, 'video2dlssnr.exe')).exists(),
            isTrue,
          );
        },
      );
      final active = (await manager.active())!;
      expect(active.release.tag, 'v1');
      expect(active.hashes.keys.toSet(), dlssRuntimeFiles);
      expect(active.installedBytes, 512);
      expect(
        await File(p.join(active.directory.path, 'ffmpeg.exe')).exists(),
        isFalse,
      );
      await manager.verify(active);
    },
  );

  test(
    'failed upgrade and failed reinstall preserve the working version',
    () async {
      final first = release(1, archive);
      await install(first);
      Future<void> fail(Directory _) async =>
          throw StateError('NR initialization failed');
      await expectLater(
        install(release(2, archive), probe: fail),
        throwsStateError,
      );
      await expectLater(install(first, probe: fail), throwsStateError);
      expect((await manager.active())!.release.tag, 'v1');
      expect((await manager.installed()).length, 1);
      expect(
        await directory
            .list()
            .where((e) => p.basename(e.path).startsWith('.install'))
            .length,
        0,
      );
    },
  );

  test(
    'supports rollback, rejects changed components and removing active version',
    () async {
      await install(release(1, archive));
      await install(release(2, archive));
      final installed = await manager.installed();
      final first = installed.singleWhere((i) => i.release.id == 1);
      final second = installed.singleWhere((i) => i.release.id == 2);
      await manager.activate(first, (_) async {});
      expect((await manager.active())!.release.id, 1);
      await expectLater(manager.remove(first), throwsStateError);
      await File(
        p.join(second.directory.path, 'nvngx_dlssnr.dll'),
      ).writeAsBytes([1, 2]);
      await expectLater(
        manager.activate(second, (_) async {}),
        throwsFormatException,
      );
      expect((await manager.active())!.release.id, 1);
      await manager.remove(second);
      expect((await manager.installed()).length, 1);
    },
  );

  test(
    'rejects archive hash mismatch, duplicate names and missing NR DLL',
    () async {
      final zipFile = await File(
        p.join(directory.path, 'test.zip'),
      ).writeAsBytes(archive);
      final output = await Directory(p.join(directory.path, 'out')).create();
      await expectLater(
        extractDlssRuntime(zipFile.path, output.path, archive.length, '0' * 64),
        throwsFormatException,
      );
      for (final bad in [
        runtimeZip(duplicate: true),
        runtimeZip(missing: true),
      ]) {
        await zipFile.writeAsBytes(bad);
        await expectLater(
          extractDlssRuntime(
            zipFile.path,
            output.path,
            bad.length,
            sha256.convert(bad).toString(),
          ),
          throwsFormatException,
        );
      }
    },
  );

  test('cancellation never switches the active pointer', () async {
    await install(release(1, archive));
    final token = CancelToken()..cancel('cancel test');
    await expectLater(
      manager.install(
        release(2, archive),
        probe: (_) async {},
        cancelToken: token,
        onProgress: (_) {},
      ),
      throwsA(isA<DioException>()),
    );
    expect((await manager.active())!.release.id, 1);
  });
}

DlssRelease release(int id, List<int> bytes) => DlssRelease(
  id: id,
  tag: 'v$id',
  prerelease: false,
  publishedAt: DateTime(2026, 9, id),
  assetId: id,
  bytes: bytes.length,
  url: '$dlssRepositoryUrl/releases/download/v$id/video2dlssnr_release.zip',
  digest: sha256.convert(bytes).toString(),
);

List<int> runtimeZip({bool duplicate = false, bool missing = false}) {
  final pe = Uint8List(128);
  pe[0] = 0x4d;
  pe[1] = 0x5a;
  pe[60] = 64;
  pe[64] = 0x50;
  pe[65] = 0x45;
  pe[68] = 0x64;
  pe[69] = 0x86;
  final zip = Archive();
  for (final name in dlssRuntimeFiles) {
    if (missing && name == 'nvngx_dlssnr.dll') continue;
    zip.addFile(ArchiveFile('out\\$name', pe.length, pe));
  }
  zip.addFile(ArchiveFile('out/ffmpeg.exe', 3, [1, 2, 3]));
  if (duplicate) {
    zip.addFile(ArchiveFile('other/nvngx_dlssnr.dll', pe.length, pe));
  }
  return ZipEncoder().encode(zip)!;
}

class _ArchiveAdapter implements HttpClientAdapter {
  _ArchiveAdapter(this.bytes);
  final List<int> bytes;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromBytes(
    bytes,
    200,
    headers: {
      Headers.contentLengthHeader: ['${bytes.length}'],
    },
  );
  @override
  void close({bool force = false}) {}
}
