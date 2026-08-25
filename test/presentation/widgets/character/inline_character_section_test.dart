import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/character_prompt_provider.dart';
import 'package:nai_launcher/presentation/widgets/character/inline_character_card.dart';
import 'package:nai_launcher/presentation/widgets/character/inline_character_section.dart';

class _TestCharacterPromptNotifier extends CharacterPromptNotifier {
  @override
  CharacterPromptConfig build() {
    return const CharacterPromptConfig(
      characters: [
        CharacterPrompt(id: 'alice', name: 'Alice', prompt: 'red hair'),
        CharacterPrompt(id: 'bob', name: 'Bob', prompt: 'blue hair'),
      ],
    );
  }
}

class _MemoryStorage extends LocalStorageService {
  final Map<String, Object?> values = {};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    final value = values[key];
    return value is T ? value : defaultValue;
  }

  @override
  Future<void> setSetting<T>(String key, T value) async {
    values[key] = value;
  }
}

void main() {
  ProviderContainer createContainer() {
    final storage = _MemoryStorage();
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWith((ref) => storage),
        characterPromptNotifierProvider.overrideWith(
          _TestCharacterPromptNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Widget subject(ProviderContainer container, double width) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SizedBox(width: width, child: const InlineCharacterSection()),
        ),
      ),
    );
  }

  testWidgets('默认折叠显示实时摘要，展开内容与生成角色状态不变', (tester) async {
    final container = createContainer();
    final before = container.read(characterPromptNotifierProvider);

    await tester.pumpWidget(subject(container, 700));
    await tester.pumpAndSettle();

    expect(find.text('已启用 2 个 · Alice +1'), findsOneWidget);
    expect(find.byType(InlineCharacterCard), findsNothing);

    await tester.tap(find.byKey(const Key('collapsible-header-角色')).first);
    await tester.pumpAndSettle();

    expect(find.byType(InlineCharacterCard), findsNWidgets(2));
    expect(container.read(characterPromptNotifierProvider), before);

    await tester.tap(find.byKey(const Key('collapsible-header-角色')).first);
    await tester.pumpAndSettle();
    expect(find.text('已启用 2 个 · Alice +1'), findsOneWidget);
  });

  for (final width in [700.0, 840.0, 1180.0, 1600.0]) {
    testWidgets('角色菜单在 $width 宽度无 RenderFlex overflow', (tester) async {
      final container = createContainer();
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(subject(container, width));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('collapsible-header-角色')).first);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(InlineCharacterCard), findsNWidgets(2));
    });
  }
}
