import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/storage/local_storage_service.dart';

/// 左侧面板模块显示控制状态
class WebPanelModulesState {
  const WebPanelModulesState({
    this.showCharacter = true,
    this.showPreciseReference = true,
    this.showVibeTransfer = true,
    this.showTagExtraction = true,
  });

  final bool showCharacter;
  final bool showPreciseReference;
  final bool showVibeTransfer;
  final bool showTagExtraction;

  WebPanelModulesState copyWith({
    bool? showCharacter,
    bool? showPreciseReference,
    bool? showVibeTransfer,
    bool? showTagExtraction,
  }) {
    return WebPanelModulesState(
      showCharacter: showCharacter ?? this.showCharacter,
      showPreciseReference: showPreciseReference ?? this.showPreciseReference,
      showVibeTransfer: showVibeTransfer ?? this.showVibeTransfer,
      showTagExtraction: showTagExtraction ?? this.showTagExtraction,
    );
  }
}

final webPanelModulesProvider =
    NotifierProvider<WebPanelModulesNotifier, WebPanelModulesState>(
      WebPanelModulesNotifier.new,
    );

class WebPanelModulesNotifier extends Notifier<WebPanelModulesState> {
  @override
  WebPanelModulesState build() {
    final storage = ref.watch(localStorageServiceProvider);
    return WebPanelModulesState(
      showCharacter:
          storage.getSetting<bool>(StorageKeys.webPanelShowCharacter) ?? true,
      showPreciseReference:
          storage.getSetting<bool>(StorageKeys.webPanelShowPreciseRef) ?? true,
      showVibeTransfer:
          storage.getSetting<bool>(StorageKeys.webPanelShowVibeTransfer) ?? true,
      showTagExtraction:
          storage.getSetting<bool>(StorageKeys.webPanelShowTagExtraction) ?? true,
    );
  }

  Future<void> toggleCharacter() async {
    final next = !state.showCharacter;
    await ref
        .read(localStorageServiceProvider)
        .setSetting(StorageKeys.webPanelShowCharacter, next);
    state = state.copyWith(showCharacter: next);
  }

  Future<void> togglePreciseReference() async {
    final next = !state.showPreciseReference;
    await ref
        .read(localStorageServiceProvider)
        .setSetting(StorageKeys.webPanelShowPreciseRef, next);
    state = state.copyWith(showPreciseReference: next);
  }

  Future<void> toggleVibeTransfer() async {
    final next = !state.showVibeTransfer;
    await ref
        .read(localStorageServiceProvider)
        .setSetting(StorageKeys.webPanelShowVibeTransfer, next);
    state = state.copyWith(showVibeTransfer: next);
  }

  Future<void> toggleTagExtraction() async {
    final next = !state.showTagExtraction;
    await ref
        .read(localStorageServiceProvider)
        .setSetting(StorageKeys.webPanelShowTagExtraction, next);
    state = state.copyWith(showTagExtraction: next);
  }
}
