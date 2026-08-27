import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/storage/local_storage_service.dart';

class ShareImageSettings {
  const ShareImageSettings({
    this.protectionMode = false,
    this.stripMetadataForCopyAndDrag = true,
    this.confirmDangerousActions = true,
    this.warnExternalImageSend = true,
    this.preventOverwrite = true,
    this.warnHighAnlasCost = true,
    this.highAnlasCostThreshold = 50,
    this.limitGenerationInterval = false,
    this.generationIntervalSeconds = 5,
  });

  final bool protectionMode;
  final bool stripMetadataForCopyAndDrag;
  final bool confirmDangerousActions;
  final bool warnExternalImageSend;
  final bool preventOverwrite;
  final bool warnHighAnlasCost;
  final int highAnlasCostThreshold;
  final bool limitGenerationInterval;
  final int generationIntervalSeconds;

  bool get effectiveStripMetadataForCopyAndDrag =>
      protectionMode && stripMetadataForCopyAndDrag;

  bool get effectiveConfirmDangerousActions =>
      protectionMode && confirmDangerousActions;

  bool get effectiveWarnExternalImageSend =>
      protectionMode && warnExternalImageSend;

  bool get effectivePreventOverwrite => protectionMode && preventOverwrite;

  bool get effectiveWarnHighAnlasCost =>
      protectionMode && warnHighAnlasCost && highAnlasCostThreshold > 0;

  int get effectiveGenerationIntervalSeconds =>
      protectionMode && limitGenerationInterval ? generationIntervalSeconds : 0;

  ShareImageSettings copyWith({
    bool? protectionMode,
    bool? stripMetadataForCopyAndDrag,
    bool? confirmDangerousActions,
    bool? warnExternalImageSend,
    bool? preventOverwrite,
    bool? warnHighAnlasCost,
    int? highAnlasCostThreshold,
    bool? limitGenerationInterval,
    int? generationIntervalSeconds,
  }) {
    return ShareImageSettings(
      protectionMode: protectionMode ?? this.protectionMode,
      stripMetadataForCopyAndDrag:
          stripMetadataForCopyAndDrag ?? this.stripMetadataForCopyAndDrag,
      confirmDangerousActions:
          confirmDangerousActions ?? this.confirmDangerousActions,
      warnExternalImageSend:
          warnExternalImageSend ?? this.warnExternalImageSend,
      preventOverwrite: preventOverwrite ?? this.preventOverwrite,
      warnHighAnlasCost: warnHighAnlasCost ?? this.warnHighAnlasCost,
      highAnlasCostThreshold:
          highAnlasCostThreshold ?? this.highAnlasCostThreshold,
      limitGenerationInterval:
          limitGenerationInterval ?? this.limitGenerationInterval,
      generationIntervalSeconds:
          generationIntervalSeconds ?? this.generationIntervalSeconds,
    );
  }
}

final shareImageSettingsProvider =
    NotifierProvider<ShareImageSettingsNotifier, ShareImageSettings>(
      ShareImageSettingsNotifier.new,
    );

class ShareImageSettingsNotifier extends Notifier<ShareImageSettings> {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  ShareImageSettings build() {
    final protectionMode =
        _storage.getSetting<bool>(StorageKeys.protectionMode) ??
        _storage.getSetting<bool>(
          StorageKeys.assetProtectionMode,
          defaultValue: false,
        ) ??
        false;
    final generationIntervalSeconds =
        (_storage.getSetting<int>(
                  StorageKeys.protectionGenerationIntervalSeconds,
                  defaultValue: 5,
                ) ??
                5)
            .clamp(1, 3600)
            .toInt();

    return ShareImageSettings(
      protectionMode: protectionMode,
      stripMetadataForCopyAndDrag:
          _storage.getSetting<bool>(
            StorageKeys.shareStripMetadata,
            defaultValue: true,
          ) ??
          true,
      confirmDangerousActions:
          _storage.getSetting<bool>(
            StorageKeys.protectionConfirmDangerousActions,
            defaultValue: true,
          ) ??
          true,
      warnExternalImageSend:
          _storage.getSetting<bool>(
            StorageKeys.protectionWarnExternalImageSend,
            defaultValue: true,
          ) ??
          true,
      preventOverwrite:
          _storage.getSetting<bool>(
            StorageKeys.protectionPreventOverwrite,
            defaultValue: true,
          ) ??
          true,
      warnHighAnlasCost:
          _storage.getSetting<bool>(
            StorageKeys.protectionWarnHighAnlasCost,
            defaultValue: true,
          ) ??
          true,
      highAnlasCostThreshold:
          _storage.getSetting<int>(
            StorageKeys.protectionHighAnlasCostThreshold,
            defaultValue: 50,
          ) ??
          50,
      limitGenerationInterval:
          _storage.getSetting<bool>(
            StorageKeys.protectionLimitGenerationInterval,
            defaultValue: false,
          ) ??
          false,
      generationIntervalSeconds: generationIntervalSeconds,
    );
  }

  Future<void> setProtectionMode(bool value) async {
    state = state.copyWith(protectionMode: value);
    await _storage.setSetting(StorageKeys.protectionMode, value);
    await _storage.setSetting(StorageKeys.assetProtectionMode, value);
  }

  Future<void> setStripMetadataForCopyAndDrag(bool value) async {
    state = state.copyWith(stripMetadataForCopyAndDrag: value);
    await _storage.setSetting(StorageKeys.shareStripMetadata, value);
  }

  Future<void> setConfirmDangerousActions(bool value) async {
    state = state.copyWith(confirmDangerousActions: value);
    await _storage.setSetting(
      StorageKeys.protectionConfirmDangerousActions,
      value,
    );
  }

  Future<void> setWarnExternalImageSend(bool value) async {
    state = state.copyWith(warnExternalImageSend: value);
    await _storage.setSetting(
      StorageKeys.protectionWarnExternalImageSend,
      value,
    );
  }

  Future<void> setPreventOverwrite(bool value) async {
    state = state.copyWith(preventOverwrite: value);
    await _storage.setSetting(StorageKeys.protectionPreventOverwrite, value);
  }

  Future<void> setWarnHighAnlasCost(bool value) async {
    state = state.copyWith(warnHighAnlasCost: value);
    await _storage.setSetting(StorageKeys.protectionWarnHighAnlasCost, value);
  }

  Future<void> setHighAnlasCostThreshold(int value) async {
    final clamped = value.clamp(1, 9999).toInt();
    state = state.copyWith(highAnlasCostThreshold: clamped);
    await _storage.setSetting(
      StorageKeys.protectionHighAnlasCostThreshold,
      clamped,
    );
  }

  Future<void> setLimitGenerationInterval(bool value) async {
    state = state.copyWith(limitGenerationInterval: value);
    await _storage.setSetting(
      StorageKeys.protectionLimitGenerationInterval,
      value,
    );
  }

  Future<void> setGenerationIntervalSeconds(int value) async {
    final clamped = value.clamp(1, 3600).toInt();
    state = state.copyWith(generationIntervalSeconds: clamped);
    await _storage.setSetting(
      StorageKeys.protectionGenerationIntervalSeconds,
      clamped,
    );
  }
}
