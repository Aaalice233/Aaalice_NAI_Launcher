import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/prompt_tag.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/prompt/components/tag_action_menu/bottom_action_sheet.dart';
import 'package:nai_launcher/presentation/widgets/prompt/components/tag_action_menu/floating_action_menu.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.single;
    view.devicePixelRatio = 3;
    view.physicalSize = const Size(960, 1800);
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.single;
    view.resetDevicePixelRatio();
    view.resetPhysicalSize();
  });

  Widget app(Widget child, {double textScale = 1, double keyboardInset = 0}) {
    return MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, appChild) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          viewInsets: EdgeInsets.only(bottom: keyboardInset),
          padding: const EdgeInsets.only(bottom: 24),
        ),
        child: appChild!,
      ),
      home: Scaffold(body: child),
    );
  }

  const tag = PromptTag(
    id: 'tag',
    text: 'very_long_character_tag_name',
    translation: '用于验证三倍字体和窄屏布局的长翻译',
    weight: 1.1,
  );

  testWidgets(
    'adaptive touch panel preserves every action at 320dp, 3x and IME inset',
    (tester) async {
      var toggled = 0;
      var edited = 0;
      var deleted = 0;
      var copied = 0;
      var favorited = 0;
      final weights = <double>[];

      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) => FilledButton(
              onPressed: () => TagBottomActionSheet.show(
                context,
                tag: tag,
                onWeightChanged: weights.add,
                onToggleEnabled: () => toggled++,
                onEdit: () => edited++,
                onDelete: () => deleted++,
                onCopy: () => copied++,
                onToggleFavorite: () => favorited++,
              ),
              child: const Text('Open tag actions'),
            ),
          ),
          textScale: 3,
          keyboardInset: 120,
        ),
      );

      Future<void> openPanel() async {
        await tester.tap(find.text('Open tag actions'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('adaptive-bottom-sheet')),
          findsOneWidget,
        );
        expect(find.byType(DraggableScrollableSheet), findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      Future<void> invokeClosingAction(IconData icon) async {
        final action = find.byIcon(icon);
        final scrollable = find.byType(Scrollable).last;
        await tester.scrollUntilVisible(action, 160, scrollable: scrollable);
        await Scrollable.ensureVisible(
          tester.element(action),
          alignment: 0.5,
          duration: Duration.zero,
        );
        await tester.pump();
        await tester.tap(action);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('adaptive-bottom-sheet')),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      }

      await openPanel();
      final slider = find.byType(Slider);
      final scrollable = find.byType(Scrollable).last;
      await tester.scrollUntilVisible(slider, 160, scrollable: scrollable);
      await Scrollable.ensureVisible(
        tester.element(slider),
        alignment: 0.5,
        duration: Duration.zero,
      );
      await tester.pump();
      tester.widget<Slider>(slider).onChanged!(1.2);
      await tester.pump();
      expect(weights, isNotEmpty);
      expect(
        find.byKey(const ValueKey('adaptive-bottom-sheet')),
        findsOneWidget,
      );

      await invokeClosingAction(Icons.favorite_border);
      expect(favorited, 1);
      await openPanel();
      await invokeClosingAction(Icons.visibility_off_outlined);
      expect(toggled, 1);
      await openPanel();
      await invokeClosingAction(Icons.edit_outlined);
      expect(edited, 1);
      await openPanel();
      await invokeClosingAction(Icons.copy_outlined);
      expect(copied, 1);
      await openPanel();
      await invokeClosingAction(Icons.delete_outline);
      expect(deleted, 1);
    },
  );

  testWidgets('floating menu exposes the same weight command to keyboard', (
    tester,
  ) async {
    final weights = <double>[];
    await tester.pumpWidget(
      app(
        Align(
          alignment: Alignment.topLeft,
          child: FloatingActionMenu(
            tag: tag,
            onWeightChanged: weights.add,
            onToggleEnabled: () {},
            onEdit: () {},
            onDelete: () {},
            onCopy: () {},
          ),
        ),
        textScale: 3,
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(FloatingActionMenu)).width,
      lessThanOrEqualTo(296),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add));

    expect(weights.first, closeTo(1.05, 0.001));
    expect(weights.last, closeTo(1.15, 0.001));
  });

  testWidgets('portal honors an initially visible menu', (tester) async {
    await tester.pumpWidget(
      app(
        FloatingMenuPortal(
          showMenu: true,
          menuBuilder: (_) => const Text('menu-content'),
          child: const SizedBox(width: 80, height: 40),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('menu-content'), findsOneWidget);
  });
}
