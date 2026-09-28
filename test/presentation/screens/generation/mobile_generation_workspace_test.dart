import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/generation/mobile_generation_workspace.dart';

void main() {
  testWidgets('移动端提示词概览将字数放在第二行右侧且摘要占满剩余宽度', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 160));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_subject(prompt: List.filled(632, 'a').join()));
    await tester.pumpAndSettle();

    final primaryRow = find.byKey(
      const ValueKey('generation-prompt-overview-primary-row'),
    );
    final secondaryRow = find.byKey(
      const ValueKey('generation-prompt-overview-secondary-row'),
    );
    final characters = find.byKey(
      const ValueKey('generation-prompt-overview-characters'),
    );
    final launcher = find.byKey(
      const ValueKey('generation-collapsed-prompt-launcher'),
    );
    final summaryFinder = find.byKey(
      const ValueKey('generation-prompt-overview-summary'),
    );
    final summary = tester.widget<Text>(summaryFinder);

    expect(find.text('632 字'), findsOneWidget);
    expect(summary.softWrap, isFalse);
    expect(
      tester.getRect(summaryFinder).right,
      closeTo(tester.getRect(launcher).right - 10, 0.1),
    );
    expect(tester.getSize(summaryFinder).width, greaterThan(200));
    expect(
      tester.getCenter(primaryRow).dy,
      lessThan(tester.getCenter(characters).dy),
    );
    expect(
      tester.getCenter(secondaryRow).dy,
      closeTo(tester.getCenter(characters).dy, 0.1),
    );
    expect(find.byIcon(Icons.open_in_full_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320 宽度与 3x 文本下提示词概览不溢出', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 240));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _subject(
        prompt: List.filled(120, 'a').join(),
        textScaler: const TextScaler.linear(3),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('generation-prompt-overview-characters')),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.open_in_full_rounded), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Widget _subject({required String prompt, TextScaler? textScaler}) =>
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: MobileCollapsedPromptLauncher(
              prompt: prompt,
              characterCount: 1,
              qualityEnabled: true,
              negativePresetLabel: '负面预设',
              fixedTagCount: 2,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
