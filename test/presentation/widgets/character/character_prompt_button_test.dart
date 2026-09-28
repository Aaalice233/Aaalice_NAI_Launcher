import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/data/repositories/character_prompt_repository.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/character/character_prompt_button.dart';

import '../../../helpers/ink_expectations.dart';

class _MemoryCharacterPromptRepository extends CharacterPromptRepository {
  _MemoryCharacterPromptRepository(this.config);

  CharacterPromptConfig config;

  @override
  CharacterPromptConfig load() => config;

  @override
  Future<bool> save(CharacterPromptConfig value) async {
    config = value;
    return true;
  }
}

void main() {
  testWidgets('无角色时添加菜单的悬停与按压反馈画在按钮底色之上', (tester) async {
    await _pumpButton(tester, const CharacterPromptConfig());
    final button = find.byType(CharacterPromptButton);
    final theme = Theme.of(tester.element(button));
    final fill = theme.colorScheme.surfaceContainerLow;
    final surface = _surfaceWithFill(fill);

    await hoverOver(tester, button);
    expectInkOnTop(tester, surface, ink: theme.hoverColor, below: fill);

    final press = await pressAndHold(tester, button);
    expectInkOnTop(tester, surface, ink: theme.highlightColor, below: fill);
    await press.cancel();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('有角色时管理入口的按压反馈画在按钮底色之上', (tester) async {
    var managed = 0;
    await _pumpButton(
      tester,
      const CharacterPromptConfig(
        characters: [CharacterPrompt(id: 'alice', name: 'Alice')],
      ),
      onManage: () => managed++,
    );
    final button = find.byType(CharacterPromptButton);
    final theme = Theme.of(tester.element(button));
    final fill = theme.colorScheme.primary.withValues(alpha: 0.12);

    final press = await pressAndHold(tester, button);
    expectInkOnTop(
      tester,
      _surfaceWithFill(fill),
      ink: theme.highlightColor,
      below: fill,
    );
    await press.up();
    await tester.pump(const Duration(milliseconds: 300));
    expect(managed, 1);
  });
}

Finder _surfaceWithFill(Color fill) => find
    .descendant(
      of: find.byType(CharacterPromptButton),
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is DecoratedBox &&
            (widget.decoration as BoxDecoration).color == fill,
      ),
    )
    .first;

Future<void> _pumpButton(
  WidgetTester tester,
  CharacterPromptConfig config, {
  VoidCallback? onManage,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        characterPromptRepositoryProvider.overrideWith(
          (ref) => _MemoryCharacterPromptRepository(config),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(child: CharacterPromptButton(onManage: onManage)),
        ),
      ),
    ),
  );
  await tester.pump();
}
