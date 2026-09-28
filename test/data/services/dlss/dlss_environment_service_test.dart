import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/services/dlss/dlss_device_probe.dart';
import 'package:nai_launcher/data/services/dlss/dlss_environment_service.dart';
import 'package:nai_launcher/data/services/dlss/dlss_release.dart';
import 'package:nai_launcher/data/services/dlss/dlss_runtime_manager.dart';
import 'package:nai_launcher/data/services/dlss/dlss_worker.dart';

void main() {
  late _Devices devices;
  late _Worker worker;
  late DlssEnvironmentService service;
  late DlssInstallation runtime;
  String? cache;
  setUp(() {
    cache = null;
    devices = _Devices();
    worker = _Worker();
    service = DlssEnvironmentService(
      devices: devices,
      worker: worker,
      readCache: () => cache,
      writeCache: (value) async {
        cache = value;
      },
    );
    runtime = DlssInstallation(
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
      {'nvngx_dlssnr.dll': 'a'},
    );
  });

  test('unknown NVIDIA model must pass a real probe before enabling', () async {
    final result = await service.inspect(runtime);
    expect(result.availability, DlssAvailability.ready);
    expect(result.selected!.name, 'Unknown future GPU');
    expect(worker.calls, [0]);
  });

  test('cache is invalidated by driver and component changes', () async {
    await service.inspect(runtime);
    await service.inspect(runtime);
    expect(worker.calls.length, 1);
    devices.driver = 'changed';
    await service.inspect(runtime);
    expect(worker.calls.length, 2);
    final updated = DlssInstallation(runtime.release, runtime.directory, {
      'nvngx_dlssnr.dll': 'b',
    });
    await service.inspect(updated);
    expect(worker.calls.length, 3);
    await service.inspect(updated, force: true);
    expect(worker.calls.length, 4);
  });

  test(
    'missing components and absent selected GPU are distinct states',
    () async {
      expect(
        (await service.inspect(null)).availability,
        DlssAvailability.missingRuntime,
      );
      await expectLater(
        service.inspect(runtime, preferredLuid: 'absent'),
        throwsA(
          isA<DlssEnvironmentException>().having(
            (e) => e.availability,
            'status',
            DlssAvailability.noCompatibleGpu,
          ),
        ),
      );
      expect(worker.calls, isEmpty);
    },
  );

  test('a failed NR probe never writes a successful cache', () async {
    worker.fail = true;
    await expectLater(
      service.inspect(runtime),
      throwsA(isA<DlssEnvironmentException>()),
    );
    expect(cache, isNull);
  });
}

class _Devices extends DlssDeviceProbe {
  String driver = '1';
  @override
  Future<List<DlssDevice>> enumerate() async => [
    DlssDevice(
      index: 0,
      name: 'Unknown future GPU',
      luid: 'device',
      vendorId: 0x10de,
      deviceId: 999,
      memoryBytes: 8 * 1024 * 1024 * 1024,
      d3d12: true,
      driver: driver,
    ),
  ];
}

class _Worker extends DlssWorker {
  final calls = <int>[];
  bool fail = false;
  @override
  Future<void> probe(Directory runtime, {int adapter = 0}) async {
    calls.add(adapter);
    if (fail) throw StateError('NGX initialization failed');
  }
}
