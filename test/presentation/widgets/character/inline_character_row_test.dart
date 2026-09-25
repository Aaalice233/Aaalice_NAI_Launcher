import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/data/repositories/character_prompt_repository.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/character_prompt_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/widgets/character/inline_character_row.dart';

import '../../../helpers/ink_expectations.dart';

/// 惰性生成状态：真实 Notifier 内部有持续性任务会阻止测试进程退出
class _IdleImageGenerationNotifier extends ImageGenerationNotifier {
  @override
  ImageGenerationState build() => const ImageGenerationState();
}

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
  testWidgets('展开的角色编辑面板里，页签的反馈画在面板底色之上', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          characterPromptRepositoryProvider.overrideWith(
            (ref) => _MemoryCharacterPromptRepository(
              const CharacterPromptConfig(
                characters: [
                  CharacterPrompt(id: 'alice', name: 'Alice', prompt: 'girl'),
                ],
              ),
            ),
          ),
          imageGenerationNotifierProvider.overrideWith(
            _IdleImageGenerationNotifier.new,
          ),
        ],
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: InlineCharacterRow()),
          ),
        ),
      ),
    );
    await tester.pump();
    ProviderScope.containerOf(
      tester.element(find.byType(InlineCharacterRow)),
    ).read(selectedCharacterIdProvider.notifier).select('alice');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final negativeTab = find
        .ancestor(
          of: find.text('Undesired Content'),
          matching: find.byType(InkWell),
        )
        .first;
    final theme = Theme.of(tester.element(negativeTab));
    final surface = theme.colorScheme.surface;
    final panel = find
        .ancestor(
          of: negativeTab,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is Container &&
                widget.decoration is BoxDecoration &&
                (widget.decoration! as BoxDecoration).color == surface,
          ),
        )
        .first;

    await hoverOver(tester, negativeTab);
    expectInkOnTop(tester, panel, ink: theme.hoverColor, below: surface);

    final press = await pressAndHold(tester, negativeTab);
    expectInkOnTop(tester, panel, ink: theme.highlightColor, below: surface);
    await press.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  });
}
