import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/prompt/diy/dialogs/rule_condition_dialog_scaffold.dart';

void main() {
  testWidgets('renders the injected panel and gates the save action', (
    tester,
  ) async {
    await _open(tester, initialValue: 'initial');

    expect(
      find.byKey(const ValueKey('sample-condition-dialog')),
      findsOneWidget,
    );
    expect(find.text('initial'), findsOneWidget);
    expect(_saveButton(tester).onPressed, isNull);
    expect(_clear, findsOneWidget);
    expect(_cancel, findsOneWidget);
  });

  testWidgets('hides the clear action while no value is set', (tester) async {
    await _open(tester, initialValue: null);

    expect(find.text('empty'), findsOneWidget);
    expect(_clear, findsNothing);
    expect(_cancel, findsOneWidget);
  });

  testWidgets('keeps the dialog open while nothing changed', (tester) async {
    final result = await _open(tester, initialValue: 'initial');

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('sample-condition-dialog')),
      findsOneWidget,
    );
    expect(result.isCompleted, isFalse);
  });

  testWidgets('submits the value reported by the panel', (tester) async {
    final result = await _open(tester, initialValue: 'initial');

    await tester.tap(find.byKey(const ValueKey('sample-panel-edit')));
    await tester.pumpAndSettle();
    expect(find.text('edited'), findsOneWidget);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(await result.future, 'edited');
  });

  testWidgets('clearing submits a null value', (tester) async {
    final result = await _open(tester, initialValue: 'initial');

    await tester.tap(_clear);
    await tester.pumpAndSettle();
    expect(_clear, findsNothing);

    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(await result.future, isNull);
  });

  testWidgets('cancelling reports no value', (tester) async {
    final result = await _open(tester, initialValue: 'initial');

    await tester.tap(_cancel);
    await tester.pumpAndSettle();

    expect(await result.future, isNull);
    expect(find.byKey(const ValueKey('sample-condition-dialog')), findsNothing);
  });

  testWidgets('keeps every action reachable at 320dp, 3x text and IME', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(960, 1920);
    tester.view.padding = const FakeViewPadding(
      top: 72,
      left: 24,
      right: 24,
      bottom: 72,
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 600);
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
      tester.view.resetPadding();
      tester.view.resetViewInsets();
    });

    final result = await _open(tester, initialValue: 'initial', textScale: 3);

    expect(
      find.byKey(const ValueKey('sample-condition-compact-scroll')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    for (final action in [_cancel, _clear, find.byType(FilledButton)]) {
      await tester.ensureVisible(action);
      await tester.pump();
      expect(action, findsOneWidget);
    }
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.byKey(const ValueKey('sample-panel-edit')));
    await tester.tap(find.byKey(const ValueKey('sample-panel-edit')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byType(FilledButton));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();

    expect(await result.future, 'edited');
    expect(tester.takeException(), isNull);
  });
}

final Finder _cancel = find.widgetWithText(TextButton, 'Cancel');
final Finder _clear = find.widgetWithText(TextButton, 'Clear');

FilledButton _saveButton(WidgetTester tester) =>
    tester.widget<FilledButton>(find.byType(FilledButton));

Future<Completer<String?>> _open(
  WidgetTester tester, {
  required String? initialValue,
  double textScale = 1,
}) async {
  final result = Completer<String?>();
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              final value = await RuleConditionDialogScaffold.show<String>(
                context: context,
                icon: Icons.call_split,
                titleBuilder: (context) => 'Sample condition',
                dialogWidth: 600,
                builder: (context, scrollController) =>
                    RuleConditionDialogScaffold<String>(
                      keyPrefix: 'sample-condition',
                      initialValue: initialValue,
                      scrollController: scrollController,
                      panelBuilder: (context, value, onChanged) =>
                          _SamplePanel(value: value, onChanged: onChanged),
                    ),
              );
              result.complete(value);
            },
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return result;
}

class _SamplePanel extends StatelessWidget {
  const _SamplePanel({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value ?? 'empty'),
        IconButton(
          key: const ValueKey('sample-panel-edit'),
          onPressed: () => onChanged('edited'),
          icon: const Icon(Icons.edit),
        ),
      ],
    );
  }
}
