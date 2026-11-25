import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows Runner CMakeLists 注册 directory_picker 并链接 COM/Shell 库', () {
    final cmakeSource = File(
      'windows/runner/CMakeLists.txt',
    ).readAsStringSync();

    expect(cmakeSource, contains('"directory_picker.cpp"'));
    expect(cmakeSource, contains('"ole32.lib"'));
    expect(cmakeSource, contains('"shell32.lib"'));
  });

  test('FlutterWindow 通过 PostMessage 在主窗口线程延后执行并安全清理生命周期', () {
    final headerSource = File(
      'windows/runner/flutter_window.h',
    ).readAsStringSync();
    final windowSource = File(
      'windows/runner/flutter_window.cpp',
    ).readAsStringSync();

    expect(headerSource, contains('directory_picker_channel_'));
    expect(headerSource, contains('pending_directory_pick_'));
    expect(headerSource, contains('active_directory_pick_result_'));
    expect(headerSource, contains('directory_pick_in_progress_'));

    expect(windowSource, contains('"com.nailauncher/directory_picker"'));
    expect(windowSource, contains('call.method_name() != "pickDirectory"'));
    expect(
      windowSource,
      contains('PostMessage(window, kPickDirectoryMessage, 0, 0)'),
    );
    expect(windowSource, contains('if (message == kPickDirectoryMessage)'));
    expect(windowSource, contains('HandlePendingDirectoryPick(hwnd);'));
    expect(
      windowSource,
      contains('PickDirectoryOnWindowThread(hwnd, dialog_title)'),
    );

    final onDestroyStart = windowSource.indexOf(
      'void FlutterWindow::OnDestroy()',
    );
    final onDestroyEnd = windowSource.indexOf(
      'Win32Window::OnDestroy();',
      onDestroyStart,
    );
    expect(onDestroyStart, greaterThanOrEqualTo(0));
    expect(onDestroyEnd, greaterThan(onDestroyStart));

    final onDestroyBody = windowSource.substring(onDestroyStart, onDestroyEnd);
    final pendingCleanup = onDestroyBody.indexOf('pending_directory_pick_');
    final activeCleanup = onDestroyBody.indexOf(
      'active_directory_pick_result_',
    );
    final controllerReset = onDestroyBody.indexOf(
      'flutter_controller_ = nullptr',
    );
    expect(pendingCleanup, greaterThanOrEqualTo(0));
    expect(activeCleanup, greaterThanOrEqualTo(0));
    expect(pendingCleanup, lessThan(controllerReset));
    expect(activeCleanup, lessThan(controllerReset));
  });

  test('directory_picker.cpp 复用主线程 STA COM 并在同线程弹出 IFileOpenDialog', () {
    final pickerSource = File(
      'windows/runner/directory_picker.cpp',
    ).readAsStringSync();

    expect(pickerSource, contains('CLSID_FileOpenDialog'));
    expect(
      pickerSource,
      contains('FOS_PICKFOLDERS | FOS_FORCEFILESYSTEM | FOS_NOCHANGEDIR'),
    );
    expect(pickerSource, contains('dialog->Show(owner)'));
    expect(pickerSource, contains('HRESULT_FROM_WIN32(ERROR_CANCELLED)'));
    expect(pickerSource, contains('CoTaskMemFree'));
    expect(pickerSource, isNot(contains('CoInitializeEx(')));
    expect(pickerSource, isNot(contains('CoUninitialize(')));
  });

  test('Dart 侧 Windows 目录选择已移除跨线程 Isolate 与 win32 FFI', () {
    final dartSource = File(
      'lib/core/platform/windows_directory_picker.dart',
    ).readAsStringSync();

    expect(dartSource, contains("'com.nailauncher/directory_picker'"));
    expect(
      dartSource,
      matches(RegExp(r"invokeMethod<String>\(\s*'pickDirectory'")),
    );
    expect(dartSource, isNot(contains('Isolate.run')));
    expect(dartSource, isNot(contains('dart:ffi')));
    expect(dartSource, isNot(contains('package:win32/')));
  });
}
