import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/desktop_app_shutdown_service.dart';
import 'package:nai_launcher/main.dart' show AppTrayListener;
import 'package:tray_manager/tray_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('退出立即隐藏窗口，等待保存完成且不允许托盘重新打开', () async {
    final events = <String>[];
    final flushStarted = Completer<void>();
    final finishFlush = Completer<void>();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final name in ['window_manager', 'tray_manager']) {
      final channel = MethodChannel(name);
      messenger.setMockMethodCallHandler(channel, (call) async {
        events.add('$name.${call.method}');
        return null;
      });
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    }
    DesktopAppShutdownService.setWindowStateFlushHandler(() async {
      events.add('flush');
      flushStarted.complete();
      await finishFlush.future;
      events.add('flushed');
    });

    await IOOverrides.runZoned(
      () async {
        final shutdown = DesktopAppShutdownService.shutdownAndExit(7);
        final completed = expectLater(shutdown, throwsA(isA<_ExitRequested>()));
        await flushStarted.future;
        expect(events, [
          'window_manager.hide',
          'tray_manager.destroy',
          'flush',
        ]);
        expect(DesktopAppShutdownService.isShuttingDown, isTrue);
        expect(
          identical(shutdown, DesktopAppShutdownService.shutdownAndExit(7)),
          isTrue,
        );
        final listener = AppTrayListener();
        await listener.onTrayIconMouseDown();
        listener.onTrayIconRightMouseDown();
        await listener.onTrayMenuItemClick(
          MenuItem(key: 'show', label: 'Show'),
        );
        expect(events, [
          'window_manager.hide',
          'tray_manager.destroy',
          'flush',
        ]);
        finishFlush.complete();
        await completed;
        expect(events, [
          'window_manager.hide',
          'tray_manager.destroy',
          'flush',
          'flushed',
          'window_manager.setPreventClose',
          'window_manager.destroy',
          'exit:7',
        ]);
      },
      exit: (code) {
        events.add('exit:$code');
        throw _ExitRequested();
      },
    );
  });
}

class _ExitRequested implements Exception {}
