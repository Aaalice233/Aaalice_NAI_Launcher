import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../platform/platform_capabilities.dart';

part 'system_font_service.g.dart';

/// 系统字体服务 - 通过 MethodChannel 获取系统字体列表
class SystemFontService {
  SystemFontService({
    MethodChannel channel = const MethodChannel('com.nailauncher/system_fonts'),
    PlatformCapabilities? capabilities,
  }) : _channel = channel,
       _capabilities = capabilities ?? PlatformCapabilities.current;

  final MethodChannel _channel;
  final PlatformCapabilities _capabilities;

  /// 获取系统字体列表
  Future<List<String>> getSystemFonts() async {
    if (!_capabilities.supportsSystemFontEnumeration) {
      throw UnsupportedError('System font enumeration is not supported');
    }

    final List<dynamic> fonts = await _channel.invokeMethod('getSystemFonts');
    return fonts.cast<String>();
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
