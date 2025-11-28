import 'package:flutter/material.dart';
import '../../themes/theme_extension.dart';

class ThemedInput extends StatelessWidget {
  final TextEditingController? controller;
  final String? hintText;
  final String? labelText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int? maxLines;
  final int? minLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;

  const ThemedInput({
    super.key,
    this.controller,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
    this.minLines,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final extension = theme.extension<AppThemeExtension>();
    
    // 某些风格下的特殊处理
    final isDigital = extension?.interactionStyle == AppInteractionStyle.digital;
    
    // 对于 Linear 风格 (blurStrength > 0)，我们使用特殊的填充和背景
    final isBlurry = extension?.blurStrength != null && extension!.blurStrength > 0;

    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      minLines: minLines,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      autofocus: autofocus,
      // 移除硬编码的 monospace，让全局 Theme 的 fontFamily 生效 (例如 VT323)
      // 但如果是 Digital 风格，我们可以增加字间距以模拟 LCD
      style: isDigital 
          ? const TextStyle(letterSpacing: 2.0, fontWeight: FontWeight.bold) 
          : null,
      cursorColor: theme.colorScheme.primary,
      decoration: InputDecoration(
        hintText: hintText,
        labelText: labelText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        // Linear 风格特殊背景
        filled: isBlurry ? true : null,
        fillColor: isBlurry 
            ? theme.colorScheme.surface.withOpacity(0.3) 
            : null,
        // Digital 风格特殊 Hint 样式
        hintStyle: isDigital 
            ? TextStyle(color: theme.colorScheme.primary.withOpacity(0.5), letterSpacing: 1.0)
            : null,
      ),
    );
  }
}
