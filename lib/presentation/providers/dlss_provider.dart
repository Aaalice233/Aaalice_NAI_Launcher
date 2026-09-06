import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/platform/platform_capabilities.dart';
import '../../core/storage/local_storage_service.dart';
import '../../data/services/dlss/dlss_options.dart';
import '../../data/services/dlss/dlss_release.dart';
import '../../data/services/dlss/dlss_runtime_manager.dart';
import '../../data/services/dlss/dlss_worker.dart';
import '../../data/services/dlss/dlss_device_probe.dart';
import '../../data/services/dlss/dlss_environment_service.dart';

final dlssProvider = ChangeNotifierProvider<DlssController>((ref) {
  final dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 60),
    ),
  );
  ref.onDispose(() => dio.close(force: true));
  final controller = DlssController(
    ref.read(localStorageServiceProvider),
    DlssRuntimeManager(dio: dio),
    DlssReleaseSource(dio),
    DlssWorker(),
  );
  if (PlatformCapabilities.operatingSystem.supportsDlssEnhancement) {
    scheduleMicrotask(() => controller.refresh(fetchReleases: false));
  }
  return controller;
});

class DlssController extends ChangeNotifier {
  DlssController(
    this.storage,
    this.manager,
    this.source,
    this.worker, {
    DlssDeviceProbe? deviceProbe,
  }) {
    environmentService = DlssEnvironmentService(
      devices: deviceProbe ?? DlssDeviceProbe(),
      worker: worker,
      readCache: () => storage.getSetting<String>('dlss_probe_cache'),
      writeCache: (value) => storage.setSetting('dlss_probe_cache', value),
    );
  }
  final LocalStorageService storage;
  final DlssRuntimeManager manager;
  final DlssReleaseSource source;
  final DlssWorker worker;
  late final DlssEnvironmentService environmentService;
  DlssEnvironment environment = const DlssEnvironment();
  List<DlssRelease> releases = [];
  List<DlssInstallation> installations = [];
  DlssInstallation? active;
  bool busy = false;
  bool enhancing = false;
  double? progress;
  Object? error;
  DlssInstallPhase? installPhase;
  int downloadedBytes = 0;
  int downloadTotalBytes = 0;
  double downloadBytesPerSecond = 0;
  Object? enhancementError;
  int queuedJobs = 0;
  CancelToken? _download;
  Future<void>? _activeOperation;
  bool _disposed = false;

  bool get preferenceEnabled =>
      storage.getSetting<bool>('dlss_enabled', defaultValue: true) ?? true;
  bool get ready => environment.availability == DlssAvailability.ready;
  bool get canCancelInstall => _download != null;
  bool get enabled => preferenceEnabled && ready;
  bool get automatic =>
      storage.getSetting<bool>('dlss_automatic', defaultValue: false) ?? false;
  String? get preferredLuid => storage.getSetting<String>('dlss_adapter_luid');
  DlssOptions get options => DlssOptions.fromJson(
    jsonDecode(storage.getSetting<String>('dlss_options') ?? '{}')
        as Map<String, dynamic>,
  );
  DlssRelease? get latest => releases.where((r) => !r.prerelease).firstOrNull;

  Future<void> setEnabled(bool value) async {
    if (value && !ready) {
      throw StateError('DLSS environment has not passed verification');
    }
    await storage.setSetting('dlss_enabled', value);
    _notify();
  }

  Future<void> setAutomatic(bool value) async {
    await storage.setSetting('dlss_automatic', value);
    _notify();
  }

  Future<void> setOptions(DlssOptions value) async {
    value.validate();
    await storage.setSetting('dlss_options', jsonEncode(value.toJson()));
    _notify();
  }

  Future<void> refresh({bool fetchReleases = true}) async {
    await _activeOperation;
    return _operation(() async {
      installations = await manager.installed();
      active = await manager.active();
      if (fetchReleases) releases = await source.list();
      await manager.lock.synchronized(
        () => _ensureEnvironment(selectedLuid: preferredLuid),
      );
    });
  }

  Future<void> detect() => _operation(
    () => manager.lock.synchronized(
      () => _ensureEnvironment(force: true, selectedLuid: preferredLuid),
    ),
  );

  Future<void> selectDevice(String? luid) => _operation(() async {
    if (luid == null) {
      await storage.deleteSetting('dlss_adapter_luid');
    } else {
      await storage.setSetting('dlss_adapter_luid', luid);
    }
    await manager.lock.synchronized(
      () => _ensureEnvironment(force: true, selectedLuid: luid),
    );
  });

  Future<void> _ensureEnvironment({
    bool force = false,
    String? selectedLuid,
  }) async {
    environment = DlssEnvironment(
      availability: DlssAvailability.checking,
      devices: environment.devices,
      selected: environment.selected,
    );
    _notify();
    try {
      active = await manager.active();
      if (active != null) {
        try {
          await manager.verify(active!);
        } catch (exception) {
          throw DlssEnvironmentException(
            DlssAvailability.invalidComponents,
            exception.toString(),
          );
        }
      }
      environment = await environmentService.inspect(
        active,
        preferredLuid: selectedLuid,
        force: force,
      );
    } on DlssEnvironmentException catch (exception) {
      environment = DlssEnvironment(
        availability: exception.availability,
        devices: environment.devices,
        detail: exception.detail,
      );
      rethrow;
    } catch (exception) {
      environment = DlssEnvironment(
        availability: DlssAvailability.initializationFailed,
        devices: environment.devices,
        detail: exception.toString(),
      );
      rethrow;
    } finally {
      _notify();
    }
  }

