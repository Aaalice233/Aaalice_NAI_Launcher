import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// 权限请求工具类
class PermissionUtils {
  PermissionUtils._();

  /// 应用图库位于应用自己的存储目录，导入由系统文件选择器授权，
  /// 两者都不需要申请整库读取权限。
  static Future<bool> requestGalleryPermission() async => true;

  static Future<bool> checkGalleryPermission() async => true;

  /// Android 9 及更早版本向公共 Pictures 目录写入时仍需旧存储权限。
  /// Android 10 起通过 MediaStore 写入，不应申请照片读取权限。
  static Future<bool> requestLegacyMediaWritePermission() async {
    if (!Platform.isAndroid) return true;

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt >= 29) return true;

    final status = await ph.Permission.storage.request();
    return status.isGranted;
  }

  /// 打开应用设置页 (用户拒绝权限时)
  static Future<void> openAppSettings() async {
    await ph.openAppSettings();
  }
}
