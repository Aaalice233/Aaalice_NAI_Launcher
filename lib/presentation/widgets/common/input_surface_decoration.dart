import 'package:flutter/material.dart';

/// 调用方装饰在共享输入色面上的呈现规则
///
/// 标签、提示、图标等交给色面内的 TextField，边框与填充由色面绘制，
/// 帮助、错误与计数排在色面下方。[decoration] 的非空属性覆盖同名参数。
class InputSurfaceDecoration {
  InputSurfaceDecoration(
    InputDecoration? decoration, {
    required EdgeInsetsGeometry contentPadding,
    this.labelText,
    this.hintText,
    this.hintStyle,
    this.prefixIcon,
    this.suffixIcon,
    this.helperText,
  }) : decoration = decoration ?? const InputDecoration(),
       // 与 decoration 其余属性同规则；参数带默认值，无法判断是否显式传入
       contentPadding = decoration?.contentPadding ?? contentPadding;

  final InputDecoration decoration;
  final EdgeInsetsGeometry contentPadding;
  final String? labelText;
  final String? hintText;
  final TextStyle? hintStyle;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? helperText;

  static const double _supportingGap = 4;
  static const double _counterGap = 8;

  /// 色面内 TextField 使用的装饰
  InputDecoration get fieldDecoration {
    final hasLabel = decoration.label != null || decoration.labelText != null;
    final hasHint = decoration.hint != null || decoration.hintText != null;
    return InputDecoration(
      icon: decoration.icon,
      iconColor: decoration.iconColor,
      label: decoration.label,
      labelText: hasLabel ? decoration.labelText : labelText,
      labelStyle: decoration.labelStyle,
      floatingLabelStyle: decoration.floatingLabelStyle,
      hint: decoration.hint,
      hintText: hasHint ? decoration.hintText : hintText,
      hintStyle: decoration.hintStyle ?? hintStyle,
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
      prefixIcon: decoration.prefixIcon ?? prefixIcon,
      prefixIconConstraints: decoration.prefixIconConstraints,
      prefix: decoration.prefix,
      prefixText: decoration.prefixText,
      prefixStyle: decoration.prefixStyle,
      prefixIconColor: decoration.prefixIconColor,
      suffixIcon: decoration.suffixIcon ?? suffixIcon,
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

  /// 是否处于错误状态；[validatorError] 来自表单校验
  bool hasError([String? validatorError]) =>
      validatorError != null ||
      decoration.error != null ||
      decoration.errorText != null;

  /// 色面下方的文字；没有可显示的内容时返回 null
  ///
  /// [validatorError] 优先于 [InputDecoration.errorText]，错误出现时隐藏帮助文字。
  Widget? supportingText([String? validatorError]) {
    final hasMessage =
        hasError(validatorError) ||
        decoration.helper != null ||
        (decoration.helperText ?? helperText) != null;
    final hasCounter =
        decoration.counter != null ||
        (decoration.counterText?.isNotEmpty ?? false);
    if (!hasMessage && !hasCounter) return null;
    return _InputSupportingText(
      surface: this,
      validatorError: validatorError,
      showMessage: hasMessage,
      showCounter: hasCounter,
    );
  }
}

class _InputSupportingText extends StatelessWidget {
  const _InputSupportingText({
    required this.surface,
    required this.validatorError,
    required this.showMessage,
    required this.showCounter,
  });

  final InputSurfaceDecoration surface;
  final String? validatorError;
  final bool showMessage;
  final bool showCounter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final inset = surface.contentPadding.resolve(Directionality.of(context));
    return Padding(
      padding: EdgeInsets.only(
        top: InputSurfaceDecoration._supportingGap,
        left: inset.left,
        right: inset.right,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: showMessage ? _buildMessage(theme) : const SizedBox.shrink(),
          ),
          if (showCounter)
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: InputSurfaceDecoration._counterGap,
              ),
              child: _buildCounter(theme),
            ),
        ],
      ),
    );
  }

  Widget _buildMessage(ThemeData theme) {
    final decoration = surface.decoration;
    final base = theme.textTheme.bodySmall;
    if (surface.hasError(validatorError)) {
      final style = base
          ?.copyWith(color: theme.colorScheme.error)
          .merge(decoration.errorStyle);
      if (validatorError == null && decoration.error != null) {
        return DefaultTextStyle.merge(style: style, child: decoration.error!);
      }
      return _text(
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
    return _text(
      decoration.helperText ?? surface.helperText!,
      style,
      decoration.helperMaxLines,
    );
  }

  Widget _buildCounter(ThemeData theme) {
    final decoration = surface.decoration;
    final style = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)
        .merge(decoration.counterStyle);
    if (decoration.counter != null) {
      return DefaultTextStyle.merge(style: style, child: decoration.counter!);
    }
    return Text(
      decoration.counterText!,
      style: style,
      semanticsLabel: decoration.semanticCounterText,
    );
  }

  Text _text(String text, TextStyle? style, int? maxLines) {
    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
    );
  }
}
