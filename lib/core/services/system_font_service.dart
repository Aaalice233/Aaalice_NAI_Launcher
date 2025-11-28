import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'system_font_service.g.dart';

/// 系统字体服务 - 通过 MethodChannel 获取系统字体列表
class SystemFontService {
  static const _channel = MethodChannel('com.nailauncher/system_fonts');

  /// 获取系统字体列表
  Future<List<String>> getSystemFonts() async {
    try {
      final List<dynamic> fonts = await _channel.invokeMethod('getSystemFonts');
      return fonts.cast<String>();
    } catch (e) {
      // 如果获取失败，返回空列表
      return [];
    }
  }
}

/// SystemFontService Provider
@riverpod
SystemFontService systemFontService(Ref ref) {
  return SystemFontService();
}

/// 系统字体列表 Provider
@riverpod
Future<List<String>> systemFonts(Ref ref) async {
  final service = ref.read(systemFontServiceProvider);
  final fonts = await service.getSystemFonts();
  // 按字母排序
  fonts.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return fonts;
}
