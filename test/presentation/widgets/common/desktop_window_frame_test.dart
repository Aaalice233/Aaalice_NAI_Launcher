import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/windowing/desktop_window_controller.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/desktop_window_frame.dart';
import 'package:window_manager/window_manager.dart';

class _ProbeLifecycle {
  int initCalls = 0;
  int disposeCalls = 0;
  int tapCalls = 0;
}

class _StatefulProbe extends StatefulWidget {
  const _StatefulProbe(this.lifecycle);

  final _ProbeLifecycle lifecycle;

  @override
  State<_StatefulProbe> createState() => _StatefulProbeState();
}

class _StatefulProbeState extends State<_StatefulProbe> {
  @override
  void initState() {
    super.initState();
    widget.lifecycle.initCalls++;
  }

  @override
  void dispose() {
    widget.lifecycle.disposeCalls++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FilledButton(
        key: const ValueKey('stateful-window-content'),
        onPressed: () => widget.lifecycle.tapCalls++,
        child: const Text('content'),
      ),
    );
  }
}

class _FakeDesktopWindowController implements DesktopWindowController {
  WindowListener? listener;
  bool maximized = false;
  int dragCalls = 0;
  int minimizeCalls = 0;
  int maximizeCalls = 0;
  int unmaximizeCalls = 0;
  int closeCalls = 0;

  @override
  void addListener(WindowListener listener) => this.listener = listener;

  @override
  void removeListener(WindowListener listener) {
    if (this.listener == listener) this.listener = null;
  }

  @override
  Future<bool> isMaximized() async => maximized;

  @override
  Future<void> startDragging() async => dragCalls++;

  @override
  Future<void> minimize() async => minimizeCalls++;

  @override
  Future<void> maximize() async {
    maximizeCalls++;
    maximized = true;
    listener?.onWindowMaximize();
  }

  @override
  Future<void> unmaximize() async {
    unmaximizeCalls++;
    maximized = false;
    listener?.onWindowUnmaximize();
  }

  @override
  Future<void> close() async => closeCalls++;
}

