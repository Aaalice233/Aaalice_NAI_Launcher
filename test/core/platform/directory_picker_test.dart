import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/platform/directory_picker.dart';
import 'package:nai_launcher/core/platform/windows_directory_picker.dart';
import 'package:win32/win32.dart';

import '../../helpers/fake_save_file_picker.dart';

void main() {
  tearDown(() {
    debugWindowsDirectoryShowOverride = null;
  });

  test('非 Windows 插件实现统一通过 lockParentWindow: true 调起目录选择并透传结果', () async {
    final picker = _RecordingDirectoryPicker(
      onPick: ({dialogTitle, lockParentWindow = false}) async {
        return dialogTitle == '选择保存文件夹' ? '/tmp/selected' : null;
      },
    );
    useFakeFilePicker(picker);

    final selected = await pickDirectoryPath(dialogTitle: '选择保存文件夹');
    final cancelled = await pickDirectoryPath(dialogTitle: '取消选择');

    expect(selected, '/tmp/selected');
    expect(cancelled, isNull);
    expect(picker.calls, [
      (dialogTitle: '选择保存文件夹', lockParentWindow: true),
      (dialogTitle: '取消选择', lockParentWindow: true),
    ]);
  });

  test('并发重入直接返回 null，待前一次完成后恢复可再次调用，异常亦不锁死', () async {
    final firstCompleter = Completer<String?>();
    final picker = _RecordingDirectoryPicker(
      onPick: ({dialogTitle, lockParentWindow = false}) {
        if (dialogTitle == 'first') return firstCompleter.future;
        if (dialogTitle == 'throw') {
          return Future<String?>.error(StateError('boom'));
        }
        return Future<String?>.value('/tmp/after');
      },
    );
    useFakeFilePicker(picker);

    final firstFuture = pickDirectoryPath(dialogTitle: 'first');
    try {
      final duplicateResult = await pickDirectoryPath(dialogTitle: 'second');

      expect(duplicateResult, isNull);
      expect(picker.calls, [(dialogTitle: 'first', lockParentWindow: true)]);

      firstCompleter.complete('/tmp/first');
      expect(await firstFuture, '/tmp/first');
    } finally {
      if (!firstCompleter.isCompleted) {
        firstCompleter.complete(null);
        await firstFuture;
      }
    }

    await expectLater(
      pickDirectoryPath(dialogTitle: 'throw'),
      throwsStateError,
    );
    expect(await pickDirectoryPath(dialogTitle: 'after'), '/tmp/after');
    expect(picker.calls, [
      (dialogTitle: 'first', lockParentWindow: true),
      (dialogTitle: 'throw', lockParentWindow: true),
      (dialogTitle: 'after', lockParentWindow: true),
    ]);
  });

  test('Windows 默认插件不回退到旧实现，并在独立 isolate 中传入本进程主窗口句柄', () async {
    final testHwnd = _createHiddenRunnerTestWindow();
    expect(testHwnd, isNot(NULL));
    expect(findCurrentProcessMainWindowHandle(), testHwnd);

    useFakeFilePicker(_ThrowingWindowsFilePicker());

    final callerControlPort = Isolate.current.controlPort;
    final receivePort = ReceivePort();
    addTearDown(receivePort.close);
    final sendPort = receivePort.sendPort;

    debugWindowsDirectoryShowOverride = (hwndOwner, dialogTitle) {
      sendPort.send((
        hwndOwner: hwndOwner,
        dialogTitle: dialogTitle,
        workerControlPort: Isolate.current.controlPort,
      ));
      return r'D:\NAI\images';
    };

    final selected = await pickDirectoryPath(dialogTitle: '选择保存文件夹');
    final recorded =
        await receivePort.first
            as ({
              int hwndOwner,
              String? dialogTitle,
              SendPort workerControlPort,
            });

    expect(selected, r'D:\NAI\images');
    expect(recorded.hwndOwner, testHwnd);
    expect(recorded.dialogTitle, '选择保存文件夹');
    expect(recorded.workerControlPort, isNot(callerControlPort));
  }, skip: !Platform.isWindows);

  test('无窗口的测试进程中 findCurrentProcessMainWindowHandle 返回 0 且不抓他进程窗口', () {
    expect(findCurrentProcessMainWindowHandle(), 0);
  }, skip: !Platform.isWindows);
}

int _createHiddenRunnerTestWindow() {
  final hInstance = GetModuleHandle(nullptr);
  final className = 'FLUTTER_RUNNER_WIN32_WINDOW'.toNativeUtf16();
  final windowTitle = 'NAI Launcher Test'.toNativeUtf16();
  final wndClass = calloc<WNDCLASS>();
  final defWindowProc = DynamicLibrary.open(
    'user32.dll',
  ).lookup<NativeFunction<WNDPROC>>('DefWindowProcW');

  wndClass.ref.lpfnWndProc = defWindowProc;
  wndClass.ref.hInstance = hInstance;
  wndClass.ref.lpszClassName = className;

  var atom = 0;
  var hwnd = NULL;
  addTearDown(() {
    if (hwnd != NULL) {
      DestroyWindow(hwnd);
    }
    if (atom != 0) {
      UnregisterClass(className, hInstance);
    }
    calloc.free(wndClass);
    calloc.free(windowTitle);
    calloc.free(className);
  });

  atom = RegisterClass(wndClass);
  final registered = atom != 0 || GetLastError() == ERROR_CLASS_ALREADY_EXISTS;
  expect(registered, isTrue);

  hwnd = CreateWindowEx(
    0,
    className,
    windowTitle,
    WS_OVERLAPPED,
    0,
    0,
    0,
    0,
    NULL,
    NULL,
    hInstance,
    nullptr,
  );

  return hwnd;
}

typedef _DirectoryPickCall = ({String? dialogTitle, bool lockParentWindow});

class _RecordingDirectoryPicker extends FilePicker {
  _RecordingDirectoryPicker({required this.onPick});

  final Future<String?> Function({String? dialogTitle, bool lockParentWindow})
  onPick;
  final List<_DirectoryPickCall> calls = [];

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
  }) {
    calls.add((dialogTitle: dialogTitle, lockParentWindow: lockParentWindow));
    return onPick(dialogTitle: dialogTitle, lockParentWindow: lockParentWindow);
  }
}

class _ThrowingWindowsFilePicker extends FilePickerWindows {
  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
  }) {
    fail('Windows 默认分派不应回退到 FilePickerWindows.getDirectoryPath');
  }
}
