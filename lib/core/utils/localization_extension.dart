import 'package:flutter/widgets.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

/// BuildContext 扩展，简化多语言调用
///
/// 使用示例：
/// ```dart
/// Text(context.l10n.settings)
/// ```
extension LocalizationExtension on BuildContext {
  /// 获取当前语言环境的 AppLocalizations 实例
  AppLocalizations get l10n => AppLocalizations.of(this)!;

  /// 获取 timeago 使用的本地化代码
  String get timeagoLocaleCode {
    switch (Localizations.localeOf(this).languageCode) {
      case 'zh':
        return 'zh';
      case 'ja':
        return 'ja';
      default:
        return 'en';
    }
  }

  /// 获取 Vibe 来源类型的本地化展示名称
  String vibeSourceTypeLabel(VibeSourceType sourceType) {
    switch (sourceType) {
      case VibeSourceType.png:
        return l10n.vibe_sourceType_png;
      case VibeSourceType.naiv4vibe:
        return l10n.vibe_sourceType_v4vibe;
      case VibeSourceType.naiv4vibebundle:
        return l10n.vibe_sourceType_bundle;
      case VibeSourceType.rawImage:
        return l10n.vibe_sourceType_image;
    }
  }
}
