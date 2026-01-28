import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/services/system_font_service.dart';
import '../../core/storage/local_storage_service.dart';

part 'font_provider.g.dart';

/// 字体来源类型
enum FontSource {
  system, // 系统字体
  google, // Google Fonts
}

/// 字体配置
class FontConfig {
  final String displayName; // 显示名称
  final String fontFamily; // 字体族名称
  final FontSource source; // 来源

  const FontConfig({
    required this.displayName,
    required this.fontFamily,
    required this.source,
  });

  /// 存储键
  String get key => '${source.name}:$fontFamily';

  /// 从键解析
  static FontConfig fromKey(String key) {
    if (key.isEmpty || key == 'system:') {
      return defaultFont;
    }
    final parts = key.split(':');
    if (parts.length >= 2) {
      final source =
          parts[0] == 'google' ? FontSource.google : FontSource.system;
      final fontFamily = parts.sublist(1).join(':'); // 处理字体名中包含冒号的情况
      return FontConfig(
        displayName: fontFamily,
        fontFamily: fontFamily,
        source: source,
      );
    }
    return defaultFont;
  }

  /// 默认字体（落霞孤鹜真楷 GB）
  static const defaultFont = FontConfig(
    displayName: '落霞孤鹜真楷',
    fontFamily: 'LXGW ZhenKai GB',
    source: FontSource.system,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FontConfig &&
          runtimeType == other.runtimeType &&
          fontFamily == other.fontFamily &&
          source == other.source;

  @override
  int get hashCode => fontFamily.hashCode ^ source.hashCode;
}

/// Google Fonts 预设列表
/// 注意：fontFamily 必须是 GoogleFonts.getFont() 能识别的名称格式
class GoogleFontPresets {
  static List<FontConfig> get all => [
        const FontConfig(
          displayName: '思源黑体',
          fontFamily: 'Noto Sans SC',
          source: FontSource.google,
        ),
        const FontConfig(
          displayName: '思源宋体',
          fontFamily: 'Noto Serif SC',
          source: FontSource.google,
        ),
        const FontConfig(
          displayName: '思源黑体港',
          fontFamily: 'Noto Sans HK',
          source: FontSource.google,
        ),
        const FontConfig(
          displayName: '思源等宽',
          fontFamily: 'Noto Sans Mono',
          source: FontSource.google,
        ),
        const FontConfig(
          displayName: '站酷小薇',
          fontFamily: 'ZCOOL XiaoWei',
          source: FontSource.google,
        ),
        const FontConfig(
          displayName: '站酷快乐',
          fontFamily: 'ZCOOL KuaiLe',
          source: FontSource.google,
        ),
        const FontConfig(
          displayName: '马善政楷书',
          fontFamily: 'Ma Shan Zheng',
          source: FontSource.google,
        ),
        const FontConfig(
          displayName: '龙藏体',
          fontFamily: 'Long Cang',
          source: FontSource.google,
        ),
        const FontConfig(
          displayName: '刘建毛草',
          fontFamily: 'Liu Jian Mao Cao',
          source: FontSource.google,
        ),
        const FontConfig(
          displayName: '志漫行',
          fontFamily: 'Zhi Mang Xing',
          source: FontSource.google,
        ),
        const FontConfig(
          displayName: '代码字体',
          fontFamily: 'Source Code Pro',
          source: FontSource.google,
        ),
        const FontConfig(
          displayName: '现代窄体',
          fontFamily: 'Saira Condensed',
          source: FontSource.google,
        ),
        const FontConfig(
          displayName: '古典衬线',
          fontFamily: 'Cinzel',
          source: FontSource.google,
        ),
        const FontConfig(
          displayName: '科幻风',
          fontFamily: 'Orbitron',
          source: FontSource.google,
        ),
        const FontConfig(
          displayName: '科技风',
          fontFamily: 'Rajdhani',
          source: FontSource.google,
        ),
      ];
}

/// 字体状态 Notifier
@riverpod
class FontNotifier extends _$FontNotifier {
  @override
  FontConfig build() {
    final storage = ref.read(localStorageServiceProvider);
    final fontKey = storage.getFontFamily();
    return FontConfig.fromKey(fontKey);
  }

  /// 设置字体
  Future<void> setFont(FontConfig font) async {
    state = font;
    final storage = ref.read(localStorageServiceProvider);
    await storage.setFontFamily(font.key);
  }
}

/// 系统字体列表 Provider（异步加载）
@riverpod
Future<List<FontConfig>> systemFontList(Ref ref) async {
  final service = ref.read(systemFontServiceProvider);
  final fonts = await service.getSystemFonts();

  // 转换为 FontConfig 列表
  final fontConfigs = fonts.map((name) {
    return FontConfig(
      displayName: name,
      fontFamily: name,
      source: FontSource.system,
    );
  }).toList();

  // 按名称排序
  fontConfigs.sort(
    (a, b) =>
        a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
  );

  return fontConfigs;
}

/// 所有可用字体列表 Provider
@riverpod
Future<Map<String, List<FontConfig>>> allFonts(Ref ref) async {
  final systemFonts = await ref.watch(systemFontListProvider.future);
  final googleFonts = GoogleFontPresets.all;

  return {
    '应用默认': [FontConfig.defaultFont],
    'Google Fonts': googleFonts,
    '系统字体': systemFonts,
  };
}
