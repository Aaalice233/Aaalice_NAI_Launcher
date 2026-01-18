import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// 权限请求工具类
class PermissionUtils {
  PermissionUtils._();

  /// 检测是否为 Android 13 及以上版本
  static Future<bool> _isAndroid13OrAbove() async {
    if (!Platform.isAndroid) return false;

    final deviceInfo = DeviceInfoPlugin();
    final androidInfo = await deviceInfo.androidInfo;
    return androidInfo.version.sdkInt >= 33; // Android 13 = API 33
  }

  /// 请求画廊权限 (兼容 Android 13)
  static Future<bool> requestGalleryPermission() async {
    if (!Platform.isAndroid) {
      return true; // 桌面端无需权限
    }

    final isAndroid13 = await _isAndroid13OrAbove();
    final permission =
        isAndroid13 ? ph.Permission.photos : ph.Permission.storage;

    final status = await permission.request();
    return status.isGranted || status.isLimited;
  }

  /// 检查画廊权限状态
  static Future<bool> checkGalleryPermission() async {
    if (!Platform.isAndroid) {
      return true;
    }

    final isAndroid13 = await _isAndroid13OrAbove();
    final permission =
        isAndroid13 ? ph.Permission.photos : ph.Permission.storage;

    final status = await permission.status;
    return status.isGranted || status.isLimited;
  }

  /// 打开应用设置页 (用户拒绝权限时)
  static Future<void> openAppSettings() async {
    await ph.openAppSettings();
  }
}
