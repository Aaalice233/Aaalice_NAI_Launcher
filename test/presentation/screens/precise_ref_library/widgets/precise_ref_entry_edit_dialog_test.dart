import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/enums/precise_ref_type.dart';
import 'package:nai_launcher/data/models/precise_ref/precise_ref_library_entry.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/precise_ref_library/widgets/precise_ref_entry_edit_dialog.dart';

import '../../../../helpers/labeled_rows_expectations.dart';

final _entry = PreciseRefLibraryEntry(
  id: 'entry',
  name: '参考',
  imagePath: 'entry.png',
  typeIndex: PreciseRefType.character.index,
  strength: 0.6,
  fidelity: 0.4,
  createdAt: DateTime(2026),
);

void main() {
  testWidgets('数值框提交与滑块拖动都写回结果，数值框不受滑块区间限制', (tester) async {
    PreciseRefEntryEditResult? result;
    await _open(
      tester,
      locale: 'zh',
      width: 840,
      onResult: (value) => result = value,
    );

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('precise-ref-edit-strength-field')),
        matching: find.byType(EditableText),
      ),
      '1.5',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    final fidelity = labeledRowSlider('保真度');
    await tester.tapAt(tester.getCenter(fidelity));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('precise-ref-edit-confirm')));
    await tester.pumpAndSettle();
    expect(result?.strength, 1.5);
    expect(result?.fidelity, 0.5);
  });

  for (final locale in const ['zh', 'ja', 'en']) {
    for (final width in labeledRowWidths) {
      for (final scale in labeledRowTextScales) {
        final scenario = '$locale ${width.toInt()} ${scale}x';
        testWidgets('$scenario 下强度与保真度行标签完整且可达', (tester) async {
          await _open(tester, locale: locale, width: width, textScale: scale);
          expect(tester.takeException(), isNull, reason: scenario);

          final l10n = lookupAppLocalizations(Locale(locale));
          await expectLabeledSliderRows(
            tester,
            labels: [l10n.preciseRef_strength, l10n.preciseRef_fidelity],
            labelsSingleLine: locale != 'en',
            reason: scenario,
          );
          expect(tester.takeException(), isNull, reason: scenario);
        });
      }
    }
  }
}

Future<void> _open(
  WidgetTester tester, {
  required String locale,
  required double width,
  double textScale = 1,
  ValueChanged<PreciseRefEntryEditResult?>? onResult,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(locale),
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
              final result = await PreciseRefEntryEditDialog.show(
                context,
                _entry,
              );
              onResult?.call(result);
            },
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}
