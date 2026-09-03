import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/common/draggable_number_input.dart';
import 'package:nai_launcher/presentation/widgets/common/editable_double_field.dart';

void main() {
  testWidgets('touch numeric inputs keep 48px targets', (tester) async {
    await tester.pumpWidget(
      _harness(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DraggableNumberInput(value: 2, max: 9, onChanged: (_) {}),
            const SizedBox(width: 8),
            EditableDoubleField(value: 1.25, onChanged: (_) {}),
          ],
        ),
      ),
    );

    expect(
      tester.getSize(find.byType(DraggableNumberInput)).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byType(EditableDoubleField)).height,
      greaterThanOrEqualTo(48),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'large text expands the field and resize preserves editing state',
    (tester) async {
      final mediaQuery = ValueNotifier(
        const MediaQueryData(
          size: Size(320, 568),
          textScaler: TextScaler.linear(3),
        ),
      );
      addTearDown(mediaQuery.dispose);

      await tester.pumpWidget(
        ValueListenableBuilder<MediaQueryData>(
          valueListenable: mediaQuery,
          builder: (context, data, _) => _harness(
            mediaQuery: data,
            child: EditableDoubleField(value: -12.34, onChanged: (_) {}),
          ),
        ),
      );

      final initialWidth = tester
          .getSize(find.byType(EditableDoubleField))
          .width;
      expect(initialWidth, greaterThan(64));

      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), '2.75');
      mediaQuery.value = mediaQuery.value.copyWith(size: const Size(840, 600));
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller!.text, '2.75');
      expect(field.focusNode!.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}

Widget _harness({required Widget child, MediaQueryData? mediaQuery}) {
  return MaterialApp(
    home: MediaQuery(
      data: mediaQuery ?? const MediaQueryData(size: Size(320, 568)),
      child: InteractionPolicyScope(
        initialPolicy: const InteractionPolicy(
          modality: InteractionModality.touch,
          touchAvailable: true,
          precisePointerAvailable: false,
        ),
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}
