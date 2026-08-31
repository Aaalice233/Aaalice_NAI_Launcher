import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/storage/local_storage_service.dart';
import '../../core/watermark/watermark_logo_service.dart';
import '../../data/models/watermark/watermark_settings.dart';

class WatermarkSettingsState {
  const WatermarkSettingsState({
    required this.configuration,
    this.localLogoPath,
    this.loadIssue,
  });

  final WatermarkSettings configuration;
  final String? localLogoPath;
  final WatermarkSettingsLoadIssue? loadIssue;

  bool get localLogoMissing {
    if (!configuration.logoStyle.enabled) return false;
    final path = localLogoPath;
    return path == null || path.isEmpty || !File(path).existsSync();
  }
}

final watermarkLogoServiceProvider = Provider<WatermarkLogoService>(
  (ref) => const WatermarkLogoService(),
);

final watermarkSettingsProvider =
    NotifierProvider<WatermarkSettingsNotifier, WatermarkSettingsState>(
      WatermarkSettingsNotifier.new,
    );

class WatermarkSettingsNotifier extends Notifier<WatermarkSettingsState> {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  WatermarkSettingsState build() {
    final encoded = _storage.getSetting<Object?>(StorageKeys.watermarkConfigV1);
    final result = WatermarkSettings.decode(encoded is String ? encoded : null);
    final storedLogoPath = _storage.getSetting<Object?>(
      StorageKeys.watermarkLogoPathV1,
    );
    return WatermarkSettingsState(
      configuration: result.settings,
      localLogoPath: storedLogoPath is String && storedLogoPath.isNotEmpty
          ? storedLogoPath
          : null,
      loadIssue: encoded == null || encoded is String
          ? result.issue
          : WatermarkSettingsLoadIssue.corrupted,
    );
  }

  Future<void> saveDefaults([WatermarkSettings? configuration]) =>
      _persistConfiguration(configuration ?? state.configuration);

  Future<void> updateConfiguration(WatermarkSettings configuration) async {
    if (state.loadIssue != null) return;
    await _persistConfiguration(configuration);
  }

  Future<void> _persistConfiguration(WatermarkSettings configuration) async {
    final normalized = WatermarkSettings.decode(
      configuration.encode(),
    ).settings;
    await _storage.setSetting(
      StorageKeys.watermarkConfigV1,
      normalized.encode(),
    );
    state = WatermarkSettingsState(
      configuration: normalized,
      localLogoPath: state.localLogoPath,
    );
  }

  Future<void> updateLocalLogoPath(String path) async {
    if (path.isEmpty) {
      await clearLocalLogoPath();
      return;
    }
    await _storage.setSetting(StorageKeys.watermarkLogoPathV1, path);
    state = WatermarkSettingsState(
      configuration: state.configuration,
      localLogoPath: path,
      loadIssue: state.loadIssue,
    );
  }

  Future<void> clearLocalLogoPath() async {
    final previousPath = state.localLogoPath;
    if (previousPath != null) {
      await ref.read(watermarkLogoServiceProvider).deleteManaged(previousPath);
    }
    await _storage.deleteSetting(StorageKeys.watermarkLogoPathV1);
    state = WatermarkSettingsState(
      configuration: state.configuration,
      loadIssue: state.loadIssue,
    );
  }
}
