import 'package:file_picker/file_picker.dart';

import 'platform_capabilities.dart';
import 'windows_directory_picker.dart';

bool _isPickingDirectory = false;

/// 打开系统目录选择对话框，并确保同一时刻仅存在一个选择器请求。
///
/// 在 Windows 上通过原生 Runner 主窗口线程弹出模态 `IFileOpenDialog`，规避 `file_picker` 8.x
/// 在 Dart UI 线程同步阻塞、依赖 `GetForegroundWindow()` 及跨线程挂载父窗口导致的死锁问题。
Future<String?> pickDirectoryPath({String? dialogTitle}) async {
  if (_isPickingDirectory) {
    return null;
  }

  _isPickingDirectory = true;
  try {
    if (PlatformCapabilities.operatingSystem.isWindows &&
        FilePicker.platform is FilePickerWindows) {
      return await pickWindowsDirectoryPath(dialogTitle: dialogTitle);
    }

    return await FilePicker.platform.getDirectoryPath(
      dialogTitle: dialogTitle,
      lockParentWindow: true,
    );
  } finally {
    _isPickingDirectory = false;
  }
}
