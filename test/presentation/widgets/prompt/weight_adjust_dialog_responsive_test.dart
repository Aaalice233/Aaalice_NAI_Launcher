import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/prompt_tag.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/prompt/weight_adjust_dialog.dart';

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

  testWidgets('320dp、3x、IME 与 SafeArea 下权重面板命令保持可达', (tester) async {
    final weights = <double>[];
    await tester.pumpWidget(
      _app(
        onPressed: (context) => WeightAdjustDialog.show(
          context,
          tag: _tag,
          onWeightChanged: weights.add,
          onToggleEnabled: () {},
          onDelete: () {},
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsOneWidget);
    expect(find.textContaining(']]'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pump();
    expect(weights.last, closeTo(0.95, 0.001));

    final increase = find.byIcon(Icons.add);
    await tester.ensureVisible(increase);
    await tester.tap(increase);
    await tester.pump();
    expect(weights.last, closeTo(1.0, 0.001));
  });

  testWidgets('嵌套标签文本编辑使用长表单并保留确认语义', (tester) async {
    String? changedText;
    await tester.pumpWidget(
      _app(
        onPressed: (context) => TagEditDialog.show(
          context,
          tag: _tag,
          onTextChanged: (value) => changedText = value,
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'replacement tag');
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(changedText, 'replacement tag');
    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide weight panel remains bounded instead of stretching', (
    tester,
  ) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.single;
    view.devicePixelRatio = 1;
    view.physicalSize = const Size(1600, 900);

    await tester.pumpWidget(
      MaterialApp(
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => WeightAdjustDialog.show(
                context,
                tag: const PromptTag(id: 'tag', text: 'cat'),
                onWeightChanged: (_) {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final panel = find.byKey(const ValueKey('adaptive-centered-form'));
    expect(panel, findsOneWidget);
    expect(tester.getSize(panel).width, lessThanOrEqualTo(640));
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide tag edit form follows its content height', (tester) async {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.single;
    view.devicePixelRatio = 1;
    view.physicalSize = const Size(1000, 800);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () =>
                  TagEditDialog.show(context, tag: _tag, onTextChanged: (_) {}),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final panel = find.byKey(const ValueKey('adaptive-centered-form'));
    expect(panel, findsOneWidget);
    expect(tester.getSize(panel).height, lessThan(320));
    expect(tester.getRect(panel).center.dy, moreOrLessEquals(400));
    expect(tester.takeException(), isNull);
  });
}

Widget _app({required ValueChanged<BuildContext> onPressed}) {
  return MaterialApp(
    locale: const Locale('zh'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: const TextScaler.linear(3),
        padding: const EdgeInsets.fromLTRB(12, 24, 12, 24),
        viewInsets: const EdgeInsets.only(bottom: 120),
      ),
      child: child!,
    ),
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => onPressed(context),
          child: const Text('open'),
        ),
      ),
    ),
  );
}

const _tag = PromptTag(
  id: 'tag',
  text: 'long_character_name_for_responsive_layout',
  translation: '长翻译文本验证三倍字体布局',
  weight: 0.9,
);
