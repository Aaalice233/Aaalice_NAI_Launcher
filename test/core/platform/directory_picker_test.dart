import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/platform/directory_picker.dart';
import 'package:nai_launcher/core/platform/windows_directory_picker.dart';

import '../../helpers/fake_save_file_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(windowsDirectoryPickerChannel, null);
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

  test('pickWindowsDirectoryPath 通过原生 MethodChannel 传递标题、处理取消与异常', () async {
    final recordedCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(windowsDirectoryPickerChannel, (call) async {
          recordedCalls.add(call);
          final args = call.arguments as Map<Object?, Object?>?;
          final title = args?['dialogTitle'] as String?;
          if (title == '选择保存文件夹') {
            return r'D:\NAI\images';
          }
          if (title == 'empty') {
            return '';
          }
          if (title == 'throw') {
            throw PlatformException(
              code: 'directory_picker_show_failed',
              message: 'boom',
            );
          }
          return null;
        });

    expect(
      await pickWindowsDirectoryPath(dialogTitle: '选择保存文件夹'),
      r'D:\NAI\images',
    );
    expect(await pickWindowsDirectoryPath(), isNull);
    expect(await pickWindowsDirectoryPath(dialogTitle: ''), isNull);
    expect(await pickWindowsDirectoryPath(dialogTitle: 'empty'), isNull);
    await expectLater(
      pickWindowsDirectoryPath(dialogTitle: 'throw'),
      throwsA(
        isA<PlatformException>().having(
          (e) => e.code,
          'code',
          'directory_picker_show_failed',
        ),
      ),
    );

    expect(recordedCalls.map((call) => call.method), [
      'pickDirectory',
      'pickDirectory',
      'pickDirectory',
      'pickDirectory',
      'pickDirectory',
    ]);
    expect(recordedCalls.map((call) => call.arguments), [
      {'dialogTitle': '选择保存文件夹'},
      null,
      null,
      {'dialogTitle': 'empty'},
      {'dialogTitle': 'throw'},
    ]);
  });

  test('Windows 默认插件直接走原生 MethodChannel 且不回退 FilePickerWindows', () async {
    useFakeFilePicker(_ThrowingWindowsFilePicker());

    final firstCompleter = Completer<String?>();
    final recordedCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(windowsDirectoryPickerChannel, (call) {
          recordedCalls.add(call);
          final args = call.arguments as Map<Object?, Object?>?;
          final title = args?['dialogTitle'] as String?;
          if (title == 'first') {
            return firstCompleter.future;
          }
          if (title == 'throw') {
            return Future<String?>.error(
              PlatformException(code: 'directory_picker_show_failed'),
            );
          }
          return Future<String?>.value(r'D:\NAI\after');
        });

    final firstFuture = pickDirectoryPath(dialogTitle: 'first');
    try {
      final duplicate = await pickDirectoryPath(dialogTitle: 'duplicate');
      expect(duplicate, isNull);
      expect(recordedCalls, hasLength(1));

      firstCompleter.complete(r'D:\NAI\images');
      expect(await firstFuture, r'D:\NAI\images');
    } finally {
      if (!firstCompleter.isCompleted) {
        firstCompleter.complete(null);
        await firstFuture;
      }
    }

    await expectLater(
      pickDirectoryPath(dialogTitle: 'throw'),
      throwsA(isA<PlatformException>()),
    );
    expect(await pickDirectoryPath(dialogTitle: 'after'), r'D:\NAI\after');
    expect(recordedCalls.map((call) => call.arguments), [
      {'dialogTitle': 'first'},
      {'dialogTitle': 'throw'},
      {'dialogTitle': 'after'},
    ]);
  }, skip: !Platform.isWindows);
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
