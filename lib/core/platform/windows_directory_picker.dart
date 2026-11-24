import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:win32/win32.dart';

const _flutterRunnerWindowClassName = 'FLUTTER_RUNNER_WIN32_WINDOW';

/// 测试中替换 Windows 原生 `Show` 调用边界，保留句柄查找与独立 isolate 分派。
@visibleForTesting
String? Function(int hwndOwner, String? dialogTitle)?
debugWindowsDirectoryShowOverride;

/// 查找当前进程持有的主 Flutter Runner 窗口句柄。
///
/// 避免跨进程 `FindWindow` 或依赖易受焦点切换影响的 `GetForegroundWindow`，
/// 找不到本进程窗口时返回 `NULL`。
int findCurrentProcessMainWindowHandle() {
  return using((arena) {
    final className = _flutterRunnerWindowClassName.toNativeUtf16(
      allocator: arena,
    );
    final windowPid = arena<Uint32>();
    final currentPid = GetCurrentProcessId();
    var hwnd = NULL;
    var fallbackHwnd = NULL;

    while ((hwnd = FindWindowEx(NULL, hwnd, className, nullptr)) != NULL) {
      if (GetWindowThreadProcessId(hwnd, windowPid) == 0 ||
          windowPid.value != currentPid) {
        continue;
      }
      if (IsWindowVisible(hwnd) != 0) {
        return hwnd;
      }
      fallbackHwnd = hwnd;
    }

    return fallbackHwnd;
  });
}

/// 在独立 isolate 中弹出 Windows 原生目录选择对话框，避免阻塞 Flutter UI 线程。
Future<String?> pickWindowsDirectoryPath({String? dialogTitle}) {
  final hwndOwner = findCurrentProcessMainWindowHandle();
  final showOverride = debugWindowsDirectoryShowOverride;
  return Isolate.run(() {
    if (showOverride != null) {
      return showOverride(hwndOwner, dialogTitle);
    }
    return _showWindowsDirectoryDialog(
      hwndOwner: hwndOwner,
      dialogTitle: dialogTitle,
    );
  });
}

String? _showWindowsDirectoryDialog({
  required int hwndOwner,
  String? dialogTitle,
}) {
  final coInitHr = CoInitializeEx(
    nullptr,
    COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE,
  );
  if (FAILED(coInitHr)) {
    throw WindowsException(coInitHr);
  }

  try {
    final fileDialog = FileOpenDialog.createInstance();
    try {
      return using((arena) {
        final optionsPointer = arena<Uint32>();
        var hr = fileDialog.getOptions(optionsPointer);
        if (FAILED(hr)) {
          throw WindowsException(hr);
        }

        final options =
            optionsPointer.value |
            FOS_PICKFOLDERS |
            FOS_FORCEFILESYSTEM |
            FOS_NOCHANGEDIR;
        hr = fileDialog.setOptions(options);
        if (FAILED(hr)) {
          throw WindowsException(hr);
        }

        if (dialogTitle != null && dialogTitle.isNotEmpty) {
          final title = dialogTitle.toNativeUtf16(allocator: arena);
          hr = fileDialog.setTitle(title);
          if (FAILED(hr)) {
            throw WindowsException(hr);
          }
        }

        hr = fileDialog.show(hwndOwner);
        if (hr == HRESULT_FROM_WIN32(ERROR_CANCELLED)) {
          return null;
        }
        if (FAILED(hr)) {
          throw WindowsException(hr);
        }

        final resultPtr = calloc<COMObject>();
        hr = fileDialog.getResult(resultPtr.cast());
        if (FAILED(hr)) {
          calloc.free(resultPtr);
          throw WindowsException(hr);
        }
        if (resultPtr.ref.isNull) {
          calloc.free(resultPtr);
          return null;
        }

        final item = IShellItem(resultPtr);
        try {
          final pathPtr = arena<Pointer<Utf16>>();
          hr = item.getDisplayName(SIGDN_FILESYSPATH, pathPtr);
          if (FAILED(hr)) {
            throw WindowsException(hr);
          }

          final rawPath = pathPtr.value;
          if (rawPath == nullptr) {
            return null;
          }
          try {
            return rawPath.toDartString();
          } finally {
            CoTaskMemFree(rawPath);
          }
        } finally {
          // 必须在 release + free 前 detach，否则 IUnknown 的 Finalizer 会重复释放。
          item.detach();
          item.release();
          calloc.free(resultPtr);
        }
      });
    } finally {
      fileDialog.detach();
      fileDialog.release();
      calloc.free(fileDialog.ptr);
    }
  } finally {
    CoUninitialize();
  }
}
