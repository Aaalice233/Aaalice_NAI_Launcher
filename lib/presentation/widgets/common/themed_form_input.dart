import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'input_surface_container.dart';

/// 带表单验证的统一样式输入框组件
///
/// 使用共享深色填充与清晰、无发光的聚焦和错误轮廓。
/// 支持 [validator] 验证功能和错误提示显示。
class ThemedFormInput extends StatefulWidget {
  /// 文本控制器
  final TextEditingController? controller;

  /// 焦点节点
  final FocusNode? focusNode;

  /// 提示文字
  final String? hintText;

  /// 标签文字
  final String? labelText;

  /// 帮助文字（显示在输入框下方）
  final String? helperText;

  /// 最大行数，null表示无限制
  final int? maxLines;

  /// 最小行数
  final int minLines;

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

  /// 表单字段提交回调
  final ValueChanged<String>? onFieldSubmitted;

  /// 保存回调
  final FormFieldSetter<String>? onSaved;

  /// 验证器
  final FormFieldValidator<String>? validator;

  /// 自动验证模式
  final AutovalidateMode? autovalidateMode;

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

  /// 初始值；未传 [controller] 时作为输入内容，之后的外部更新在输入框未聚焦时同步
  final String? initialValue;

  /// 文本对齐方式
  final TextAlign textAlign;

  /// 垂直对齐方式
  final TextAlignVertical? textAlignVertical;

  /// 光标颜色
  final Color? cursorColor;

  /// 点击输入框外部时的回调
  final TapRegionCallback? onTapOutside;

  /// 额外的 InputDecoration，非空属性覆盖同名参数
  ///
  /// 边框、填充与启用状态由组件负责；帮助、错误与计数显示在输入框下方，
  /// [validator] 的错误优先于 [InputDecoration.errorText]。
  final InputDecoration? decoration;

  const ThemedFormInput({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.labelText,
    this.helperText,
    this.maxLines = 1,
    this.minLines = 1,
    this.expands = false,
    this.textInputAction,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.onFieldSubmitted,
    this.onSaved,
    this.validator,
    this.autovalidateMode,
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
    this.initialValue,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.cursorColor,
    this.onTapOutside,
    this.decoration,
  });

  /// 创建多行输入框
  const ThemedFormInput.multiline({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.labelText,
    this.helperText,
    this.maxLines,
    this.minLines = 3,
    this.expands = false,
    this.textInputAction,
    this.keyboardType = TextInputType.multiline,
    this.onChanged,
    this.onSubmitted,
    this.onFieldSubmitted,
    this.onSaved,
    this.validator,
    this.autovalidateMode,
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
    this.initialValue,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.cursorColor,
    this.onTapOutside,
    this.decoration,
  });

  @override
  State<ThemedFormInput> createState() => _ThemedFormInputState();
}

class _ThemedFormInputState extends State<ThemedFormInput> {
  static const double _supportingGap = 4;
  static const double _counterGap = 8;

  TextEditingController? _ownedController;
  late String _observedText;
  bool _editing = false;
  bool _initialValueChangedWhileEditing = false;

