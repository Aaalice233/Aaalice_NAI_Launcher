import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';

/// 替换上游 Windows 原生实现：上游注册插件时就订阅定位、启动即打开定位会话，
/// 查询蓝牙服务还会打开蓝牙。返回值与上游一致，只是不再实际查询定位与蓝牙。
class PermissionHandlerWindows extends PermissionHandlerPlatform {
  static void registerWith() {
    PermissionHandlerPlatform.instance = PermissionHandlerWindows();
  }

  @override
  Future<PermissionStatus> checkPermissionStatus(Permission permission) async =>
      PermissionStatus.granted;

  @override
  Future<ServiceStatus> checkServiceStatus(Permission permission) async =>
      permission == Permission.ignoreBatteryOptimizations
      ? ServiceStatus.enabled
      : ServiceStatus.notApplicable;

  @override
  Future<Map<Permission, PermissionStatus>> requestPermissions(
    List<Permission> permissions,
  ) async => {
    for (final permission in permissions) permission: PermissionStatus.granted,
  };

  @override
  Future<bool> shouldShowRequestPermissionRationale(
    Permission permission,
  ) async => false;

  @override
  Future<bool> openAppSettings() async => false;
}