Widget _buildFrame(_FakeDesktopWindowController controller) {
  return MaterialApp(
    locale: const Locale('zh'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: ThemeData.dark(useMaterial3: true),
    home: DesktopWindowFrame(
      enabled: true,
      controller: controller,
      child: const ColoredBox(
        key: ValueKey('window-content'),
        color: Colors.black,
      ),
    ),
  );
}

Widget _buildFrameAboveNavigator(_FakeDesktopWindowController controller) {
  return MaterialApp(
    locale: const Locale('zh'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    theme: ThemeData.dark(useMaterial3: true),
    builder: (context, child) => DesktopWindowFrame(
      enabled: true,
      controller: controller,
      child: child!,
    ),
    home: const ColoredBox(
      key: ValueKey('window-content'),
      color: Colors.black,
    ),
  );
}

void main() {
  testWidgets('header is safe above the Navigator overlay', (tester) async {
    final controller = _FakeDesktopWindowController();

    await tester.pumpWidget(_buildFrameAboveNavigator(controller));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(Tooltip), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('desktop-window-header'))),
      const Size(800, desktopWindowHeaderHeight),
    );
  });

  testWidgets(
    'transient minimized surfaces preserve child state and suspend activity',
    (tester) async {
      final controller = _FakeDesktopWindowController();
      final lifecycle = _ProbeLifecycle();
      final viewport = ValueNotifier(const Size(800, 600));
      addTearDown(viewport.dispose);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Align(
            alignment: Alignment.topLeft,
            child: ValueListenableBuilder<Size>(
              valueListenable: viewport,
              builder: (context, size, child) => SizedBox.fromSize(
                size: size,
                child: DesktopWindowFrame(
                  enabled: true,
                  controller: controller,
                  child: child!,
                ),
              ),
              child: _StatefulProbe(lifecycle),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(lifecycle.initCalls, 1);
      expect(lifecycle.disposeCalls, 0);

      for (final minimizedSize in [Size.zero, const Size(144, 19)]) {
        viewport.value = minimizedSize;
        await tester.pump();

        expect(lifecycle.initCalls, 1);
        expect(lifecycle.disposeCalls, 0);
        expect(
          find.byKey(const ValueKey('desktop-window-header')),
          findsOneWidget,
        );
        expect(
          tester
              .widgetList<IgnorePointer>(find.byType(IgnorePointer))
              .any((widget) => widget.ignoring),
          isTrue,
        );
        expect(tester.takeException(), isNull);
      }

      viewport.value = const Size(800, 600);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('stateful-window-content')));
      await tester.pump();

      expect(lifecycle.initCalls, 1);
      expect(lifecycle.disposeCalls, 0);
      expect(lifecycle.tapCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Windows header exposes localized controls with desktop hit areas',
    (tester) async {
      final controller = _FakeDesktopWindowController();
      await tester.pumpWidget(_buildFrame(controller));
      await tester.pump();

      expect(
        tester.getSize(find.byKey(const ValueKey('desktop-window-header'))),
        const Size(800, desktopWindowHeaderHeight),
      );
      final projectIcon = tester.widget<Image>(
        find.byKey(const ValueKey('desktop-window-project-icon')),
      );
      expect(projectIcon.image, isA<AssetImage>());
      expect(
        (projectIcon.image as AssetImage).assetName,
        'assets/icons/Icon.png',
      );
      expect(
        tester.getSize(
          find.byKey(const ValueKey('desktop-window-project-icon')),
        ),
        const Size.square(24),
      );
      final divider = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('desktop-window-header-divider')),
      );
      final decoration = divider.decoration as BoxDecoration;
      expect(decoration.border, isA<Border>());
      expect((decoration.border! as Border).bottom.width, 1);
      expect((decoration.border! as Border).bottom.color.a, greaterThan(0));
      for (final key in [
        'desktop-window-minimize',
        'desktop-window-maximize',
        'desktop-window-close',
      ]) {
        expect(
          tester.getSize(find.byKey(ValueKey(key))),
          const Size(desktopWindowButtonWidth, desktopWindowHeaderHeight),
        );
      }

      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('desktop-window-minimize')))
            .label,
        '最小化',
      );
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('desktop-window-maximize')))
            .label,
        '最大化',
      );
      expect(
        tester
            .getSemantics(find.byKey(const ValueKey('desktop-window-close')))
            .label,
        '关闭窗口',
      );
    },
  );

  testWidgets('caption controls preserve minimize maximize restore and close', (
    tester,
  ) async {
    final controller = _FakeDesktopWindowController();
    await tester.pumpWidget(_buildFrame(controller));
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('desktop-window-minimize')));
    await tester.tap(find.byKey(const ValueKey('desktop-window-maximize')));
    await tester.pump();

    expect(controller.minimizeCalls, 1);
    expect(controller.maximizeCalls, 1);
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('desktop-window-maximize')))
          .label,
      '还原',
    );

    await tester.tap(find.byKey(const ValueKey('desktop-window-maximize')));
    await tester.tap(find.byKey(const ValueKey('desktop-window-close')));
    await tester.pump();

    expect(controller.unmaximizeCalls, 1);
    expect(controller.closeCalls, 1);
  });

  testWidgets(
    'drag region starts native move and double click toggles maximize',
    (tester) async {
      final controller = _FakeDesktopWindowController();
      await tester.pumpWidget(_buildFrame(controller));
      await tester.pump();

      final dragRegion = find.byKey(
        const ValueKey('desktop-window-drag-region'),
      );
      await tester.drag(dragRegion, const Offset(24, 0));
      expect(controller.dragCalls, 1);

      await tester.tap(dragRegion);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(dragRegion);
      await tester.pumpAndSettle();
      expect(controller.maximizeCalls, 1);
    },
  );

  testWidgets('caption buttons are reachable and activatable from keyboard', (
    tester,
  ) async {
    final controller = _FakeDesktopWindowController();
    await tester.pumpWidget(_buildFrame(controller));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();

    expect(controller.minimizeCalls, 1);
  });
}
