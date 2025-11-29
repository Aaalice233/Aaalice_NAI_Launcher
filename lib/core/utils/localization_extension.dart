import 'package:flutter/widgets.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

/// BuildContext 扩展，简化多语言调用
/// 
/// 使用示例：
/// ```dart
/// Text(context.l10n.settings)
/// ```
extension LocalizationExtension on BuildContext {
  /// 获取当前语言环境的 AppLocalizations 实例
  AppLocalizations get l10n => AppLocalizations.of(this)!;
}

