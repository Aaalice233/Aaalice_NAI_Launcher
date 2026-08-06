import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/data/repositories/character_prompt_repository.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/character/character_prompt_button.dart';
import 'package:nai_launcher/presentation/widgets/character/inline_character_row.dart';
import 'package:nai_launcher/presentation/widgets/tag_library/tag_library_picker_dialog.dart';

void main() {
  late Directory hiveTempDir;

  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    hiveTempDir = await Directory.systemTemp.createTemp(
      'nai_launcher_character_library_menu_hive_',
    );
    Hive.init(hiveTempDir.path);
    await Hive.openBox(StorageKeys.settingsBox);
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveTempDir.exists()) {
      await hiveTempDir.delete(recursive: true);
    }
  });

  setUp(() async {
    await Hive.box(StorageKeys.settingsBox).clear();
    await Hive.box(
      StorageKeys.settingsBox,
    ).put(StorageKeys.enableAutocomplete, false);
  });

  Widget buildTestApp(Widget child) {
    return ProviderScope(
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  Future<void> openLibraryMenuItem(WidgetTester tester) async {
    await tester.tap(find.text('Library').last);
    await tester.pumpAndSettle();
  }

  testWidgets('empty character toolbar opens the library picker', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildTestApp(const CharacterPromptButton()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Characters'));
    await tester.pumpAndSettle();
    expect(find.text('Library'), findsOneWidget);

    await openLibraryMenuItem(tester);

    expect(find.byType(TagLibraryPickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('classic character row opens the library picker', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.runAsync(
      () => CharacterPromptRepository().save(
        const CharacterPromptConfig(
          characters: [
            CharacterPrompt(id: 'char-1', name: 'Alice', prompt: 'girl'),
          ],
        ),
      ),
    );
    await tester.pumpWidget(buildTestApp(const InlineCharacterRow()));
    await tester.pumpAndSettle();

    final addMenu = find.byWidgetPredicate(
      (widget) => widget is PopupMenuButton,
      description: 'classic character row add menu',
    );
    expect(addMenu, findsOneWidget);
    await tester.tap(addMenu);
    await tester.pumpAndSettle();
    expect(find.text('Library'), findsOneWidget);

    await openLibraryMenuItem(tester);

    expect(find.byType(TagLibraryPickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });
}
