import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/character/character_prompt.dart';
import '../../autocomplete/autocomplete_wrapper.dart';
import '../comfyui_import_wrapper.dart';
import '../nai_syntax_controller.dart';
import '../prompt_formatter_wrapper.dart';
import 'unified_prompt_config.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';

/// 文本撤回栈
///
/// 管理文本编辑历史，支持多步撤回和重做。
class _TextUndoStack {
  final List<String> _history = [];
  int _currentIndex = -1;
  
  /// 最大历史记录数
  static const int _maxHistory = 50;

  /// 防抖定时器
  Timer? _debounceTimer;

  /// 防抖延迟（毫秒）
  static const int _debounceMs = 500;

  /// 是否正在执行撤回/重做操作（避免循环记录）
  bool _isUndoRedoing = false;

  _TextUndoStack();

  /// 记录文本变化（带防抖）
  void record(String text) {
    if (_isUndoRedoing) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: _debounceMs), () {
      _recordImmediate(text);
    });
  }

  /// 立即记录文本（不防抖，用于清空等重要操作）
  void recordImmediate(String text) {
    if (_isUndoRedoing) return;
    _debounceTimer?.cancel();
    _recordImmediate(text);
  }

  void _recordImmediate(String text) {
    // 如果和当前状态相同，不记录
    if (_currentIndex >= 0 && _history[_currentIndex] == text) {
      return;
    }

    // 如果有重做历史，清除它们
    if (_currentIndex < _history.length - 1) {
      _history.removeRange(_currentIndex + 1, _history.length);
    }

    // 添加新记录
    _history.add(text);
    _currentIndex = _history.length - 1;

    // 限制历史长度
    while (_history.length > _maxHistory) {
      _history.removeAt(0);
      _currentIndex--;
    }
  }

  /// 撤回，返回撤回后的文本，如果无法撤回返回 null
  String? undo() {
    if (!canUndo) return null;

    _isUndoRedoing = true;
    _currentIndex--;
    final text = _history[_currentIndex];
    _isUndoRedoing = false;

    return text;
  }

  /// 重做，返回重做后的文本，如果无法重做返回 null
  String? redo() {
    if (!canRedo) return null;

    _isUndoRedoing = true;
    _currentIndex++;
    final text = _history[_currentIndex];
    _isUndoRedoing = false;

    return text;
  }

  /// 是否可以撤回
  bool get canUndo => _currentIndex > 0;

  /// 是否可以重做
  bool get canRedo => _currentIndex < _history.length - 1;

  /// 清空历史
  void clear() {
    _debounceTimer?.cancel();
    _history.clear();
    _currentIndex = -1;
  }

  /// 释放资源
  void dispose() {
    _debounceTimer?.cancel();
  }
}

/// 统一提示词输入组件
///
/// 文本输入组件，支持：
/// - 自动补全
/// - 语法高亮
/// - 自动格式化
///
/// 使用示例：
/// ```dart
/// UnifiedPromptInput(
///   config: UnifiedPromptConfig.characterEditor,
///   controller: _promptController,
///   onChanged: (text) => print('Text changed: $text'),
/// )
/// ```
class UnifiedPromptInput extends ConsumerStatefulWidget {
  /// 配置
  final UnifiedPromptConfig config;

  /// 外部文本控制器（可选）
  /// 如果提供，组件将使用此控制器并同步状态
  final TextEditingController? controller;

  /// 焦点节点（可选）
  final FocusNode? focusNode;

  /// 输入装饰
  final InputDecoration? decoration;

  /// 文本变化回调
  final ValueChanged<String>? onChanged;

  /// 提交回调（按 Enter 键时触发，不阻止 Shift+Enter 换行）
  final ValueChanged<String>? onSubmitted;

  /// 最大行数
  final int? maxLines;

  /// 最小行数
  final int? minLines;

  /// 是否扩展填满空间
  final bool expands;

  /// ComfyUI 多角色导入回调
  ///
  /// 当用户确认导入 ComfyUI 格式的多角色提示词时触发。
  /// [globalPrompt] 全局提示词，用于替换主输入框内容
  /// [characters] 角色列表，用于替换角色配置
  final void Function(String globalPrompt, List<CharacterPrompt> characters)?
      onComfyuiImport;

  const UnifiedPromptInput({
    super.key,
    this.config = const UnifiedPromptConfig(),
    this.controller,
    this.focusNode,
    this.decoration,
    this.onChanged,
    this.onSubmitted,
    this.maxLines,
    this.minLines,
    this.expands = false,
    this.onComfyuiImport,
  });

  @override
  ConsumerState<UnifiedPromptInput> createState() => _UnifiedPromptInputState();
}

