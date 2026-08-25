import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/prompt/random_mode_selector.dart';

void main() {
  testWidgets('RandomModeSelector exposes official, custom, and hybrid modes',
      (tester) async {
    final storage = _FakeRandomModeStorage();

    await tester.pumpWidget(
      _buildTestApp(
        storage: storage,
        child: const RandomModeSelector(),
      ),
    );

    expect(find.text('Offline Library'), findsOneWidget);
    expect(find.text('Custom Mode'), findsOneWidget);
    expect(find.text('Hybrid Mode'), findsOneWidget);
  });

  testWidgets('RandomModePopupMenu exposes hybrid mode', (tester) async {
    final storage = _FakeRandomModeStorage();

    await tester.pumpWidget(
      _buildTestApp(
        storage: storage,
        child: const RandomModePopupMenu(
          child: Text('mode menu'),
        ),
      ),
    );

    await tester.tap(find.text('mode menu'));
    await tester.pumpAndSettle();

    expect(find.text('Offline Library'), findsOneWidget);
    expect(find.text('Custom Mode'), findsOneWidget);
    expect(find.text('Hybrid Mode'), findsOneWidget);
  });

  testWidgets('RandomModeIndicator displays a distinct hybrid label',
      (tester) async {
    final storage = _FakeRandomModeStorage(initialMode: 'hybrid');

    await tester.pumpWidget(
      _buildTestApp(
        storage: storage,
        child: const RandomModeIndicator(),
      ),
    );

    expect(find.text('Hybrid Mode'), findsOneWidget);
    expect(find.text('Custom'), findsNothing);
  });
}

Widget _buildTestApp({
  required LocalStorageService storage,
  required Widget child,
}) {
  return ProviderScope(
    overrides: [
      localStorageServiceProvider.overrideWith((ref) => storage),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: Center(child: child),
      ),
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
