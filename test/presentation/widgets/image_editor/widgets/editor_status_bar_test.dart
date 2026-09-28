import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/widgets/editor_status_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // EditorState 构造时会异步读取工具设置
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final textScale in const [1.0, 1.4]) {
    testWidgets(
      'narrow status bar scrolls instead of overflowing x$textScale',
      (tester) async {
        final state = EditorState()..setCanvasSize(const Size(512, 512));
        addTearDown(state.dispose);
        state.canvasController
          ..rotateRight()
          ..toggleMirrorHorizontal();

        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
              child: Scaffold(
                body: Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    width: 320,
                    child: EditorStatusBar(state: state),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Rotation: 15°'), findsOneWidget);
        final mirrored = find.text('Mirrored');
        await tester.ensureVisible(mirrored);
        await tester.pumpAndSettle();
        expect(mirrored.hitTestable(), findsOneWidget);
      },
    );
  }
}
