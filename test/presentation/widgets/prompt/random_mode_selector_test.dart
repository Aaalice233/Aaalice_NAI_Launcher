import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/prompt/random_mode_selector.dart';

import '../../../helpers/flutter_error_collector.dart';

void main() {
  testWidgets(
    'RandomModeSelector exposes one default, custom, and hybrid mode',
    (tester) async {
      final storage = _FakeRandomModeStorage();

      await tester.pumpWidget(
        _buildTestApp(storage: storage, child: const RandomModeSelector()),
      );

      expect(find.text('Default'), findsOneWidget);
      expect(find.text('Custom Mode'), findsOneWidget);
      expect(find.text('Hybrid Mode'), findsOneWidget);
      expect(
        find.text(
          'Automatically select the bundled random recipe for the current model',
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('RandomModePopupMenu exposes hybrid mode', (tester) async {
    final storage = _FakeRandomModeStorage();

    await tester.pumpWidget(
      _buildTestApp(
        storage: storage,
        child: const RandomModePopupMenu(child: Text('mode menu')),
      ),
    );

    await tester.tap(find.text('mode menu'));
    await tester.pumpAndSettle();

    expect(find.text('Default'), findsOneWidget);
    expect(find.text('Custom Mode'), findsOneWidget);
    expect(find.text('Hybrid Mode'), findsOneWidget);
  });

  testWidgets(
    'RandomModeBottomSheet real entry adapts at compact worst-case and wide widths',
    (tester) async {
      final flutterErrors = FlutterErrorCollector.install(tester);
      addTearDown(flutterErrors.restoreAndAssertNoErrors);
      final storage = _FakeRandomModeStorage();
      var changedCount = 0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;

      for (final size in [const Size(320, 480), const Size(1200, 800)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          _buildTestApp(
            storage: storage,
            textScaler: size.width < 600
                ? const TextScaler.linear(2)
                : TextScaler.noScaling,
            child: Builder(
              builder: (context) => FilledButton(
                onPressed: () => RandomModeBottomSheet.show(
                  context,
                  onModeChanged: () => changedCount++,
                ),
                child: const Text('open random mode'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('open random mode'));
        await tester.pumpAndSettle();

        expect(
          find.byKey(
            ValueKey(
              size.width < 600
                  ? 'adaptive-bottom-sheet'
                  : 'adaptive-side-sheet',
            ),
          ),
          findsOneWidget,
          reason: 'size=$size',
        );
        expect(find.text('Hybrid Mode'), findsOneWidget);
        flutterErrors.expectNoErrors(reason: 'size=$size');

        if (size.width < 600) {
          await tester.tap(find.text('Default'));
          await tester.pumpAndSettle();
          expect(storage.mode, 'nai_official');
          expect(changedCount, 1);
        } else {
          await tester.tap(find.byTooltip('Close'));
          await tester.pumpAndSettle();
        }
      }
    },
  );

  testWidgets('RandomModeIndicator displays a distinct hybrid label', (
    tester,
  ) async {
    final storage = _FakeRandomModeStorage(initialMode: 'hybrid');

    await tester.pumpWidget(
      _buildTestApp(storage: storage, child: const RandomModeIndicator()),
    );

    expect(find.text('Hybrid Mode'), findsOneWidget);
    expect(find.text('Custom'), findsNothing);
  });
}

Widget _buildTestApp({
  required LocalStorageService storage,
  required Widget child,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return ProviderScope(
    overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Scaffold(body: Center(child: child)),
    ),
  );
}

class _FakeRandomModeStorage extends LocalStorageService {
  _FakeRandomModeStorage({String initialMode = 'nai_official'})
    : mode = initialMode;

  String mode;

  @override
  String getRandomGenerationMode() => mode;

  @override
  Future<void> setRandomGenerationMode(String value) async {
    mode = value;
  }
}
