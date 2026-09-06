import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'dlss_device_probe.dart';
import 'dlss_runtime_manager.dart';
import 'dlss_worker.dart';

class DlssEnvironment {
  const DlssEnvironment({
    this.availability = DlssAvailability.notChecked,
    this.devices = const [],
    this.selected,
    this.detail,
  });
  final DlssAvailability availability;
  final List<DlssDevice> devices;
  final DlssDevice? selected;
  final String? detail;
}

class DlssEnvironmentException implements Exception {
  const DlssEnvironmentException(this.availability, this.detail);
  final DlssAvailability availability;
  final String detail;
  @override
  String toString() => detail;
}

/// Caches only a successful real NR job, keyed by device, driver and all files.
class DlssEnvironmentService {
  DlssEnvironmentService({
    required this.devices,
    required this.worker,
    required this.readCache,
    required this.writeCache,
  });
  final DlssDeviceProbe devices;
  final DlssWorker worker;
  final String? Function() readCache;
  final Future<void> Function(String) writeCache;

  Future<DlssEnvironment> inspect(
    DlssInstallation? runtime, {
    String? preferredLuid,
    bool force = false,
  }) async {
    final adapters = await devices.enumerate();
    if (runtime == null) {
      return DlssEnvironment(
        availability: DlssAvailability.missingRuntime,
        devices: adapters,
      );
    }
    final candidates = adapters
        .where(
          (d) =>
              d.candidate && (preferredLuid == null || preferredLuid == d.luid),
        )
        .toList();
    if (candidates.isEmpty) {
      throw const DlssEnvironmentException(
        DlssAvailability.noCompatibleGpu,
        'No selected NVIDIA DXGI adapter with D3D12 support is available',
      );
    }
    if (!force) {
      final cached = readCache();
      for (final device in candidates) {
        if (device.driver != null && cached == fingerprint(runtime, device)) {
          return DlssEnvironment(
            availability: DlssAvailability.ready,
            devices: adapters,
            selected: device,
          );
        }
      }
    }
    final selected = await _probeCandidates(runtime.directory, candidates);
    await writeCache(fingerprint(runtime, selected));
    return DlssEnvironment(
      availability: DlssAvailability.ready,
      devices: adapters,
      selected: selected,
    );
  }

  Future<void> probeDirectory(
    Directory directory, {
    String? preferredLuid,
  }) async {
    final adapters = await devices.enumerate();
    final candidates = adapters
        .where(
          (d) =>
              d.candidate && (preferredLuid == null || preferredLuid == d.luid),
        )
        .toList();
    if (candidates.isEmpty) {
      throw const DlssEnvironmentException(
        DlssAvailability.noCompatibleGpu,
        'No selected NVIDIA DXGI adapter with D3D12 support is available',
      );
    }
    await _probeCandidates(directory, candidates);
  }

  Future<DlssDevice> _probeCandidates(
    Directory directory,
    List<DlssDevice> candidates,
  ) async {
    final failures = <String>[];
    for (final device in candidates) {
      try {
        await worker.probe(directory, adapter: device.index);
        return device;
      } catch (error) {
        failures.add(
          '${device.name} (${device.luid}, ${device.driver}): $error',
        );
      }
    }
    throw DlssEnvironmentException(
      DlssAvailability.initializationFailed,
      failures.join('\n'),
    );
  }

  static String fingerprint(DlssInstallation runtime, DlssDevice device) =>
      sha256
          .convert(
            utf8.encode(
              jsonEncode({
                'workerProtocol': 5,
                'device': device.fingerprint,
                'release': runtime.release.directoryName,
                'components': {
                  for (final key in runtime.hashes.keys.toList()..sort())
                    key: runtime.hashes[key],
                },
              }),
            ),
          )
          .toString();
}
