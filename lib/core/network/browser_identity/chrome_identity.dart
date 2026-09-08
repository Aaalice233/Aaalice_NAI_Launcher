import 'package:flutter/foundation.dart';

import 'chrome_grease_brands.dart';

/// 请求头对齐的 Chrome 稳定版大版本号。
///
/// User-Agent 与 `sec-ch-ua` 都由它派生，两处不得各自写死版本号。
const int chromeMajorVersion = 152;

/// Chrome 客户端提示识别的平台。
enum ChromePlatform {
  windows('Windows', 'Windows NT 10.0; Win64; x64'),
  macOS('macOS', 'Macintosh; Intel Mac OS X 10_15_7'),
  android('Android', 'Linux; Android 10; K'),
  linux('Linux', 'X11; Linux x86_64');

  const ChromePlatform(this.hintValue, this.userAgentPlatform);

  /// `sec-ch-ua-platform` 的取值（不含引号）。
  final String hintValue;

  /// User-Agent 括号内的平台段。
  final String userAgentPlatform;

  bool get isMobile => this == ChromePlatform.android;

  /// 未覆盖的运行平台按桌面 Windows 处理。
  static ChromePlatform fromTargetPlatform(TargetPlatform platform) {
    return switch (platform) {
      TargetPlatform.macOS => ChromePlatform.macOS,
      TargetPlatform.android => ChromePlatform.android,
      TargetPlatform.linux => ChromePlatform.linux,
      _ => ChromePlatform.windows,
    };
  }
}

/// 一组自洽的 Chrome 身份请求头。
@immutable
class ChromeIdentity {
  const ChromeIdentity({
    required this.platform,
    this.majorVersion = chromeMajorVersion,
  });

  /// 按当前运行平台解析。
  factory ChromeIdentity.current() =>
      ChromeIdentity(platform: ChromePlatform.fromTargetPlatform(
        defaultTargetPlatform,
      ));

  final ChromePlatform platform;
  final int majorVersion;

  String get userAgent =>
      'Mozilla/5.0 (${platform.userAgentPlatform}) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/$majorVersion.0.0.0 '
      '${platform.isMobile ? 'Mobile ' : ''}Safari/537.36';

  String get secChUa => buildChromeSecChUa(majorVersion);

  String get secChUaMobile => platform.isMobile ? '?1' : '?0';

  String get secChUaPlatform => '"${platform.hintValue}"';
}
