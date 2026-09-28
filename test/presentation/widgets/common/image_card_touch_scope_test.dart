import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/widgets/common/card_action_buttons.dart';
import 'package:nai_launcher/presentation/widgets/common/image_card_action.dart';
import 'package:nai_launcher/presentation/widgets/common/image_card_action_region.dart';
import 'package:nai_launcher/presentation/widgets/common/image_card_batch_scope.dart';

void main() {
  for (final selected in [true, false]) {
    testWidgets(
      'touch menu applies ${selected ? 'selected batch' : 'single unselected'} scope',
      (tester) async {
        var singleCalls = 0;
        var batchCalls = 0;
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: InteractionPolicyScope(
              initialPolicy: const InteractionPolicy(
                modality: InteractionModality.touch,
                touchAvailable: true,
                precisePointerAvailable: false,
              ),
              child: Scaffold(
                body: ImageCardBatchScope(
                  targetIds: const {'a', 'b'},
                  actions: [
                    ImageCardAction(
                      id: ImageCardActionId.export,
                      icon: Icons.download,
                      label: 'Export batch',
                      supportsBatch: true,
                      invoke: () => batchCalls++,
                    ),
                  ],
                  child: ImageCardActionRegion(
                    resourceId: selected ? 'a' : 'c',
                    actions: [
                      ImageCardAction(
                        id: ImageCardActionId.edit,
                        icon: Icons.edit,
                        label: 'Edit single',
                        invoke: () => singleCalls++,
                      ),
                    ],
                    builder: (context, actions) =>
                        CardActionButtons(visible: true, buttons: actions),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.byTooltip('More actions'));
        await tester.pumpAndSettle();
        expect(
          find.text(selected ? 'Export batch' : 'Edit single'),
          findsOneWidget,
        );
        expect(
          find.text(selected ? 'Edit single' : 'Export batch'),
          findsNothing,
        );
        await tester.tap(find.text(selected ? 'Export batch' : 'Edit single'));
        await tester.pumpAndSettle();
        expect(batchCalls, selected ? 1 : 0);
        expect(singleCalls, selected ? 0 : 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
