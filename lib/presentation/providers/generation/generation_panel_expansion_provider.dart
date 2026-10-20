import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/utils/app_logger.dart';

/// 生图工作台顶层二级菜单。
///
/// 每个菜单使用独立存储键，新增菜单或旧配置损坏时不会影响其他菜单。
enum GenerationWorkbenchPanel {
  generationParameters,
  characters,
  reversePrompt,
  img2img,
  vibeTransfer,
  preciseReference,
}

extension GenerationWorkbenchPanelStorage on GenerationWorkbenchPanel {
  String get storageKey => switch (this) {
    GenerationWorkbenchPanel.generationParameters =>
      StorageKeys.generationParamsMenuExpanded,
    GenerationWorkbenchPanel.characters => StorageKeys.characterPanelExpanded,
    GenerationWorkbenchPanel.reversePrompt => StorageKeys.reversePromptExpanded,
    GenerationWorkbenchPanel.img2img => StorageKeys.img2imgExpanded,
    GenerationWorkbenchPanel.vibeTransfer => StorageKeys.vibeTransferExpanded,
    GenerationWorkbenchPanel.preciseReference => StorageKeys.preciseRefExpanded,
  };

  /// 旧版本没有可靠的顶层面板持久状态，统一从紧凑的收起状态开始。
  bool get defaultExpanded => false;
}

class GenerationPanelExpansionState {
  const GenerationPanelExpansionState(
    this._values, {
    this.manuallyClosed = const {},
  });

  final Map<GenerationWorkbenchPanel, bool> _values;
  final Set<GenerationWorkbenchPanel> manuallyClosed;

  bool isExpanded(GenerationWorkbenchPanel panel, {bool hasData = false}) {
    if (manuallyClosed.contains(panel)) {
      return false;
    }
    if (hasData) {
      return true;
    }
    return _values[panel] ?? panel.defaultExpanded;
  }

  GenerationPanelExpansionState copyWith(
    GenerationWorkbenchPanel panel,
    bool expanded,
  ) {
    final nextClosed = Set<GenerationWorkbenchPanel>.from(manuallyClosed);
    if (!expanded) {
      nextClosed.add(panel);
    } else {
      nextClosed.remove(panel);
    }
    return GenerationPanelExpansionState(
      Map.unmodifiable({..._values, panel: expanded}),
      manuallyClosed: Set.unmodifiable(nextClosed),
    );
  }
}

final generationPanelExpansionProvider =
    NotifierProvider<
      GenerationPanelExpansionNotifier,
      GenerationPanelExpansionState
    >(GenerationPanelExpansionNotifier.new);

class GenerationPanelExpansionNotifier
    extends Notifier<GenerationPanelExpansionState> {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  GenerationPanelExpansionState build() {
    return GenerationPanelExpansionState(
      Map.unmodifiable({
        for (final panel in GenerationWorkbenchPanel.values)
          panel: _readExpanded(panel),
      }),
    );
  }

  bool _readExpanded(GenerationWorkbenchPanel panel) {
    final value = _storage.getSetting<dynamic>(panel.storageKey);
    return value is bool ? value : panel.defaultExpanded;
  }

  Future<void> setExpanded(
    GenerationWorkbenchPanel panel,
    bool expanded, {
    bool resetManuallyClosed = false,
  }) async {
    final nextClosed = Set<GenerationWorkbenchPanel>.from(state.manuallyClosed);
    if (resetManuallyClosed) {
      nextClosed.remove(panel);
    } else if (!expanded) {
      nextClosed.add(panel);
    } else {
      nextClosed.remove(panel);
    }

    if (state.isExpanded(panel) == expanded &&
        state.manuallyClosed.contains(panel) == nextClosed.contains(panel)) {
      return;
    }

    state = GenerationPanelExpansionState(
      Map.unmodifiable({...state._values, panel: expanded}),
      manuallyClosed: Set.unmodifiable(nextClosed),
    );
    try {
      await _storage.setSetting(panel.storageKey, expanded);
    } catch (error, stackTrace) {
      AppLogger.e(
        'Failed to persist ${panel.name} panel expansion state',
        error,
        stackTrace,
        'GenerationPanelExpansion',
      );
    }
  }

  Future<void> toggle(GenerationWorkbenchPanel panel) {
    return setExpanded(panel, !state.isExpanded(panel));
  }
}
