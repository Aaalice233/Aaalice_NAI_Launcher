import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/shortcuts/default_shortcuts.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/themes/core/layered_surface_style.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/interaction/user_question.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/user_question_flow.dart';
import 'package:nai_launcher/presentation/widgets/shortcuts/shortcut_aware_widget.dart';

import '../../../fixtures/user_questions.dart';

Future<void> pumpFlow(
  WidgetTester tester, {
  double width = 390,
  double height = 760,
  double scale = 1,
  double keyboard = 0,
  ValueChanged<List<UserQuestionAnswer>>? onSubmit,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          viewInsets: EdgeInsets.only(bottom: keyboard),
          padding: const EdgeInsets.only(top: 24, bottom: 24),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: SafeArea(
          child: UserQuestionFlow(
            questions: testQuestions(),
            expiresAt: DateTime.now().add(const Duration(minutes: 2)),
            onSubmit: onSubmit ?? (_) {},
            onCancel: () {},
          ),
        ),
      ),
    ),
  );
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  testWidgets(
    'group surface and footer remain inside a short question viewport',
    (tester) async {
      await pumpFlow(tester, width: 360, height: 400);
      final card = find.byKey(const ValueKey('user-question-card'));
      final cancel = find.byKey(const ValueKey('user-question-cancel'));
      expect(
        tester.widget<Material>(card).color,
        sectionSurfaceColor(Theme.of(tester.element(card)).colorScheme),
      );
      expect(cancel.hitTestable(), findsOneWidget);
      final before = tester.getRect(cancel);
      await tester.drag(
        find.byKey(const ValueKey('user-question-option-appearance-classic')),
        const Offset(0, -250),
      );
      await tester.pump();
      expect(tester.getRect(cancel), before);
      expect(tester.getRect(card).contains(before.bottomRight), isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'recommendation is marked, answers advance, custom input and final review are editable',
    (tester) async {
      List<UserQuestionAnswer>? submitted;
      await pumpFlow(tester, onSubmit: (answers) => submitted = answers);
      expect(find.text('推荐'), findsOneWidget);
      expect(find.text('自定义'), findsOneWidget);
      expect(submitted, isNull);
      await tapVisible(
        tester,
        find.byKey(const ValueKey('user-question-option-appearance-classic')),
      );
      expect(find.text('问题 2 / 2'), findsOneWidget);
      await tapVisible(
        tester,
        find.byKey(const ValueKey('user-question-custom-option')),
      );
      final next = find.byKey(const ValueKey('user-question-next'));
      expect(tester.widget<FilledButton>(next).onPressed, isNull);
      final input = find.byKey(const ValueKey('user-question-custom-input'));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('user-question-custom-option')),
          matching: input,
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<EditableText>(
              find.descendant(of: input, matching: find.byType(EditableText)),
            )
            .focusNode
            .hasFocus,
        isTrue,
      );
      await tester.enterText(input, '旅行服装');
      await tapVisible(tester, next);
      expect(find.text('确认你的选择'), findsOneWidget);
      expect(submitted, isNull);
      await tapVisible(tester, find.text('上一个问题'));
      expect(tester.widget<TextField>(input).controller!.text, '旅行服装');
      await tapVisible(tester, next);
      await tapVisible(
        tester,
        find.byKey(const ValueKey('user-question-submit')),
      );
      expect(submitted!.first.optionId, 'classic');
      expect(submitted!.last.customText, '旅行服装');
      expect(tester.takeException(), isNull);
    },
  );

  for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
    testWidgets(
      'all options and submit remain reachable at $width with 3x text and IME',
      (tester) async {
        await pumpFlow(tester, width: width, scale: 3, keyboard: 220);
        for (final option in ['classic', 'daily', 'formal']) {
          final finder = find.byKey(
            ValueKey('user-question-option-appearance-$option'),
          );
          await tester.ensureVisible(finder);
          await tester.pump();
          expect(finder.hitTestable(), findsOneWidget);
        }
        await tapVisible(
          tester,
          find.byKey(const ValueKey('user-question-option-appearance-formal')),
        );
        await tapVisible(
          tester,
          find.byKey(const ValueKey('user-question-custom-option')),
        );
        final input = find.byKey(const ValueKey('user-question-custom-input'));
        await tester.ensureVisible(input);
        await tester.pump();
        await tester.enterText(input, '保留角色特征，采用旅行服装');
        await tapVisible(
          tester,
          find.byKey(const ValueKey('user-question-next')),
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('user-question-submit')),
        );
        await tester.pump();
        expect(
          find.byKey(const ValueKey('user-question-submit')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('short landscape can scroll through every question', (
    tester,
  ) async {
    await pumpFlow(tester, width: 740, height: 320, keyboard: 100);
    await tapVisible(
      tester,
      find.byKey(const ValueKey('user-question-option-appearance-classic')),
    );
    await tapVisible(
      tester,
      find.byKey(const ValueKey('user-question-option-scene-classic')),
    );
    await tapVisible(
      tester,
      find.byKey(const ValueKey('user-question-submit')),
    );
    expect(tester.takeException(), isNull);
  });

  group('与页面快捷键锚点同处一个路由作用域', () {
    testWidgets('自定义回答输入框出现即可输入', (tester) async {
      await pumpBesidePageShortcuts(tester);

      await openCustomInput(tester);

      expect(customEditableFocus(tester).hasPrimaryFocus, isTrue);
      tester.testTextInput.enterText('保留角色特征');
      await tester.pump();
      expect(
        tester.widget<EditableText>(customEditable).controller.text,
        '保留角色特征',
      );
    });

    testWidgets('鼠标点自定义回答输入框外部后，页面快捷键仍可触发', (tester) async {
      final page = await pumpBesidePageShortcuts(tester);
      await openCustomInput(tester);
      final inputFocus = customEditableFocus(tester);

      await tester.tapAt(
        tester.getCenter(find.byKey(pageKey)),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();

      expect(inputFocus.hasFocus, isFalse);
      await sendGenerateShortcut(tester);
      expect(page.generateCount, 1);
    });

    testWidgets('触屏点自定义回答输入框外部也会失焦并收起键盘', (tester) async {
      final page = await pumpBesidePageShortcuts(tester);
      await openCustomInput(tester);
      final inputFocus = customEditableFocus(tester);
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.tapAt(
        tester.getCenter(find.byKey(pageKey)),
        kind: PointerDeviceKind.touch,
      );
      await tester.pump();

      expect(inputFocus.hasFocus, isFalse);
      expect(tester.testTextInput.isVisible, isFalse);
      await sendGenerateShortcut(tester);
      expect(page.generateCount, 1);
    });

    testWidgets('答完一题切到下一题后，页面快捷键仍可触发', (tester) async {
      final page = await pumpBesidePageShortcuts(tester);

      await tapVisible(
        tester,
        find.byKey(const ValueKey('user-question-option-appearance-classic')),
      );
      expect(find.text('问题 2 / 2'), findsOneWidget);
      await sendGenerateShortcut(tester);
      expect(page.generateCount, 1);

      await openCustomInput(tester);
      tester.testTextInput.enterText('旅行服装');
      await tester.pump();
      await tapVisible(
        tester,
        find.byKey(const ValueKey('user-question-next')),
      );
      expect(find.text('确认你的选择'), findsOneWidget);
      await sendGenerateShortcut(tester);
      expect(page.generateCount, 2);
    });
  });
}

const pageKey = ValueKey('page');

final customEditable = find.descendant(
  of: find.byKey(const ValueKey('user-question-custom-input')),
  matching: find.byType(EditableText),
);

FocusNode customEditableFocus(WidgetTester tester) =>
    tester.widget<EditableText>(customEditable).focusNode;

class PageShortcutProbe {
  int generateCount = 0;
}

Future<PageShortcutProbe> pumpBesidePageShortcuts(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1180, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final probe = PageShortcutProbe();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        shortcutConfigNotifierProvider.overrideWith(
          _DefaultShortcutConfigNotifier.new,
        ),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          // 与生成页停靠的智能体面板一致：和页面锚点同处一个路由作用域
          body: Row(
            children: [
              Expanded(
                child: PageShortcuts(
                  contextType: ShortcutContext.generation,
                  shortcuts: {
                    ShortcutIds.generateImage: () => probe.generateCount++,
                  },
                  child: const SizedBox.expand(key: pageKey),
                ),
              ),
              SizedBox(
                width: 420,
                child: UserQuestionFlow(
                  questions: testQuestions(),
                  expiresAt: DateTime.now().add(const Duration(minutes: 2)),
                  onSubmit: (_) {},
                  onCancel: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  expect(Focus.of(tester.element(find.byKey(pageKey))).hasPrimaryFocus, isTrue);
  return probe;
}

Future<void> openCustomInput(WidgetTester tester) async {
  await tapVisible(
    tester,
    find.byKey(const ValueKey('user-question-custom-option')),
  );
  await tester.pump();
}

Future<void> sendGenerateShortcut(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

class _DefaultShortcutConfigNotifier extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() async => ShortcutConfig.createDefault();
}
