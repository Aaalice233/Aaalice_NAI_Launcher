import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/shortcuts/shortcut_config.dart';
import '../../../core/shortcuts/shortcut_manager.dart';
import '../../../core/utils/localization_extension.dart';
import '../../adaptive/interaction_policy.dart';
import '../../providers/shortcuts_provider.dart';

/// 快捷键绑定编辑器
/// 用于编辑单个快捷键的绑定
class ShortcutBindingEditor extends ConsumerStatefulWidget {
  /// 快捷键绑定
  final ShortcutBinding binding;

  /// 保存回调
  final ValueChanged<ShortcutBinding>? onSave;

  /// 取消回调
  final VoidCallback? onCancel;

  /// 是否内联显示（较小尺寸）
  final bool inline;

  const ShortcutBindingEditor({
    super.key,
    required this.binding,
    this.onSave,
    this.onCancel,
    this.inline = false,
  });

  @override
  ConsumerState<ShortcutBindingEditor> createState() =>
      _ShortcutBindingEditorState();
}

class _ShortcutBindingEditorState extends ConsumerState<ShortcutBindingEditor> {
  late TextEditingController _controller;
  bool _isRecording = false;
  String? _conflictId;
  Set<LogicalKeyboardKey> _pressedKeys = {};
  final FocusNode _recordingFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.binding.effectiveShortcut);
  }

  @override
  void dispose() {
    _recordingFocusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.inline) {
      return _buildInlineEditor(theme);
    }

    return _buildFullEditor(theme);
  }

  Widget _buildInlineEditor(ThemeData theme) {
    final l10n = context.l10n;
    final controlExtent = context.interactionPolicy.minimumControlExtent;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // 快捷键显示/输入
        GestureDetector(
          onTap: _isRecording ? null : _startRecording,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _isRecording
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _isRecording
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline.withValues(alpha: 0.3),
              ),
            ),
            child: _isRecording
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.shortcut_editor_recordingInline,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  )
                : Text(
                    _controller.text.isEmpty
                        ? l10n.shortcut_settings_unassigned
                        : _controller.text,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: widget.binding.hasCustomShortcut
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
          ),
        ),

        // 操作按钮
        if (widget.binding.hasCustomShortcut) ...[
          IconButton(
            icon: const Icon(Icons.refresh, size: 16),
            tooltip: l10n.shortcut_settings_reset_to_default,
            visualDensity: VisualDensity.compact,
            constraints: BoxConstraints.tightFor(
              width: controlExtent,
              height: controlExtent,
            ),
            onPressed: _resetToDefault,
          ),
        ],
        if (_controller.text.isNotEmpty) ...[
          IconButton(
            icon: const Icon(Icons.clear, size: 16),
            tooltip: l10n.common_clear,
            visualDensity: VisualDensity.compact,
            constraints: BoxConstraints.tightFor(
              width: controlExtent,
              height: controlExtent,
            ),
            onPressed: _clear,
          ),
        ],
      ],
    );
  }

  Widget _buildFullEditor(ThemeData theme) {
    final l10n = context.l10n;

    return Focus(
      focusNode: _recordingFocusNode,
      autofocus: true,
      onKeyEvent: _isRecording ? _handleKeyEvent : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 快捷键输入区域
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _isRecording
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isRecording
                    ? theme.colorScheme.primary
                    : _conflictId != null
                    ? theme.colorScheme.error
                    : theme.colorScheme.outline.withValues(alpha: 0.3),
                width: _isRecording || _conflictId != null ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                // 显示区域
                GestureDetector(
                  onTap: _isRecording ? null : _startRecording,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: _isRecording
                          ? Column(
                              children: [
                                SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  l10n.shortcut_settings_press_key,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.shortcut_editor_pressEscToCancel,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ],
                            )
                          : _controller.text.isEmpty
                          ? Text(
                              l10n.shortcut_editor_clickToRecord,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            )
                          : Text(
                              AppShortcutManager.getDisplayLabel(
                                _controller.text,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                                color: widget.binding.hasCustomShortcut
                                    ? theme.colorScheme.primary
                                    : theme.colorScheme.onSurface,
                              ),
                            ),
                    ),
                  ),
                ),

                // 冲突提示
                if (_conflictId != null)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber,
                          size: 16,
                          color: theme.colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.shortcut_editor_conflictWith(_conflictId!),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                if (widget.binding.hasCustomShortcut)
                  TextButton.icon(
                    onPressed: _resetToDefault,
                    icon: const Icon(Icons.refresh),
                    label: Text(l10n.shortcut_settings_reset_to_default),
                  ),
                TextButton(
                  onPressed: widget.onCancel,
                  child: Text(l10n.common_cancel),
                ),
                FilledButton(
                  onPressed: _conflictId == null && _canSave() ? _save : null,
                  child: Text(l10n.common_save),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _canSave() {
    return _controller.text != widget.binding.effectiveShortcut;
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _pressedKeys = {};
    });
    _recordingFocusNode.requestFocus();
  }

  void _stopRecording() {
    setState(() {
      _isRecording = false;
      _pressedKeys = {};
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (!_isRecording) return KeyEventResult.ignored;

    if (event is KeyDownEvent) {
      // Esc 取消录制
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        _stopRecording();
        return KeyEventResult.handled;
      }

      // 记录按键
      setState(() {
        _pressedKeys.add(event.logicalKey);
      });

      // 检查是否是有效的快捷键组合
      _processKeyCombination();

      return KeyEventResult.handled;
    } else if (event is KeyUpEvent) {
      // 按键释放时停止录制
      if (_pressedKeys.isNotEmpty) {
        _stopRecording();
      }
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  void _processKeyCombination() {
    // 解析当前按键组合
    final modifiers = <ShortcutModifier>{};
    ShortcutKey? mainKey;

    for (final key in _pressedKeys) {
      if (key == LogicalKeyboardKey.controlLeft ||
          key == LogicalKeyboardKey.controlRight) {
        modifiers.add(ShortcutModifier.control);
      } else if (key == LogicalKeyboardKey.altLeft ||
          key == LogicalKeyboardKey.altRight) {
        modifiers.add(ShortcutModifier.alt);
      } else if (key == LogicalKeyboardKey.shiftLeft ||
          key == LogicalKeyboardKey.shiftRight) {
        modifiers.add(ShortcutModifier.shift);
      } else if (key == LogicalKeyboardKey.metaLeft ||
          key == LogicalKeyboardKey.metaRight) {
        modifiers.add(ShortcutModifier.meta);
      } else {
        // 主键
        mainKey = _shortcutKeyFromLogical(key);
      }
    }

    // 需要至少一个修饰键和一个主键
    if (modifiers.isEmpty || mainKey == null) {
      // 允许单独的功能键
      if (mainKey != null) {
        final isFunctionKey =
            mainKey.logicalKey.startsWith('f') ||
            mainKey == ShortcutKey.escape ||
            mainKey == ShortcutKey.delete ||
            mainKey == ShortcutKey.space ||
            mainKey == ShortcutKey.enter ||
            mainKey == ShortcutKey.arrowup ||
            mainKey == ShortcutKey.arrowdown ||
            mainKey == ShortcutKey.arrowleft ||
            mainKey == ShortcutKey.arrowright;

        if (!isFunctionKey) return;
      } else {
        return;
      }
    }

    // 构建快捷键字符串
    final parts = <String>[];
    if (modifiers.contains(ShortcutModifier.control)) parts.add('ctrl');
    if (modifiers.contains(ShortcutModifier.alt)) parts.add('alt');
    if (modifiers.contains(ShortcutModifier.shift)) parts.add('shift');
    if (modifiers.contains(ShortcutModifier.meta)) parts.add('meta');
    parts.add(mainKey.logicalKey);

    final shortcutString = parts.join('+');

    // 检查冲突
    final conflicts = ref
        .read(shortcutConfigNotifierProvider.notifier)
        .findConflicts(
          shortcutString,
          context: widget.binding.context,
          excludeId: widget.binding.id,
        );

    setState(() {
      _controller.text = shortcutString;
      _conflictId = conflicts.isNotEmpty ? conflicts.first : null;
    });
  }

  ShortcutKey? _shortcutKeyFromLogical(LogicalKeyboardKey key) {
    // 字母键
    if (key == LogicalKeyboardKey.keyA) return ShortcutKey.keyA;
    if (key == LogicalKeyboardKey.keyB) return ShortcutKey.keyB;
    if (key == LogicalKeyboardKey.keyC) return ShortcutKey.keyC;
    if (key == LogicalKeyboardKey.keyD) return ShortcutKey.keyD;
    if (key == LogicalKeyboardKey.keyE) return ShortcutKey.keyE;
    if (key == LogicalKeyboardKey.keyF) return ShortcutKey.keyF;
    if (key == LogicalKeyboardKey.keyG) return ShortcutKey.keyG;
    if (key == LogicalKeyboardKey.keyH) return ShortcutKey.keyH;
    if (key == LogicalKeyboardKey.keyI) return ShortcutKey.keyI;
    if (key == LogicalKeyboardKey.keyJ) return ShortcutKey.keyJ;
    if (key == LogicalKeyboardKey.keyK) return ShortcutKey.keyK;
    if (key == LogicalKeyboardKey.keyL) return ShortcutKey.keyL;
    if (key == LogicalKeyboardKey.keyM) return ShortcutKey.keyM;
    if (key == LogicalKeyboardKey.keyN) return ShortcutKey.keyN;
    if (key == LogicalKeyboardKey.keyO) return ShortcutKey.keyO;
    if (key == LogicalKeyboardKey.keyP) return ShortcutKey.keyP;
    if (key == LogicalKeyboardKey.keyQ) return ShortcutKey.keyQ;
    if (key == LogicalKeyboardKey.keyR) return ShortcutKey.keyR;
    if (key == LogicalKeyboardKey.keyS) return ShortcutKey.keyS;
    if (key == LogicalKeyboardKey.keyT) return ShortcutKey.keyT;
    if (key == LogicalKeyboardKey.keyU) return ShortcutKey.keyU;
    if (key == LogicalKeyboardKey.keyV) return ShortcutKey.keyV;
    if (key == LogicalKeyboardKey.keyW) return ShortcutKey.keyW;
    if (key == LogicalKeyboardKey.keyX) return ShortcutKey.keyX;
    if (key == LogicalKeyboardKey.keyY) return ShortcutKey.keyY;
    if (key == LogicalKeyboardKey.keyZ) return ShortcutKey.keyZ;

    // 数字键
    if (key == LogicalKeyboardKey.digit0) return ShortcutKey.digit0;
    if (key == LogicalKeyboardKey.digit1) return ShortcutKey.digit1;
    if (key == LogicalKeyboardKey.digit2) return ShortcutKey.digit2;
    if (key == LogicalKeyboardKey.digit3) return ShortcutKey.digit3;
    if (key == LogicalKeyboardKey.digit4) return ShortcutKey.digit4;
    if (key == LogicalKeyboardKey.digit5) return ShortcutKey.digit5;
    if (key == LogicalKeyboardKey.digit6) return ShortcutKey.digit6;
    if (key == LogicalKeyboardKey.digit7) return ShortcutKey.digit7;
    if (key == LogicalKeyboardKey.digit8) return ShortcutKey.digit8;
    if (key == LogicalKeyboardKey.digit9) return ShortcutKey.digit9;

    // 功能键
    if (key == LogicalKeyboardKey.f1) return ShortcutKey.f1;
    if (key == LogicalKeyboardKey.f2) return ShortcutKey.f2;
    if (key == LogicalKeyboardKey.f3) return ShortcutKey.f3;
    if (key == LogicalKeyboardKey.f4) return ShortcutKey.f4;
    if (key == LogicalKeyboardKey.f5) return ShortcutKey.f5;
    if (key == LogicalKeyboardKey.f6) return ShortcutKey.f6;
    if (key == LogicalKeyboardKey.f7) return ShortcutKey.f7;
    if (key == LogicalKeyboardKey.f8) return ShortcutKey.f8;
    if (key == LogicalKeyboardKey.f9) return ShortcutKey.f9;
    if (key == LogicalKeyboardKey.f10) return ShortcutKey.f10;
    if (key == LogicalKeyboardKey.f11) return ShortcutKey.f11;
    if (key == LogicalKeyboardKey.f12) return ShortcutKey.f12;

    // 特殊键
    if (key == LogicalKeyboardKey.enter) return ShortcutKey.enter;
    if (key == LogicalKeyboardKey.escape) return ShortcutKey.escape;
    if (key == LogicalKeyboardKey.space) return ShortcutKey.space;
    if (key == LogicalKeyboardKey.tab) return ShortcutKey.tab;
    if (key == LogicalKeyboardKey.backspace) return ShortcutKey.backspace;
    if (key == LogicalKeyboardKey.delete) return ShortcutKey.delete;
    if (key == LogicalKeyboardKey.insert) return ShortcutKey.insert;
    if (key == LogicalKeyboardKey.home) return ShortcutKey.home;
    if (key == LogicalKeyboardKey.end) return ShortcutKey.end;
    if (key == LogicalKeyboardKey.pageUp) return ShortcutKey.pageup;
    if (key == LogicalKeyboardKey.pageDown) return ShortcutKey.pagedown;

    // 方向键
    if (key == LogicalKeyboardKey.arrowUp) return ShortcutKey.arrowup;
    if (key == LogicalKeyboardKey.arrowDown) return ShortcutKey.arrowdown;
    if (key == LogicalKeyboardKey.arrowLeft) return ShortcutKey.arrowleft;
    if (key == LogicalKeyboardKey.arrowRight) return ShortcutKey.arrowright;

    return null;
  }

  void _resetToDefault() {
    setState(() {
      _controller.text = widget.binding.defaultShortcut;
      _conflictId = null;
    });
    _save();
  }

  void _clear() {
    setState(() {
      _controller.clear();
      _conflictId = null;
    });
  }

  void _save() {
    final newBinding = widget.binding.copyWith(
      customShortcut: _controller.text.isEmpty ? null : _controller.text,
    );
    widget.onSave?.call(newBinding);
  }
}