  Future<void> install(DlssRelease release) => _operation(() async {
    final token = _download = CancelToken();
    final timer = Stopwatch()..start();
    var lastBytes = 0;
    var lastTime = 0;
    progress = 0;
    downloadedBytes = 0;
    downloadTotalBytes = release.bytes;
    downloadBytesPerSecond = 0;
    await manager.install(
      release,
      cancelToken: token,
      probe: (directory) => environmentService.probeDirectory(
        directory,
        preferredLuid: preferredLuid,
      ),
      onPhase: (phase) {
        installPhase = phase;
        _notify();
      },
      onDownload: (received, total) {
        downloadedBytes = received;
        downloadTotalBytes = total;
        final now = timer.elapsedMilliseconds;
        if (now - lastTime >= 250 || received == total) {
          final elapsed = now - lastTime;
          if (elapsed > 0) {
            downloadBytesPerSecond = (received - lastBytes) * 1000 / elapsed;
          }
          lastBytes = received;
          lastTime = now;
          _notify();
        }
      },
      onProgress: (value) {
        progress = value;
        _notify();
      },
    );
    installations = await manager.installed();
    active = await manager.active();
    await manager.lock.synchronized(
      () => _ensureEnvironment(selectedLuid: preferredLuid),
    );
  });

  Future<void> activate(DlssInstallation value) => _operation(() async {
    await manager.activate(
      value,
      (directory) => environmentService.probeDirectory(
        directory,
        preferredLuid: preferredLuid,
      ),
    );
    active = await manager.active();
    await manager.lock.synchronized(
      () => _ensureEnvironment(selectedLuid: preferredLuid),
    );
  });

  Future<void> remove(DlssInstallation value) => _operation(() async {
    await manager.remove(value);
    installations = await manager.installed();
  });

  void cancelDownload() => _download?.cancel('User cancelled DLSS download');

  Future<void> _operation(Future<void> Function() action) {
    if (busy || _disposed) return _activeOperation ?? Future<void>.value();
    return _activeOperation = _performOperation(action);
  }

  Future<void> _performOperation(Future<void> Function() action) async {
    if (busy || _disposed) return;
    busy = true;
    error = null;
    progress = null;
    _notify();
    try {
      await action();
    } catch (exception) {
      error = exception;
    } finally {
      busy = false;
      _download = null;
      installPhase = null;
      progress = null;
      _notify();
    }
  }

  Future<Uint8List> enhance(
    Uint8List bytes,
    DlssOptions parameters, {
    Future<void>? cancelled,
  }) {
    if (!preferenceEnabled) return Future.error(StateError('DLSS is disabled'));
    return _enhance(
      bytes,
      parameters,
      cancelled: cancelled,
      selectedLuid: preferredLuid,
    );
  }

  Future<Uint8List> _enhance(
    Uint8List bytes,
    DlssOptions parameters, {
    Future<void>? cancelled,
    String? selectedLuid,
  }) async {
    var wasCancelled = false;
    var finished = false;
    if (cancelled != null) {
      unawaited(
        cancelled.then((_) {
          if (!finished) wasCancelled = true;
        }),
      );
    }
    queuedJobs++;
    _notify();
    try {
      return await manager.lock.synchronized(() async {
        queuedJobs--;
        _notify();
        if (wasCancelled) throw const DlssCancelled();
        await _ensureEnvironment(selectedLuid: selectedLuid);
        final runtime = active;
        if (!ready || runtime == null) {
          throw DlssEnvironmentException(
            environment.availability,
            environment.detail ?? 'DLSS runtime is not ready',
          );
        }
        enhancing = true;
        enhancementError = null;
        _notify();
        try {
          return await worker.run(
            runtime.directory,
            bytes,
            parameters,
            adapter: environment.selected!.index,
            cancelled: cancelled,
            version: runtime.release.tag,
          );
        } on DlssWorkerFailure catch (exception) {
          if (exception.requiresRecheck) {
            environment = DlssEnvironment(
              availability: DlssAvailability.initializationFailed,
              devices: environment.devices,
              detail: exception.toString(),
            );
            await storage.deleteSetting('dlss_probe_cache');
          }
          rethrow;
        } finally {
          enhancing = false;
          _notify();
        }
      });
    } finally {
      finished = true;
    }
  }

  Future<Uint8List> Function(Uint8List, Future<void>) automaticSnapshot() {
    final parameters = options;
    final selected = preferredLuid;
    if (!PlatformCapabilities.operatingSystem.supportsDlssEnhancement ||
        !preferenceEnabled ||
        !automatic) {
      return (bytes, _) async => bytes;
    }
    var deviceFailed = false;
    return (bytes, cancelled) async {
      if (deviceFailed) return bytes;
      try {
        return await _enhance(
          bytes,
          parameters,
          cancelled: cancelled,
          selectedLuid: selected,
        );
      } catch (_) {
        deviceFailed = !ready;
        rethrow;
      }
    };
  }

  void reportEnhancementError(Object exception) {
    enhancementError = exception;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _download?.cancel();
    super.dispose();
  }
}
