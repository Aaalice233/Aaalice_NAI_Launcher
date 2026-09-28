import 'package:flutter/material.dart';
import 'package:nai_launcher/presentation/themes/core/layered_surface_style.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/interaction/user_question.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/user_question_flow.dart';

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
}
