import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_controller.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_types.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_workspace.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/widgets/toolbar/desktop_toolbar.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/widgets/toolbar/mobile_toolbar.dart';

void main() {
  const pointerPolicy = InteractionPolicy(
    modality: InteractionModality.pointer,
    touchAvailable: false,
    precisePointerAvailable: true,
  );
  const touchPolicy = InteractionPolicy(
    modality: InteractionModality.touch,
    touchAvailable: true,
    precisePointerAvailable: false,
  );

  testWidgets('precise-pointer editor uses expanded layout from 840', (
    tester,
  ) async {
    final key = GlobalKey<ImageEditorWorkspaceState>();
    final session = ImageEditorController(config: _config);
    addTearDown(session.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(839, 760);

    await _pumpWorkspace(
      tester,
      key: key,
      session: session,
      policy: pointerPolicy,
    );
    await tester.pumpAndSettle();
    expect(find.byType(MobileToolbar), findsOneWidget);
    key.currentState!.debugSetToolById('eraser');

    for (final width in [840.0, 899.0, 999.0]) {
      tester.view.physicalSize = Size(width, 760);
      await tester.pumpAndSettle();

      expect(
        find.byType(DesktopToolbar),
        findsOneWidget,
        reason: 'width=$width',
      );
      expect(find.byType(MobileToolbar), findsNothing, reason: 'width=$width');
      expect(key.currentState!.debugCurrentToolId, 'eraser');
      expect(tester.takeException(), isNull, reason: 'width=$width');
    }
  });

  testWidgets('desktop toolbar actions use the workspace local width', (
    tester,
  ) async {
    final session = ImageEditorController(config: _config);
    addTearDown(session.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1800, 760);

    await _pumpWorkspace(
      tester,
      session: session,
      policy: pointerPolicy,
      contentWidth: 1000,
    );
    await tester.pumpAndSettle();

    expect(find.byType(DesktopToolbar), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Effects'), findsNothing);
    expect(find.byTooltip('Effects'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compression real entry adapts at compact worst-case and wide widths',
    (tester) async {
      final session = ImageEditorController(config: _config);
      addTearDown(session.dispose);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;

      for (final size in [const Size(320, 480), const Size(1180, 760)]) {
        tester.view.physicalSize = size;
        await _pumpWorkspace(
          tester,
          session: session,
          policy: pointerPolicy,
          textScaler: size.width < 600
              ? const TextScaler.linear(2)
              : TextScaler.noScaling,
        );
        await tester.pumpAndSettle();

        if (size.width < 600) {
          await tester.tap(find.byTooltip('More'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Choose output resolution'));
        } else {
          await tester.tap(find.byTooltip('Choose output resolution'));
        }
        await tester.pumpAndSettle();

        expect(
          find.byKey(
            ValueKey(
              size.width < 600
                  ? 'adaptive-bottom-sheet'
                  : 'adaptive-centered-form',
            ),
          ),
          findsOneWidget,
          reason: 'size=$size',
        );
        expect(find.text('Output resolution'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'size=$size');

        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets('shortcut help uses adaptive long-form presentation', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    for (final scenario in <({Size size, double scale, double keyboard})>[
      (size: const Size(320, 1000), scale: 3, keyboard: 260),
      (size: const Size(1600, 900), scale: 1, keyboard: 0),
    ]) {
      tester.view.physicalSize = scenario.size;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(scenario.scale),
              viewInsets: EdgeInsets.only(bottom: scenario.keyboard),
              padding: const EdgeInsets.only(top: 20, bottom: 16),
              viewPadding: const EdgeInsets.only(top: 20, bottom: 16),
            ),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: FilledButton(
                onPressed: () =>
                    ImageEditorWorkspaceState.debugShowShortcutHelpForContext(
                      context,
                    ),
                child: const Text('Shortcuts'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Shortcuts'));
      await tester.pumpAndSettle();

      final presentation = scenario.size.width < 600
          ? find.byKey(const ValueKey('adaptive-full-screen-form'))
          : find.byKey(const ValueKey('adaptive-centered-form'));
      expect(presentation, findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      final scrollable = find.descendant(
        of: find.byKey(const ValueKey('image-editor-shortcut-help-scroll')),
        matching: find.byType(Scrollable),
      );
      expect(
        tester.state<ScrollableState>(scrollable).position.maxScrollExtent,
        greaterThan(0),
      );
      expect(tester.takeException(), isNull, reason: '${scenario.size}');

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('expanded layout follows local width under touch policy', (
    tester,
  ) async {
    final session = ImageEditorController(config: _config);
    addTearDown(session.dispose);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    for (final width in [840.0, 899.0, 999.0]) {
      tester.view.physicalSize = Size(width, 760);
      await _pumpWorkspace(tester, session: session, policy: touchPolicy);
      await tester.pumpAndSettle();

      expect(
        find.byType(DesktopToolbar),
        findsOneWidget,
        reason: 'width=$width',
      );
      expect(find.byType(MobileToolbar), findsNothing, reason: 'width=$width');
      expect(tester.takeException(), isNull, reason: 'width=$width');
    }
  });
}

final _config = ImageEditorSessionConfig(
  initialSize: const Size(512, 512),
  debugOptions: const ImageEditorDebugOptions(disableDropRegion: true),
);

Future<void> _pumpWorkspace(
  WidgetTester tester, {
  GlobalKey<ImageEditorWorkspaceState>? key,
  required ImageEditorController session,
  required InteractionPolicy policy,
  double? contentWidth,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  final workspace = InteractionPolicyScope(
    initialPolicy: policy,
    child: ImageEditorWorkspace(key: key, controller: session, config: _config),
  );
  return tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: contentWidth == null
          ? workspace
          : Align(
              child: SizedBox(width: contentWidth, child: workspace),
            ),
    ),
  );
}
