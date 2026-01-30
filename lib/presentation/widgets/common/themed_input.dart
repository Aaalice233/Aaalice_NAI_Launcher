import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'inset_shadow_container.dart';
import 'themed_confirm_dialog.dart';

/// 统一样式的输入框组件
///
/// 使用 [InsetShadowContainer] 包装，提供立体感效果。
/// 支持单行和多行模式，统一圆角和样式。
class ThemedInput extends StatefulWidget {
  /// 文本控制器
  final TextEditingController? controller;

  /// 焦点节点
  final FocusNode? focusNode;

  /// 提示文字
  final String? hintText;

  /// 帮助文字（显示在输入框下方）
  final String? helperText;

  /// 最大行数，null表示无限制
  final int? maxLines;

  /// 最小行数（当 expands 为 true 时必须为 null）
  final int? minLines;

  /// 是否自动扩展
  final bool expands;

  /// 键盘操作类型
  final TextInputAction? textInputAction;

  /// 输入类型
  final TextInputType? keyboardType;

  /// 文本变化回调
  final ValueChanged<String>? onChanged;

  /// 提交回调
  final ValueChanged<String>? onSubmitted;

  /// 是否只读
  final bool readOnly;

  /// 是否启用
  final bool enabled;

  /// 圆角半径
  final double borderRadius;

  /// 内边距
  final EdgeInsetsGeometry contentPadding;

  /// 输入格式化器
  final List<TextInputFormatter>? inputFormatters;

  /// 前缀图标
  final Widget? prefixIcon;

  /// 后缀图标
  final Widget? suffixIcon;

  /// 是否遮挡文本（密码输入）
  final bool obscureText;

  /// 最大字符数
  final int? maxLength;

  /// 文本样式
  final TextStyle? style;

  /// 提示文字样式
  final TextStyle? hintStyle;

  /// 是否自动获取焦点
  final bool autofocus;

  /// 点击回调
  final GestureTapCallback? onTap;

  /// 编辑完成回调
  final VoidCallback? onEditingComplete;

  /// 文本对齐方式
  final TextAlign textAlign;

  /// 垂直对齐方式
  final TextAlignVertical? textAlignVertical;

  /// 光标颜色
  final Color? cursorColor;

  /// 点击输入框外部时的回调
  final TapRegionCallback? onTapOutside;

  /// 额外的 InputDecoration（会与默认配置合并）
  /// 用于兼容需要额外装饰属性的场景
  final InputDecoration? decoration;

  /// 是否显示清空按钮（有内容时才显示）
  final bool showClearButton;

  /// 清空按钮回调（可选，不提供则自动清空 controller）
  final VoidCallback? onClearPressed;

  /// 清空前是否需要确认对话框
  final bool clearNeedsConfirm;

  /// 是否启用撤回/重做功能
  final bool enableUndoRedo;

  const ThemedInput({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.helperText,
    this.maxLines = 1,
    this.minLines,
    this.expands = false,
    this.textInputAction,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.readOnly = false,
    this.enabled = true,
    this.borderRadius = 8.0,
    this.contentPadding = const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 10,
    ),
    this.inputFormatters,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.maxLength,
    this.style,
    this.hintStyle,
    this.autofocus = false,
    this.onTap,
    this.onEditingComplete,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.cursorColor,
    this.onTapOutside,
    this.decoration,
    this.showClearButton = false,
    this.onClearPressed,
    this.clearNeedsConfirm = false,
    this.enableUndoRedo = false,
  });

  /// 创建多行输入框
  const ThemedInput.multiline({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.helperText,
    this.maxLines,
    this.minLines = 3,
    this.expands = false,
    this.textInputAction,
    this.keyboardType = TextInputType.multiline,
    this.onChanged,
    this.onSubmitted,
    this.readOnly = false,
    this.enabled = true,
    this.borderRadius = 8.0,
    this.contentPadding = const EdgeInsets.all(12),
    this.inputFormatters,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.maxLength,
    this.style,
    this.hintStyle,
    this.autofocus = false,
    this.onTap,
    this.onEditingComplete,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.cursorColor,
    this.onTapOutside,
    this.decoration,
    this.showClearButton = false,
    this.onClearPressed,
    this.clearNeedsConfirm = false,
    this.enableUndoRedo = false,
  });

  @override
  State<ThemedInput> createState() => _ThemedInputState();
}

class _ThemedInputState extends State<ThemedInput> {
  late TextEditingController _effectiveController;
  UndoHistoryController? _undoController;
  bool _hasContent = false;

  @override
  void initState() {
    super.initState();
    _effectiveController = widget.controller ?? TextEditingController();
    _hasContent = _effectiveController.text.isNotEmpty;
    if (widget.showClearButton) {
      _effectiveController.addListener(_onTextChanged);
    }
    if (widget.enableUndoRedo) {
      _undoController = UndoHistoryController();
    }
  }

