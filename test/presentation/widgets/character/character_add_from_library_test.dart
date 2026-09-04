import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';
import 'package:nai_launcher/data/repositories/character_prompt_repository.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/character_prompt_provider.dart';
import 'package:nai_launcher/presentation/providers/tag_library_page_provider.dart';
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

  Widget buildTestApp(Widget child, {List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: overrides,
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
    expect(
      find.byKey(const ValueKey('adaptive-centered-form')),
      findsOneWidget,
    );
    expect(find.byType(Dialog), findsNothing);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('wide toolbar character tooltip keeps a compact preview width', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final characterNotifier = _TestCharacterPromptNotifier(
      const CharacterPromptConfig(
        characters: [
          CharacterPrompt(
            id: 'char-1',
            name: 'Alice',
            prompt: 'girl, red hair',
          ),
          CharacterPrompt(id: 'char-2', name: 'Bob', prompt: 'boy, blue hair'),
        ],
      ),
    );
    await tester.pumpWidget(
      buildTestApp(
        const Align(
          alignment: Alignment.bottomCenter,
          child: CharacterPromptButton(),
        ),
        overrides: [
          characterPromptNotifierProvider.overrideWith(() => characterNotifier),
        ],
      ),
    );
    await tester.pumpAndSettle();

    final button = find.byType(CharacterPromptButton);
    final badge = find.byKey(const ValueKey('character-count-badge'));
    expect(badge, findsOneWidget);
    final buttonRect = tester.getRect(button);
    final badgeRect = tester.getRect(badge);
    expect(buttonRect.contains(badgeRect.topLeft), isTrue);
    expect(buttonRect.contains(badgeRect.bottomRight), isTrue);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(button));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    final preview = find.byKey(const Key('character-hover-preview'));
    expect(preview, findsOneWidget);
    expect(tester.getSize(preview).width, lessThanOrEqualTo(380));
    expect(tester.getSize(preview).width, lessThan(1920 / 2));
    expect(tester.takeException(), isNull);
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

    final addMenu = find.byKey(const Key('character-add-menu'));
    expect(addMenu, findsOneWidget);
    await tester.tap(addMenu);
    await tester.pumpAndSettle();
    expect(find.text('Library'), findsOneWidget);

    await openLibraryMenuItem(tester);

    expect(find.byType(TagLibraryPickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('library negative block populates independent character UC', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final entry = TagLibraryEntry.create(
      name: 'Alice negative',
      content: 'girl, blue eyes, negative(red hair, glasses)',
    );
    final characterNotifier = _TestCharacterPromptNotifier();

    await tester.pumpWidget(
      buildTestApp(
        const CharacterPromptButton(),
        overrides: [
          tagLibraryPageNotifierProvider.overrideWith(
            () => _TestTagLibraryPageNotifier([entry]),
          ),
          characterPromptNotifierProvider.overrideWith(() => characterNotifier),
        ],
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Characters'));
    await tester.pumpAndSettle();
    await openLibraryMenuItem(tester);
    await tester.tap(find.text('Alice negative'));
    await tester.pumpAndSettle();

    final character = characterNotifier.current.characters.single;
    expect(character.prompt, 'girl, blue eyes');
    expect(character.negativePrompt, 'red hair, glasses');
  });
}

class _TestTagLibraryPageNotifier extends TagLibraryPageNotifier {
  _TestTagLibraryPageNotifier(this.entries);

  final List<TagLibraryEntry> entries;

  @override
  TagLibraryPageState build() => TagLibraryPageState(entries: entries);

  @override
  Future<void> recordUsage(String id) async {}
}

class _TestCharacterPromptNotifier extends CharacterPromptNotifier {
  _TestCharacterPromptNotifier([this.initial = const CharacterPromptConfig()]);

  final CharacterPromptConfig initial;

  CharacterPromptConfig get current => state;

  @override
  CharacterPromptConfig build() => initial;

  @override
  void addCharacter(
    CharacterGender gender, {
    String? name,
    String? prompt,
    String? negativePrompt,
    String? thumbnailPath,
  }) {
    state = state.addCharacter(
      gender: gender,
      name: name,
      prompt: prompt,
      negativePrompt: negativePrompt,
      thumbnailPath: thumbnailPath,
    );
  }
}