  TextEditingController get _controller =>
      widget.controller ?? _ownedController!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _ownedController = TextEditingController(text: widget.initialValue);
    }
    _observedText = _controller.text;
    _controller.addListener(_handleTextChanged);
  }

  @override
  void didUpdateWidget(ThemedFormInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      final previous = oldWidget.controller ?? _ownedController!;
      previous.removeListener(_handleTextChanged);
      if (widget.controller == null) {
        _ownedController = TextEditingController.fromValue(previous.value);
      } else {
        _ownedController?.dispose();
        _ownedController = null;
      }
      _observedText = _controller.text;
      _controller.addListener(_handleTextChanged);
    } else if (widget.controller == null &&
        widget.initialValue != oldWidget.initialValue) {
      if (_editing) {
        _initialValueChangedWhileEditing = true;
      } else {
        _showInitialValue();
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _ownedController?.dispose();
    super.dispose();
  }

  // 编辑中不覆盖：调用方常把输入规整后回传（如去掉末尾逗号），实时写回会吞掉正在输入的字符
  void _handleFocusChange(bool focused) {
    _editing = focused;
    if (focused || !_initialValueChangedWhileEditing) return;
    _initialValueChangedWhileEditing = false;
    if (widget.controller == null) _showInitialValue();
  }

  void _showInitialValue() {
    final value = widget.initialValue ?? '';
    if (_controller.text != value) _controller.text = value;
  }

  // 程序写入的内容不经过 onChanged，需要重建才能让自动校验读到新内容
  void _handleTextChanged() {
    if (_controller.text == _observedText) return;
    _observedText = _controller.text;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final decoration = widget.decoration ?? const InputDecoration();
    final contentPadding = decoration.contentPadding ?? widget.contentPadding;

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: _handleFocusChange,
      child: Builder(
        builder: (focusContext) {
          final hasFocus = Focus.of(focusContext).hasFocus;
          final validator = widget.validator;
          final onSaved = widget.onSaved;
          return FormField<String>(
            initialValue: _controller.text,
            validator: validator == null
                ? null
                : (_) => validator(_controller.text),
            autovalidateMode:
                widget.autovalidateMode ?? AutovalidateMode.disabled,
            onSaved: onSaved == null ? null : (_) => onSaved(_controller.text),
            builder: (field) => _buildField(
              context,
              field: field,
              decoration: decoration,
              contentPadding: contentPadding,
              hasFocus: hasFocus,
            ),
          );
        },
      ),
    );
  }

  Widget _buildField(
    BuildContext context, {
    required FormFieldState<String> field,
    required InputDecoration decoration,
    required EdgeInsetsGeometry contentPadding,
    required bool hasFocus,
  }) {
    final theme = Theme.of(context);
    final message = _buildMessage(theme, field.errorText, decoration);
    final counter = _buildCounter(theme, decoration);
    final inset = contentPadding.resolve(Directionality.of(context));

    // 恒用 Column 包裹：错误出现或消失时输入框不重建，焦点与输入法连接不中断
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InputSurfaceContainer(
          borderRadius: widget.borderRadius,
          enabled: widget.enabled,
          hasError:
              field.hasError ||
              decoration.error != null ||
              decoration.errorText != null,
          isFocused: hasFocus,
          child: _buildTextField(field, decoration, contentPadding),
        ),
        if (message != null || counter != null) ...[
          const SizedBox(height: _supportingGap),
          Padding(
            padding: EdgeInsets.only(left: inset.left, right: inset.right),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: message ?? const SizedBox.shrink()),
                if (counter != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: _counterGap,
                    ),
                    child: counter,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  TextField _buildTextField(
    FormFieldState<String> field,
    InputDecoration decoration,
    EdgeInsetsGeometry contentPadding,
  ) {
    return TextField(
      controller: _controller,
      focusNode: widget.focusNode,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      expands: widget.expands,
      textInputAction: widget.textInputAction,
      keyboardType: widget.keyboardType,
      onChanged: (value) {
        field.didChange(value);
        widget.onChanged?.call(value);
      },
      onSubmitted: (value) {
        widget.onSubmitted?.call(value);
        widget.onFieldSubmitted?.call(value);
      },
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
      textAlignVertical:
          widget.textAlignVertical ??
          (widget.maxLines == 1 && !widget.expands
              ? TextAlignVertical.center
              : null),
      cursorColor: widget.cursorColor,
      decoration: _fieldDecoration(decoration, contentPadding),
    );
  }

  // 与 ThemedInput 一致由 decoration 优先：contentPadding 带默认值，无法判断参数是否显式传入
  InputDecoration _fieldDecoration(
    InputDecoration decoration,
    EdgeInsetsGeometry contentPadding,
  ) {
    final hasLabel = decoration.label != null || decoration.labelText != null;
    final hasHint = decoration.hint != null || decoration.hintText != null;
    return InputDecoration(
      icon: decoration.icon,
      iconColor: decoration.iconColor,
      label: decoration.label,
      labelText: hasLabel ? decoration.labelText : widget.labelText,
      labelStyle: decoration.labelStyle,
      floatingLabelStyle: decoration.floatingLabelStyle,
      hint: decoration.hint,
      hintText: hasHint ? decoration.hintText : widget.hintText,
      hintStyle: decoration.hintStyle ?? widget.hintStyle,
      hintTextDirection: decoration.hintTextDirection,
      hintMaxLines: decoration.hintMaxLines,
      hintFadeDuration: decoration.hintFadeDuration,
      maintainHintSize: decoration.maintainHintSize,
      maintainLabelSize: decoration.maintainLabelSize,
      floatingLabelBehavior: decoration.floatingLabelBehavior,
      floatingLabelAlignment: decoration.floatingLabelAlignment,
      isCollapsed: decoration.isCollapsed,
      isDense: decoration.isDense ?? true,
      contentPadding: contentPadding,
      prefixIcon: decoration.prefixIcon ?? widget.prefixIcon,
      prefixIconConstraints: decoration.prefixIconConstraints,
      prefix: decoration.prefix,
      prefixText: decoration.prefixText,
      prefixStyle: decoration.prefixStyle,
      prefixIconColor: decoration.prefixIconColor,
      suffixIcon: decoration.suffixIcon ?? widget.suffixIcon,
      suffix: decoration.suffix,
      suffixText: decoration.suffixText,
      suffixStyle: decoration.suffixStyle,
      suffixIconColor: decoration.suffixIconColor,
      suffixIconConstraints: decoration.suffixIconConstraints,
      counterText: '',
      filled: false,
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
      disabledBorder: InputBorder.none,
      errorBorder: InputBorder.none,
      focusedErrorBorder: InputBorder.none,
      alignLabelWithHint: decoration.alignLabelWithHint,
      constraints: decoration.constraints,
      visualDensity: decoration.visualDensity,
    );
  }

  Widget? _buildMessage(
    ThemeData theme,
    String? validatorError,
    InputDecoration decoration,
  ) {
    final base = theme.textTheme.bodySmall;
    if (validatorError != null ||
        decoration.error != null ||
        decoration.errorText != null) {
      final style = base
          ?.copyWith(color: theme.colorScheme.error)
          .merge(decoration.errorStyle);
      if (validatorError == null && decoration.error != null) {
        return DefaultTextStyle.merge(style: style, child: decoration.error!);
      }
      return _supportingText(
        validatorError ?? decoration.errorText!,
        style,
        decoration.errorMaxLines,
      );
    }

    final style = base
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)
        .merge(decoration.helperStyle);
    if (decoration.helper != null) {
      return DefaultTextStyle.merge(style: style, child: decoration.helper!);
    }
    final helperText = decoration.helperText ?? widget.helperText;
    if (helperText == null) return null;
    return _supportingText(helperText, style, decoration.helperMaxLines);
  }

  Text _supportingText(String text, TextStyle? style, int? maxLines) {
    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );
  }

  Widget? _buildCounter(ThemeData theme, InputDecoration decoration) {
    final style = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)
        .merge(decoration.counterStyle);
    if (decoration.counter != null) {
      return DefaultTextStyle.merge(style: style, child: decoration.counter!);
    }
    final counterText = decoration.counterText;
    if (counterText == null || counterText.isEmpty) return null;
    return Text(
      counterText,
      style: style,
      semanticsLabel: decoration.semanticCounterText,
    );
  }
}