  @override
  void didUpdateWidget(ThemedInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      if (oldWidget.showClearButton && oldWidget.controller == null) {
        _effectiveController.removeListener(_onTextChanged);
        _effectiveController.dispose();
      } else if (oldWidget.showClearButton) {
        oldWidget.controller?.removeListener(_onTextChanged);
      }
      _effectiveController = widget.controller ?? TextEditingController();
      _hasContent = _effectiveController.text.isNotEmpty;
      if (widget.showClearButton) {
        _effectiveController.addListener(_onTextChanged);
      }
    }
    // 处理 enableUndoRedo 变化
    if (widget.enableUndoRedo != oldWidget.enableUndoRedo) {
      if (widget.enableUndoRedo && _undoController == null) {
        _undoController = UndoHistoryController();
      } else if (!widget.enableUndoRedo && _undoController != null) {
        _undoController!.dispose();
        _undoController = null;
      }
    }
  }

  @override
  void dispose() {
    if (widget.showClearButton) {
      _effectiveController.removeListener(_onTextChanged);
    }
    if (widget.controller == null) {
      _effectiveController.dispose();
    }
    _undoController?.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasContent = _effectiveController.text.isNotEmpty;
    if (_hasContent != hasContent) {
      setState(() {
        _hasContent = hasContent;
      });
    }
  }

  Future<void> _handleClear() async {
    // 如果需要确认，显示对话框
    if (widget.clearNeedsConfirm) {
      final confirmed = await ThemedConfirmDialog.show(
        context: context,
        title: '清空确认',
        content: '确定要清空输入内容吗？',
        confirmText: '清空',
        type: ThemedConfirmDialogType.warning,
        icon: Icons.clear_all,
      );
      if (!confirmed) return;
    }

    if (widget.onClearPressed != null) {
      // 如果提供了回调，让回调负责清空逻辑
      widget.onClearPressed!();
    } else {
      // 否则自己清空
      _effectiveController.clear();
      widget.onChanged?.call('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 构建基础 InputDecoration
    var inputDecoration = InputDecoration(
      hintText: widget.hintText,
      hintStyle: widget.hintStyle,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      contentPadding: widget.contentPadding,
      prefixIcon: widget.prefixIcon,
      suffixIcon: widget.suffixIcon,
      isDense: true,
      counterText: '', // 隐藏字符计数
    );

    // 如果提供了额外的 decoration，合并属性
    if (widget.decoration != null) {
      inputDecoration = inputDecoration.copyWith(
        labelText: widget.decoration!.labelText,
        labelStyle: widget.decoration!.labelStyle,
        floatingLabelStyle: widget.decoration!.floatingLabelStyle,
        helperText: widget.decoration!.helperText,
        helperStyle: widget.decoration!.helperStyle,
        errorText: widget.decoration!.errorText,
        errorStyle: widget.decoration!.errorStyle,
        prefix: widget.decoration!.prefix,
        prefixText: widget.decoration!.prefixText,
        prefixStyle: widget.decoration!.prefixStyle,
        suffix: widget.decoration!.suffix,
        suffixText: widget.decoration!.suffixText,
        suffixStyle: widget.decoration!.suffixStyle,
        counter: widget.decoration!.counter,
        counterStyle: widget.decoration!.counterStyle,
        filled: widget.decoration!.filled,
        fillColor: widget.decoration!.fillColor,
      );
    }

    final textField = TextField(
      controller: _effectiveController,
      focusNode: widget.focusNode,
      undoController: _undoController,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      expands: widget.expands,
      textInputAction: widget.textInputAction,
      keyboardType: widget.keyboardType,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      onTap: widget.onTap,
      onEditingComplete: widget.onEditingComplete,
      onTapOutside: widget.onTapOutside,
      readOnly: widget.readOnly,
      enabled: widget.enabled,
      inputFormatters: widget.inputFormatters,
      obscureText: widget.obscureText,
      maxLength: widget.maxLength,
      style: widget.style,
      autofocus: widget.autofocus,
      textAlign: widget.textAlign,
      textAlignVertical: widget.textAlignVertical,
      cursorColor: widget.cursorColor,
      decoration: inputDecoration,
    );

    Widget content = textField;

    // 如果需要显示清空按钮，使用 Stack 包装
    if (widget.showClearButton && _hasContent) {
      content = Stack(
        children: [
          textField,
          Positioned(
            top: 4,
            right: 4,
            child: _ClearButton(onPressed: _handleClear),
          ),
        ],
      );
    }

    final container = InsetShadowContainer(
      borderRadius: widget.borderRadius,
      enabled: widget.enabled ? null : false,
      child: content,
    );

    // 如果有帮助文字，添加在下方
    if (widget.helperText != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          container,
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              widget.helperText!,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ],
      );
    }

    return container;
  }
}

/// 清空按钮组件
class _ClearButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _ClearButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest.withOpacity(0.8),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            Icons.close,
            size: 14,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
