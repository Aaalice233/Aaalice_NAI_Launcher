import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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

  /// 默认字体（系统默认）
  static const defaultFont = FontConfig(
    displayName: '系统默认',
    fontFamily: '',
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
class GoogleFontPresets {
  static List<FontConfig> get all => [
        FontConfig(
          displayName: '思源黑体',
          fontFamily: GoogleFonts.notoSansSc().fontFamily ?? 'Noto Sans SC',
          source: FontSource.google,
        ),
        FontConfig(
          displayName: '思源宋体',
          fontFamily: GoogleFonts.notoSerifSc().fontFamily ?? 'Noto Serif SC',
          source: FontSource.google,
        ),
        FontConfig(
          displayName: '思源黑体港',
          fontFamily: GoogleFonts.notoSansHk().fontFamily ?? 'Noto Sans HK',
          source: FontSource.google,
        ),
        FontConfig(
          displayName: '思源等宽',
          fontFamily: GoogleFonts.notoSansMono().fontFamily ?? 'Noto Sans Mono',
          source: FontSource.google,
        ),
        FontConfig(
          displayName: '站酷小薇',
          fontFamily: GoogleFonts.zcoolXiaoWei().fontFamily ?? 'ZCOOL XiaoWei',
          source: FontSource.google,
        ),
        FontConfig(
          displayName: '站酷快乐',
          fontFamily: GoogleFonts.zcoolKuaiLe().fontFamily ?? 'ZCOOL KuaiLe',
          source: FontSource.google,
        ),
        FontConfig(
          displayName: '马善政楷书',
          fontFamily: GoogleFonts.maShanZheng().fontFamily ?? 'Ma Shan Zheng',
          source: FontSource.google,
        ),
        FontConfig(
          displayName: '龙藏体',
          fontFamily: GoogleFonts.longCang().fontFamily ?? 'Long Cang',
          source: FontSource.google,
        ),
        FontConfig(
          displayName: '刘建毛草',
          fontFamily:
              GoogleFonts.liuJianMaoCao().fontFamily ?? 'Liu Jian Mao Cao',
          source: FontSource.google,
        ),
        FontConfig(
          displayName: '志漫行',
          fontFamily: GoogleFonts.zhiMangXing().fontFamily ?? 'Zhi Mang Xing',
          source: FontSource.google,
        ),
        FontConfig(
          displayName: '代码字体',
          fontFamily:
              GoogleFonts.sourceCodePro().fontFamily ?? 'Source Code Pro',
          source: FontSource.google,
        ),
        FontConfig(
          displayName: '现代窄体',
          fontFamily:
              GoogleFonts.sairaCondensed().fontFamily ?? 'Saira Condensed',
          source: FontSource.google,
        ),
        FontConfig(
          displayName: '古典衬线',
          fontFamily: GoogleFonts.cinzel().fontFamily ?? 'Cinzel',
          source: FontSource.google,
        ),
        FontConfig(
          displayName: '科幻风',
          fontFamily: GoogleFonts.orbitron().fontFamily ?? 'Orbitron',
          source: FontSource.google,
        ),
        FontConfig(
          displayName: '科技风',
          fontFamily: GoogleFonts.rajdhani().fontFamily ?? 'Rajdhani',
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
    '系统默认': [FontConfig.defaultFont],
    'Google Fonts': googleFonts,
    '系统字体': systemFonts,
  };
}
