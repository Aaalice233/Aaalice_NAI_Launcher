import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/adaptive_presenter.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/providers/character_position_canvas_provider.dart';
import 'package:nai_launcher/presentation/providers/character_prompt_provider.dart';
import 'package:nai_launcher/presentation/widgets/character/mobile_character_manager_sheet.dart';

class _SingleCharacterNotifier extends CharacterPromptNotifier {
  @override
  CharacterPromptConfig build() => const CharacterPromptConfig(
    characters: [
      CharacterPrompt(
        id: 'alice',
        name: 'Alice with a long localized name',
        prompt: 'girl, red hair',
      ),
    ],
  );
}

class _CanvasNotifier extends CharacterPositionCanvas {
  @override
  bool build() => false;
}

class _MemoryStorage extends LocalStorageService {
  final Map<String, Object?> _values = {};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    final value = _values[key];
    return value is T ? value : defaultValue;
  }

  @override
  Future<void> setSetting<T>(String key, T value) async {
    _values[key] = value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('常规手机宽度把位置选择和带文本清空操作保持在同一行', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWith((ref) => _MemoryStorage()),
          characterPromptNotifierProvider.overrideWith(
            _SingleCharacterNotifier.new,
          ),
          characterPositionCanvasProvider.overrideWith(_CanvasNotifier.new),
        ],
        child: const MaterialApp(
          locale: Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: InteractionPolicyScope(
            initialPolicy: InteractionPolicy.touchFirst,
            child: Scaffold(body: MobileCharacterManagerSheet()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final modes = find.byKey(const ValueKey('character-position-mode-scroll'));
    final clear = find.byKey(const ValueKey('character-manager-clear-all'));
    expect(modes, findsOneWidget);
    expect(clear, findsOneWidget);
    expect(find.text('清空所有'), findsOneWidget);
    expect(
      tester.getCenter(modes).dy,
      closeTo(tester.getCenter(clear).dy, 0.1),
    );
    final canvasEntry = find.byKey(
      const ValueKey('character-position-canvas-entry'),
    );
    expect(canvasEntry, findsOneWidget);
    expect(
      tester.getRect(canvasEntry).right,
      lessThanOrEqualTo(tester.getRect(modes).right),
    );
    expect(tester.getSize(canvasEntry).width, greaterThanOrEqualTo(48));
    final modeScroll = tester.state<ScrollableState>(
      find.descendant(of: modes, matching: find.byType(Scrollable)),
    );
    expect(modeScroll.position.maxScrollExtent, 0);

    for (final label in ['AI 选择', '自定义']) {
      final segment = find.ancestor(
        of: find.text(label),
        matching: find.byType(InkWell),
      );
      expect(tester.getSize(segment).height, greaterThanOrEqualTo(48));
    }

    await tester.tap(find.text('Alice with a long localized name'));
    await tester.pumpAndSettle();

    final editingContext = find.byKey(
      const ValueKey('character-editor-context-alice'),
    );
    final nameField = find.byKey(const ValueKey('panel-name-alice'));
    expect(editingContext, findsOneWidget);
    expect(find.text('正在编辑'), findsOneWidget);
    expect(nameField, findsOneWidget);
    expect(
      tester.getCenter(editingContext).dy,
      closeTo(tester.getCenter(nameField).dy, 0.1),
    );
    expect(
      tester.getRect(editingContext).right,
      lessThanOrEqualTo(tester.getRect(nameField).left),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'compact worst case keeps form usable and close exits immediately',
    (tester) async {
      tester.view.devicePixelRatio = 3;
      tester.view.physicalSize = const Size(960, 1440);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      late ProviderContainer container;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWith((ref) => _MemoryStorage()),
            characterPromptNotifierProvider.overrideWith(
              _SingleCharacterNotifier.new,
            ),
            characterPositionCanvasProvider.overrideWith(_CanvasNotifier.new),
          ],
          child: Consumer(
            builder: (context, ref, _) {
              container = ProviderScope.containerOf(context);
              return MaterialApp(
                locale: const Locale('zh'),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: const TextScaler.linear(3),
                    padding: const EdgeInsets.only(bottom: 24),
                    viewInsets: const EdgeInsets.only(bottom: 160),
                  ),
                  child: child!,
                ),
                home: Builder(
                  builder: (context) => Scaffold(
                    body: FilledButton(
                      onPressed: () => AdaptivePresenter.showForm<void>(
                        context: context,
                        title: '角色提示词',
                        builder: (context, scrollController) =>
                            MobileCharacterManagerSheet(
                              scrollController: scrollController,
                            ),
                      ),
                      child: const Text('open'),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        find.byKey(const ValueKey('generation_mobile_character_manager_sheet')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('adaptive-bottom-sheet')),
        findsOneWidget,
      );
      expect(container.read(selectedCharacterIdProvider), isNull);
      expect(tester.takeException(), isNull);

      final characterName = find.text('Alice with a long localized name');
      await tester.ensureVisible(characterName);
      await tester.pumpAndSettle();
      await tester.tap(characterName);
      await tester.pumpAndSettle();
      expect(find.text('正在编辑'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('generation_mobile_character_manager_sheet')),
        findsNothing,
      );
      await tester.pump(const Duration(seconds: 4));
    },
  );
}
