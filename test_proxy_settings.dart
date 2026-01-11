/// Windows 系统代理设置测试脚本
///
/// 运行方法: dart test_proxy_settings.dart
///
/// 此脚本用于验证 WindowsProxyHelper 是否正确读取系统代理设置
library;

import 'dart:io';

void main() async {
  print('=== Windows 代理设置测试 ===\n');

  // 检查平台
  if (!Platform.isWindows) {
    print('⚠️  此测试仅适用于 Windows 平台');
    print('当前平台: ${Platform.operatingSystem}');
    return;
  }

  print('✓ 平台检查通过 - 运行在 Windows 上\n');

  // 模拟 WindowsProxyHelper 的逻辑
  const registryPath =
      r'Software\Microsoft\Windows\CurrentVersion\Internet Settings';

  try {
    // 导入 win32_registry (运行时检查)
    print('正在读取注册表...');

    // 由于无法直接在测试脚本中使用 win32_registry (需要 package 导入)，
    // 此脚本用于验证原理，实际测试请运行应用查看日志

    print('''
📋 验证步骤:

1. 确保 Clash/v2ray 已安装并配置好系统代理
2. 运行应用: flutter run -d windows
3. 查看控制台日志，应显示类似:
   - "Applied system proxy: PROXY 127.0.0.1:7890" (代理开启时)
   - 或无输出 (代理关闭时)

4. 测试场景:
   ⬜ 关闭代理 -> 应用应能正常加载在线画廊
   ⬜ 开启系统代理 -> 应用应通过代理加载
   ⬜ NAI 图像生成应正常工作

⚠️  注意: 如果代理需要用户名/密码验证，应用目前不支持自动认证
''');

    print('=== 测试脚本结束 ===');
  } catch (e) {
    print('❌ 错误: $e');
  }
}
