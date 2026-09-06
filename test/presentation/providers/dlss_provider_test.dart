import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/services/dlss/dlss_device_probe.dart';
import 'package:nai_launcher/data/services/dlss/dlss_release.dart';
import 'package:nai_launcher/data/services/dlss/dlss_runtime_manager.dart';
import 'package:nai_launcher/data/services/dlss/dlss_worker.dart';
import 'package:nai_launcher/presentation/providers/dlss_provider.dart';

void main() {
  for (final offline in [false, true]) {
    test(
      'local readiness precedes release lookup (offline=$offline)',
      () async {
        final dio = Dio();
        final source = _Releases(dio);
        final manager = _Runtime(dio);
        final worker = _Worker();
        final controller = DlssController(
          _Storage(),
          manager,
          source,
          worker,
          deviceProbe: _Devices(),
        );
        addTearDown(controller.dispose);
        addTearDown(() => dio.close(force: true));

      final refresh = controller.refresh();
      addTearDown(() async {
        if (!source.response.isCompleted) source.response.complete([]);
        await refresh;
      });
        await source.started.future;
        expect(controller.enabled, isTrue);
        expect(controller.busy, isTrue);
        expect(manager.verifications, 1);
        expect(worker.probes, 1);
        if (offline) {
          source.response.completeError(StateError('release server offline'));
        } else {
          source.response.complete([]);
        }
        await refresh;
        expect(controller.enabled, isTrue);
        expect(controller.busy, isFalse);
        expect(controller.error, offline ? isA<StateError>() : isNull);
      },
    );
  }

  test('startup local refresh never fetches release metadata', () async {
    final dio = Dio();
    final source = _Releases(dio);
    final worker = _Worker();
    final controller = DlssController(
      _Storage(),
      _Runtime(dio),
      source,
      worker,
      deviceProbe: _Devices(),
    );
    addTearDown(controller.dispose);
    addTearDown(() => dio.close(force: true));
    await controller.refresh(fetchReleases: false);
    expect(controller.enabled, isTrue);
    expect(source.started.isCompleted, isFalse);
    await controller.refresh(fetchReleases: false);
    expect(
      worker.probes,
      1,
      reason: 'reuse the successful unchanged GPU probe',
    );
  });
}

class _Storage extends LocalStorageService {
  final values = <String, Object?>{};
  @override
  T? getSetting<T>(String key, {T? defaultValue}) =>
      values.containsKey(key) ? values[key] as T? : defaultValue;
  @override
  Future<void> setSetting<T>(String key, T value) async {
    values[key] = value;
  }
}

class _Releases extends DlssReleaseSource {
  _Releases(super.dio);
  final started = Completer<void>();
  final response = Completer<List<DlssRelease>>();
  @override
  Future<List<DlssRelease>> list({CancelToken? cancelToken}) {
    started.complete();
    return response.future;
  }
}

class _Runtime extends DlssRuntimeManager {
  _Runtime(Dio dio) : super(dio: dio);
  int verifications = 0;
  final runtime = DlssInstallation(
    DlssRelease(
      id: 1,
      tag: 'v1',
      prerelease: false,
      publishedAt: DateTime(2026),
      assetId: 1,
      bytes: 1,
      url: 'unused',
      digest: 'unused',
    ),
    Directory('unused'),
    const {'nvngx_dlssnr.dll': 'hash'},
  );
  @override
  Future<List<DlssInstallation>> installed() async => [runtime];
  @override
  Future<DlssInstallation?> active() async => runtime;
  @override
  Future<void> verify(DlssInstallation installation) async {
    verifications++;
  }
}

class _Devices extends DlssDeviceProbe {
  @override
  Future<List<DlssDevice>> enumerate() async => const [
    DlssDevice(
      index: 0,
      name: 'NVIDIA',
      luid: 'gpu',
      vendorId: 0x10de,
      deviceId: 1,
      memoryBytes: 1,
      d3d12: true,
      driver: '1',
    ),
  ];
}

class _Worker extends DlssWorker {
  int probes = 0;
  @override
  Future<void> probe(Directory runtime, {int adapter = 0}) async {
    probes++;
  }
}
