import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/shortcuts/default_shortcuts.dart';
import '../../widgets/shortcuts/editable_text_focus.dart';
import '../../widgets/shortcuts/shortcut_aware_widget.dart';

/// 本地图库的按键层：批量撤销/重做、页面快捷键与卡片多选，需放在 CardSelectionScope 之内。
/// 撤销/重做是固定按键，不走快捷键配置，也不受快捷键总开关影响。
class LocalGalleryShortcuts extends StatefulWidget {
  const LocalGalleryShortcuts({
    super.key,
    required this.shortcuts,
    required this.canUndo,
    required this.canRedo,
    required this.onUndo,
    required this.onRedo,
    required this.child,
  });

  /// 页面快捷键动作映射，按用户配置分派
  final Map<String, VoidCallback> shortcuts;

  final bool canUndo;
  final bool canRedo;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final Widget child;

  @override
  State<LocalGalleryShortcuts> createState() => _LocalGalleryShortcutsState();
}

class _LocalGalleryShortcutsState extends State<LocalGalleryShortcuts> {
  late final Map<Type, Action<Intent>> _actions = {
    _UndoBulkOperationIntent:
        _BulkOperationHistoryAction<_UndoBulkOperationIntent>(
          canInvoke: () => widget.canUndo,
          onInvoke: () => widget.onUndo(),
        ),
    _RedoBulkOperationIntent:
        _BulkOperationHistoryAction<_RedoBulkOperationIntent>(
          canInvoke: () => widget.canRedo,
          onInvoke: () => widget.onRedo(),
        ),
  };

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: switch (defaultTargetPlatform) {
        TargetPlatform.macOS || TargetPlatform.iOS => _commandHistoryBindings,
        _ => _controlHistoryBindings,
      },
      child: Actions(
        actions: _actions,
        child: CardSelectionPageShortcuts(
          contextType: ShortcutContext.gallery,
          shortcuts: widget.shortcuts,
          child: widget.child,
        ),
      ),
    );
  }
}

const _commandHistoryBindings = <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.keyZ, meta: true, includeRepeats: false):
      _UndoBulkOperationIntent(),
  SingleActivator(
    LogicalKeyboardKey.keyZ,
    meta: true,
    shift: true,
    includeRepeats: false,
  ): _RedoBulkOperationIntent(),
};

const _controlHistoryBindings = <ShortcutActivator, Intent>{
  SingleActivator(
    LogicalKeyboardKey.keyZ,
    control: true,
    includeRepeats: false,
  ): _UndoBulkOperationIntent(),
  SingleActivator(
    LogicalKeyboardKey.keyZ,
    control: true,
    shift: true,
    includeRepeats: false,
  ): _RedoBulkOperationIntent(),
  SingleActivator(
    LogicalKeyboardKey.keyY,
    control: true,
    includeRepeats: false,
  ): _RedoBulkOperationIntent(),
};

class _UndoBulkOperationIntent extends Intent {
  const _UndoBulkOperationIntent();
}

class _RedoBulkOperationIntent extends Intent {
  const _RedoBulkOperationIntent();
}

class _BulkOperationHistoryAction<T extends Intent> extends Action<T> {
  _BulkOperationHistoryAction({
    required this.canInvoke,
    required this.onInvoke,
  });

  final bool Function() canInvoke;
  final VoidCallback onInvoke;

  // 停用时按键继续冒泡，输入框聚焦时才能落到文本自身的撤销/重做
  @override
  bool isEnabled(T intent) => canInvoke() && !isEditableTextFocused();

  @override
  Object? invoke(T intent) {
    onInvoke();
    return null;
  }
}
