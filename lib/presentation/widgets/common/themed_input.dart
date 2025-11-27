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
    
    // 根据主题调整 InputBorder
    // 虽然 Theme 已经定义了 inputDecorationTheme，但在某些特殊风格 (如 Linear) 可能需要局部调整
    
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      minLines: minLines,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      autofocus: autofocus,
      style: extension?.usePixelFont == true 
          ? const TextStyle(fontFamily: 'monospace', letterSpacing: 1.0) 
          : null,
      decoration: InputDecoration(
        hintText: hintText,
        labelText: labelText,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
        // Linear 风格下可能需要更细的边框，或者无背景
        filled: extension?.blurStrength != null && extension!.blurStrength > 0 ? true : null,
        fillColor: extension?.blurStrength != null && extension!.blurStrength > 0 
            ? theme.colorScheme.surface.withOpacity(0.3) 
            : null,
      ),
    );
  }
}