class _UnifiedPromptInputState extends ConsumerState<UnifiedPromptInput> {
  /// 内部文本控制器（当未提供外部控制器时使用）
  TextEditingController? _internalController;

  /// 语法高亮控制器
  NaiSyntaxController? _syntaxController;

  /// 焦点节点
  FocusNode? _internalFocusNode;

  /// 撤回栈
  _TextUndoStack? _undoStack;

  /// 获取有效的文本控制器
  TextEditingController get _effectiveController {
    if (widget.config.enableSyntaxHighlight) {
      return _syntaxController!;
    }
    return widget.controller ?? _internalController!;
  }

  /// 获取有效的焦点节点
  FocusNode get _effectiveFocusNode {
    return widget.focusNode ?? _internalFocusNode!;
  }

  @override
  void initState() {
    super.initState();

    // 初始化内部控制器（如果需要）
    if (widget.controller == null) {
      _internalController = TextEditingController();
    }

    // 初始化语法高亮控制器
    if (widget.config.enableSyntaxHighlight) {
      final initialText = widget.controller?.text ?? '';
      _syntaxController = NaiSyntaxController(
        text: initialText,
        highlightEnabled: true,
      );
    }

    // 初始化焦点节点（如果需要）
    if (widget.focusNode == null) {
      _internalFocusNode = FocusNode();
    }

    // 初始化撤回栈
    if (widget.config.enableUndoRedo) {
      _undoStack = _TextUndoStack();
      // 记录初始状态
      final initialText = _effectiveController.text;
      if (initialText.isNotEmpty) {
        _undoStack!.recordImmediate(initialText);
      }
    }

    // 监听外部控制器变化
    widget.controller?.addListener(_syncFromExternalController);
  }

  @override
  void didUpdateWidget(UnifiedPromptInput oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 外部控制器变化
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_syncFromExternalController);
      widget.controller?.addListener(_syncFromExternalController);

      if (widget.controller == null && _internalController == null) {
        _internalController = TextEditingController();
      }

