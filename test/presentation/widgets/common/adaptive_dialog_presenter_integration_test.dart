import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/bulk_operation_provider.dart';
import 'package:nai_launcher/presentation/providers/update_provider.dart';
import 'package:nai_launcher/presentation/widgets/bulk_progress_dialog.dart';
import 'package:nai_launcher/presentation/widgets/common/emoji_picker_dialog.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input_dialog.dart';
import 'package:nai_launcher/presentation/widgets/common/update_check_dialog.dart';

class _StaticBulkOperationNotifier extends BulkOperationNotifier {
  @override
  BulkOperationState build() => const BulkOperationState(
    currentOperation: BulkOperationType.export,
    isOperationInProgress: true,
    currentProgress: 1,
    totalItems: 4,
  );
}

class _CheckingUpdateNotifier extends UpdateStateNotifier {
  @override
  UpdateState build() => const UpdateState(status: UpdateStatus.checking);
}

void main() {
  Future<void> pumpHost(
    WidgetTester tester, {
    required Size size,
    required Widget Function(BuildContext context) trigger,
    List<Override> overrides = const [],
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(body: Builder(builder: trigger)),
        ),
      ),
    );
  }

  testWidgets('emoji picker composes with the compact full-screen presenter', (
    tester,
  ) async {
    await pumpHost(
      tester,
      size: const Size(400, 800),
      trigger: (context) => FilledButton(
        onPressed: () => unawaited(EmojiPickerDialog.show(context)),
        child: const Text('Open emoji'),
      ),
    );

    await tester.tap(find.text('Open emoji'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('adaptive-full-screen-form')),
      findsOneWidget,
    );
    expect(find.byType(Dialog), findsNothing);
    expect(find.text('Cancel'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel'), findsNothing);
  });

  testWidgets('validated input returns through the centered desktop dialog', (
    tester,
  ) async {
    String? result;
    await pumpHost(
      tester,
      size: const Size(1000, 800),
      trigger: (context) => FilledButton(
        onPressed: () async {
          result = await ThemedInputDialog.show(
            context: context,
            title: 'Validated name',
            validator: (value) => value == 'bad' ? 'Invalid name' : null,
          );
        },
        child: const Text('Open input'),
      ),
    );

    await tester.tap(find.text('Open input'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('adaptive-centered-form')),
      findsOneWidget,
    );
    expect(find.byType(Dialog), findsNothing);

    await tester.enterText(find.byType(TextField), 'bad');
    await tester.pump();
    expect(find.text('Invalid name'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton).last).onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextField), '  valid name  ');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pumpAndSettle();
    expect(result, 'valid name');
  });

  testWidgets(
    'update manager keeps its non-dismissible barrier in a centered dialog',
    (tester) async {
      await pumpHost(
        tester,
        size: const Size(1000, 800),
        overrides: [
          updateStateNotifierProvider.overrideWith(_CheckingUpdateNotifier.new),
        ],
        trigger: (context) => FilledButton(
          onPressed: () => unawaited(UpdateCheckDialog.show(context)),
          child: const Text('Open update'),
        ),
      );

      await tester.tap(find.text('Open update'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byKey(const ValueKey('adaptive-centered-form')),
        findsOneWidget,
      );
      expect(find.byType(Dialog), findsNothing);

      await tester.tapAt(const Offset(50, 400));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Checking for updates...'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Checking for updates...'), findsNothing);
    },
  );

  testWidgets('bulk manager uses a locked compact panel and preserves false', (
    tester,
  ) async {
    bool? result;
    await pumpHost(
      tester,
      size: const Size(400, 800),
      overrides: [
        bulkOperationNotifierProvider.overrideWith(
          _StaticBulkOperationNotifier.new,
        ),
      ],
      trigger: (context) => FilledButton(
        onPressed: () async => result = await BulkProgressDialog.show(context),
        child: const Text('Open progress'),
      ),
    );

    await tester.tap(find.text('Open progress'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);

    await tester.tapAt(const Offset(20, 20));
    await tester.pumpAndSettle();
    expect(find.text('Continue in background'), findsOneWidget);

    await tester.tap(find.text('Continue in background'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}
