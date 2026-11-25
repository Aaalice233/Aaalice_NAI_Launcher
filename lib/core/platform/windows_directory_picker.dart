import 'package:flutter/services.dart';

/// Windows 原生目录选择器与主窗口所属 Win32 线程通信的 MethodChannel 名称。
const windowsDirectoryPickerChannelName = 'com.nailauncher/directory_picker';

/// Windows 原生目录选择 MethodChannel。
const windowsDirectoryPickerChannel = MethodChannel(
  windowsDirectoryPickerChannelName,
);

/// 通过 Win32 主窗口所属线程的 `PostMessage` + `IFileOpenDialog::Show(hwnd)` 选择目录。
///
/// 由原生 Runner 在拥有窗口句柄的 STA 主线程上弹出模态对话框，避免在 Dart UI 线程或
/// 后台 isolate 跨线程传入 `hwndOwner` 导致的 `AttachThreadInput` 死锁与窗口层级错位。
Future<String?> pickWindowsDirectoryPath({String? dialogTitle}) async {
  final arguments = (dialogTitle != null && dialogTitle.isNotEmpty)
      ? <String, Object?>{'dialogTitle': dialogTitle}
      : null;

  final selectedPath = await windowsDirectoryPickerChannel.invokeMethod<String>(
    'pickDirectory',
    arguments,
  );
  if (selectedPath == null || selectedPath.isEmpty) {
    return null;
  }
  return selectedPath;
}
