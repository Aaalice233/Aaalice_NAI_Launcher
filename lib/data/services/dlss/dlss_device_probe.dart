import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

enum DlssAvailability {
  notChecked,
  checking,
  missingRuntime,
  noCompatibleGpu,
  invalidComponents,
  initializationFailed,
  ready,
}

class DlssDevice {
  const DlssDevice({
    required this.index,
    required this.name,
    required this.luid,
    required this.vendorId,
    required this.deviceId,
    required this.memoryBytes,
    required this.d3d12,
    required this.driver,
  });
  final int index;
  final String name;
  final String luid;
  final int vendorId;
  final int deviceId;
  final int memoryBytes;
  final bool d3d12;
  final String? driver;
  bool get candidate => vendorId == 0x10de && d3d12;
  String get fingerprint => '$luid/$vendorId/$deviceId/$driver';

  factory DlssDevice.fromJson(Map<String, dynamic> json) => DlssDevice(
    index: json['index'] as int,
    name: json['name'] as String,
    luid: json['luid'] as String,
    vendorId: json['vendorId'] as int,
    deviceId: json['deviceId'] as int,
    memoryBytes: json['memoryBytes'] as int,
    d3d12: json['d3d12'] as bool,
    driver: json['driver'] as String?,
  );
}

class DlssDeviceProbe {
  DlssDeviceProbe({String? executable})
    : executable =
          executable ??
          p.join(
            p.dirname(Platform.resolvedExecutable),
            'aaalice_dlss_probe.exe',
          );
  final String executable;

  Future<List<DlssDevice>> enumerate() async {
    if (!Platform.isWindows) return [];
    final process = await Process.start(executable, const []);
    final output = process.stdout.transform(utf8.decoder).join();
    final errors = process.stderr.transform(utf8.decoder).join();
    try {
      final exit = await process.exitCode.timeout(const Duration(seconds: 15));
      final text = await output;
      final detail = await errors;
      if (exit != 0) throw StateError('DXGI probe exited $exit: $detail');
      final json = jsonDecode(text) as Map<String, dynamic>;
      if (json['schema'] != 1 || json['workerVersion'] != 1) {
        throw const FormatException('Unsupported DLSS device probe protocol');
      }
      return (json['adapters'] as List)
          .map((row) => DlssDevice.fromJson(row as Map<String, dynamic>))
          .toList();
    } finally {
      process.kill();
      await process.exitCode;
      await output;
      await errors;
    }
  }
}