      _syncFromExternalController();
    }

    // 语法高亮配置变化
    if (widget.config.enableSyntaxHighlight !=
        oldWidget.config.enableSyntaxHighlight) {
      if (widget.config.enableSyntaxHighlight && _syntaxController == null) {
        _syntaxController = NaiSyntaxController(
          text: _effectiveController.text,
          highlightEnabled: true,
        );
      }
    }

    // 撤回功能配置变化
    if (widget.config.enableUndoRedo != oldWidget.config.enableUndoRedo) {
      if (widget.config.enableUndoRedo && _undoStack == null) {
        _undoStack = _TextUndoStack();
        final initialText = _effectiveController.text;
        if (initialText.isNotEmpty) {
          _undoStack!.recordImmediate(initialText);
        }
      } else if (!widget.config.enableUndoRedo && _undoStack != null) {
        _undoStack!.dispose();
        _undoStack = null;
      }
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_syncFromExternalController);
    _internalController?.dispose();
    _syntaxController?.dispose();
    _internalFocusNode?.dispose();
    _undoStack?.dispose();
    super.dispose();
  }

  /// 同步外部控制器变化到内部状态
  void _syncFromExternalController() {
    if (widget.controller == null) return;

    final externalText = widget.controller!.text;

    // 同步到语法高亮控制器
    if (_syntaxController != null && _syntaxController!.text != externalText) {
      _syntaxController!.text = externalText;
    }
  }

  /// 处理文本变化
  void _handleTextChanged(String text) {
    // 记录到撤回栈
    _undoStack?.record(text);

    // 同步到外部控制器
    if (widget.controller != null && widget.controller!.text != text) {
      widget.controller!.text = text;
    }

    // 触发回调
    widget.onChanged?.call(text);
  }

  /// 处理清空操作
  void _handleClear() {
    // 立即记录清空前的状态
    _undoStack?.recordImmediate(_effectiveController.text);

    _effectiveController.clear();
    // 同步到外部控制器
    if (widget.controller != null) {
      widget.controller!.clear();
    }

    // 记录清空后的状态
    _undoStack?.recordImmediate('');

    widget.onChanged?.call('');
    widget.config.onClearPressed?.call();
  }

  /// 执行撤回
  void _performUndo() {
    final text = _undoStack?.undo();
    if (text != null) {
      _effectiveController.text = text;
      if (widget.controller != null) {
        widget.controller!.text = text;
      }
      widget.onChanged?.call(text);
    }
  }

  /// 执行重做
  void _performRedo() {
    final text = _undoStack?.redo();
    if (text != null) {
      _effectiveController.text = text;
      if (widget.controller != null) {
        widget.controller!.text = text;
      }
      widget.onChanged?.call(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget result = _buildTextField();

    // 如果启用 ComfyUI 导入，包装 ComfyuiImportWrapper
    if (widget.config.enableComfyuiImport && widget.onComfyuiImport != null) {
      result = ComfyuiImportWrapper(
        controller: _effectiveController,
        enabled: !widget.config.readOnly,
        onImport: widget.onComfyuiImport,
        child: result,
      );
    }

    // 添加快捷键支持
    if (widget.config.enableUndoRedo && _undoStack != null) {
      result = Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            final isCtrlPressed = HardwareKeyboard.instance.isControlPressed;
            final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

            // Ctrl+Z: 撤回
            if (isCtrlPressed &&
                !isShiftPressed &&
                event.logicalKey == LogicalKeyboardKey.keyZ) {
              if (_undoStack!.canUndo) {
                _performUndo();
                return KeyEventResult.handled;
              }
            }

            // Ctrl+Shift+Z 或 Ctrl+Y: 重做
            if ((isCtrlPressed &&
                    isShiftPressed &&
                    event.logicalKey == LogicalKeyboardKey.keyZ) ||
                (isCtrlPressed &&
                    !isShiftPressed &&
                    event.logicalKey == LogicalKeyboardKey.keyY)) {
              if (_undoStack!.canRedo) {
                _performRedo();
                return KeyEventResult.handled;
              }
            }
          }
          return KeyEventResult.ignored;
        },
        child: result,
      );
    }

    return result;
  }

  /// 构建文本输入框
  Widget _buildTextField() {
    final effectiveDecoration = widget.decoration ??
        InputDecoration(
          hintText: widget.config.hintText,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        );

    // 构建基础 ThemedInput
    // 注意：当启用自动补全时，不要将 focusNode 传给 ThemedInput，
    // 因为 AutocompleteWrapper 会用 Focus 包装整个组件，
    // 如果两者都使用同一个 focusNode，会导致 "Tried to make a child into a parent of itself" 错误
    // 当禁用自动补全时，focusNode 需要传给 ThemedInput
    final baseInput = ThemedInput(
      controller: _effectiveController,
      focusNode: widget.config.enableAutocomplete ? null : _effectiveFocusNode,
      decoration: effectiveDecoration,
      maxLines: widget.expands ? null : widget.maxLines,
      minLines: widget.expands ? null : (widget.minLines ?? 1),
      expands: widget.expands,
      textAlignVertical: widget.expands ? TextAlignVertical.top : null,
      readOnly: widget.config.readOnly,
      onChanged: widget.config.enableAutocomplete ? null : _handleTextChanged,
      onSubmitted: widget.onSubmitted,
      showClearButton: widget.config.showClearButton,
      onClearPressed: widget.config.showClearButton ? _handleClear : null,
      clearNeedsConfirm: widget.config.clearNeedsConfirm,
      enableUndoRedo: false, // 禁用 ThemedInput 内置的撤回，使用自定义的
    );

    // 判断是否需要格式化功能
    final needsFormatting = widget.config.enableAutoFormat ||
        widget.config.enableSdSyntaxAutoConvert;

    // 如果启用自动补全，使用 AutocompleteWrapper 包装
    if (widget.config.enableAutocomplete) {
      Widget result = AutocompleteWrapper(
        controller: _effectiveController,
        focusNode: _effectiveFocusNode,
        config: widget.config.autocompleteConfig,
        enabled: !widget.config.readOnly,
        onChanged: _handleTextChanged,
        contentPadding: effectiveDecoration.contentPadding,
        maxLines: widget.maxLines,
        expands: widget.expands,
        child: baseInput,
      );

      // 如果需要格式化，外层再包装 PromptFormatterWrapper
      if (needsFormatting) {
        result = PromptFormatterWrapper(
          controller: _effectiveController,
          focusNode: _effectiveFocusNode,
          enableAutoFormat: widget.config.enableAutoFormat,
          enableSdSyntaxAutoConvert: widget.config.enableSdSyntaxAutoConvert,
          onChanged: _handleTextChanged,
          child: result,
        );
      }

      return result;
    }

    // 不启用自动补全，但需要格式化
    if (needsFormatting) {
      return PromptFormatterWrapper(
        controller: _effectiveController,
        focusNode: _effectiveFocusNode,
        enableAutoFormat: widget.config.enableAutoFormat,
        enableSdSyntaxAutoConvert: widget.config.enableSdSyntaxAutoConvert,
        onChanged: _handleTextChanged,
        child: baseInput,
      );
    }

    return baseInput;
  }
}
