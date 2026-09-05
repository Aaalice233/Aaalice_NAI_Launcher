import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/storage/local_storage_service.dart';
import '../../data/models/mosaic/mosaic_settings.dart';

class MosaicSettingsState {
  const MosaicSettingsState({required this.configuration, this.loadIssue});

  final MosaicSettings configuration;
  final MosaicSettingsLoadIssue? loadIssue;
}

final mosaicSettingsProvider =
    NotifierProvider<MosaicSettingsNotifier, MosaicSettingsState>(
      MosaicSettingsNotifier.new,
    );

class MosaicSettingsNotifier extends Notifier<MosaicSettingsState> {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  MosaicSettingsState build() {
    final encoded = _storage.getSetting<Object?>(StorageKeys.mosaicConfigV1);
    final result = MosaicSettings.decode(encoded is String ? encoded : null);
    return MosaicSettingsState(
      configuration: result.settings,
      loadIssue: encoded == null || encoded is String
          ? result.issue
          : MosaicSettingsLoadIssue.corrupted,
    );
  }

  Future<void> saveDefaults([MosaicSettings? configuration]) =>
      _persistConfiguration(configuration ?? state.configuration);

  Future<void> updateConfiguration(MosaicSettings configuration) async {
    if (state.loadIssue != null) return;
    await _persistConfiguration(configuration);
  }

  Future<void> _persistConfiguration(MosaicSettings configuration) async {
    final normalized = MosaicSettings.decode(configuration.encode()).settings;
    await _storage.setSetting(StorageKeys.mosaicConfigV1, normalized.encode());
    state = MosaicSettingsState(configuration: normalized);
  }
}
