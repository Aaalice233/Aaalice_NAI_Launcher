import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt/dependency_config.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';
import 'package:nai_launcher/presentation/widgets/prompt/diy/dialogs/dependency_config_dialog.dart';
import 'package:nai_launcher/presentation/widgets/prompt/diy/panels/dependency_config_panel.dart';

void main() {
  testWidgets('320px、3x 文本、SafeArea 与 IME 下字段和动作均可达', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewInsets();
    });

    await _pumpLauncher(tester, textScale: 3);
    await tester.tap(find.byKey(const ValueKey('open-dependency-dialog')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('dependency-config-scroll')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    final dialog = tester.getRect(
      find.byKey(const ValueKey('dependency-config-dialog')),
    );
    expect(dialog.left, greaterThanOrEqualTo(0));
    expect(dialog.right, lessThanOrEqualTo(320));

    final fields = [
      find.byType(DropdownButtonFormField<String>),
      find.byType(EditableText),
    ];
    for (final field in fields) {
      expect(field, findsOneWidget);
      await tester.ensureVisible(field);
      await tester.pump();
      expect(tester.getRect(field).overlaps(dialog), isTrue);
      expect(tester.takeException(), isNull);
    }

    for (final action in [
      find.byIcon(Icons.block_rounded),
      find.byIcon(Icons.add_rounded),
      find.byType(Switch),
    ]) {
      await tester.ensureVisible(action.first);
      await tester.pump();
      expect(tester.getRect(action.first).overlaps(dialog), isTrue);
      expect(tester.takeException(), isNull);
    }

    final dependencyType = find.byIcon(Icons.block_rounded);
    await tester.ensureVisible(dependencyType);
    await tester.pump();
    await tester.tap(dependencyType);
    await tester.pump();

    final save = find.widgetWithText(FilledButton, '保存');
    expect(save, findsOneWidget);
    expect(tester.getRect(save).bottom, lessThanOrEqualTo(460));
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(find.byType(DependencyConfigDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('320px、3x、IME 与 SafeArea 下映射规则全屏编辑并保留输入状态', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetPadding();
      tester.view.resetViewInsets();
    });

    DependencyConfig? changedConfig;
    await _pumpPanel(
      tester,
      textScale: 3,
      onChanged: (config) => changedConfig = config,
    );
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('mapping-rule-form')), findsOneWidget);
    final submit = find.byKey(const ValueKey('mapping-rule-submit'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('mapping-rule-source')),
      's',
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mapping-rule-source')), findsOneWidget);
    expect(find.byKey(const ValueKey('mapping-rule-value')), findsOneWidget);
    expect(
      tester
          .widget<ThemedInput>(
            find.byKey(const ValueKey('mapping-rule-source')),
          )
          .controller
          ?.text,
      's',
    );

    await tester.enterText(
      find.byKey(const ValueKey('mapping-rule-value')),
      'r',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
    expect(tester.getRect(submit).bottom, lessThanOrEqualTo(460));
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(changedConfig?.mappingRules, {'s': 'r'});
    expect(find.byKey(const ValueKey('mapping-rule-form')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Expanded 映射规则编辑使用居中弹窗并可取消返回', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    var changes = 0;
    await _pumpPanel(tester, onChanged: (_) => changes++);
    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pumpAndSettle();

    final dialog = tester.getRect(
      find.byKey(const ValueKey('adaptive-centered-form')),
    );
    expect(dialog.width, lessThanOrEqualTo(480));
    expect(dialog.center.dx, moreOrLessEquals(800));

    await tester.enterText(
      find.byKey(const ValueKey('mapping-rule-source')),
      'not-saved',
    );
    await tester.tap(find.widgetWithText(TextButton, '取消'));
    await tester.pumpAndSettle();

    expect(changes, 0);
    expect(find.byKey(const ValueKey('mapping-rule-form')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Expanded 使用受限宽度居中弹窗且保留完整动作', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await _pumpLauncher(tester);
    await tester.tap(find.byKey(const ValueKey('open-dependency-dialog')));
    await tester.pumpAndSettle();

    final dialog = tester.getRect(
      find.byKey(const ValueKey('dependency-config-dialog')),
    );
    expect(dialog.width, lessThanOrEqualTo(560));
    expect(dialog.center.dx, moreOrLessEquals(800));
    expect(find.widgetWithText(TextButton, '取消'), findsOneWidget);
    expect(find.widgetWithText(TextButton, '清除'), findsWidgets);
    expect(find.widgetWithText(FilledButton, '保存'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pumpPanel(
  WidgetTester tester, {
  double textScale = 1,
  required ValueChanged<DependencyConfig?> onChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: textScale >= 2 ? 600 : tester.view.physicalSize.width,
            child: SingleChildScrollView(
              child: DependencyConfigPanel(
                config: const DependencyConfig(sourceCategoryId: 'characters'),
                availableCategories: const ['characters'],
                onConfigChanged: onChanged,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.ensureVisible(find.byIcon(Icons.add_rounded));
  await tester.pump();
}

Future<void> _pumpLauncher(WidgetTester tester, {double textScale = 1}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              key: const ValueKey('open-dependency-dialog'),
              onPressed: () => DependencyConfigDialog.show(
                context,
                initialConfig: const DependencyConfig(
                  sourceCategoryId: 'characters',
                  mappingRules: {'1': '0-3'},
                  defaultValue: '0',
                ),
                availableCategories: const ['characters', 'outfits'],
              ),
              child: const Text('打开'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
