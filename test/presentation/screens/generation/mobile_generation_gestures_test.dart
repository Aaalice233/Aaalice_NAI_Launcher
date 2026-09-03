import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/generation/mobile_generation_gestures.dart';

void main() {
  testWidgets('launcher drag does not start the workspace shortcut', (
    tester,
  ) async {
    final launcherKey = GlobalKey();
    var pointerDownCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MobileGenerationGestures(
            onPointerDown: (_) => pointerDownCount++,
            onPointerMove: (_) {},
            onPointerUp: (_) {},
            onPointerCancel: (_) {},
            onScrollNotification: (_) => false,
            pointerExclusionKeys: [launcherKey],
            pointerActive: false,
            dragOffset: 0,
            showHint: false,
            child: Column(
              children: [
                const Expanded(
                  child: ColoredBox(
                    key: ValueKey('workspace-content'),
                    color: Colors.blue,
                  ),
                ),
                SizedBox(
                  key: launcherKey,
                  height: 64,
                  width: double.infinity,
                  child: const ColoredBox(color: Colors.blue),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    final launcherDrag = await tester.startGesture(
      tester.getCenter(find.byKey(launcherKey)),
    );
    await launcherDrag.moveBy(const Offset(0, -120));
    await launcherDrag.up();
    expect(pointerDownCount, 0);

    final workspaceDrag = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('workspace-content'))),
    );
    await workspaceDrag.moveBy(const Offset(0, -120));
    await workspaceDrag.up();
    expect(pointerDownCount, 1);
  });
}
