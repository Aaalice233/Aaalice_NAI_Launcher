import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/character_prompt_provider.dart';
import 'package:nai_launcher/presentation/widgets/character/inline_character_card.dart';
import 'package:nai_launcher/presentation/widgets/character/inline_character_row.dart';
import 'package:nai_launcher/presentation/widgets/character/inline_character_section.dart';

class _TestCharacterPromptNotifier extends CharacterPromptNotifier {
  @override
  CharacterPromptConfig build() {
    return const CharacterPromptConfig(
      characters: [
        CharacterPrompt(id: 'alice', name: 'Alice', prompt: 'girl, red hair'),
        CharacterPrompt(id: 'bob', name: 'Bob', prompt: 'boy, blue hair'),
      ],
    );
  }

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

  void setEnabledForTest(String id, bool enabled) {
    state = state.copyWith(
      characters: [
        for (final character in state.characters)
          character.id == id ? character.copyWith(enabled: enabled) : character,
      ],
    );
  }
}

class _EmptyCharacterPromptNotifier extends CharacterPromptNotifier {
  @override
  CharacterPromptConfig build() => const CharacterPromptConfig();
}

class _ManyCharacterPromptNotifier extends CharacterPromptNotifier {
  @override
  CharacterPromptConfig build() {
    return const CharacterPromptConfig(
      characters: [
        CharacterPrompt(
          id: 'alice',
          name: 'Alice',
          prompt: 'girl, red hair, green eyes, smile',
        ),
        CharacterPrompt(
          id: 'bob',
          name: 'Bob',
          prompt: 'boy, blue hair, glasses',
          enabled: false,
        ),
        CharacterPrompt(
          id: 'robot',
          name: 'Robot',
          prompt: 'robot, silver body, glowing eyes',
        ),
        CharacterPrompt(
          id: 'carol',
          name: 'Carol',
          prompt: 'girl, black hair, hat',
        ),
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
  ProviderContainer createContainer({bool empty = false, bool many = false}) {
    final storage = _MemoryStorage();
    final notifierFactory = empty
        ? _EmptyCharacterPromptNotifier.new
        : many
        ? _ManyCharacterPromptNotifier.new
        : _TestCharacterPromptNotifier.new;
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWith((ref) => storage),
        characterPromptNotifierProvider.overrideWith(notifierFactory),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Widget subject(
    ProviderContainer container,
    double width, {
    Widget child = const InlineCharacterSection(),
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SizedBox(width: width, child: child),
        ),
      ),
    );
  }

  testWidgets('无角色时标题显示空态动态图标和全部添加入口', (tester) async {
    final container = createContainer(empty: true);

    await tester.pumpWidget(subject(container, 700));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('character-stack-icon')), findsOneWidget);
    expect(find.byKey(const Key('character-stack-person-0')), findsNothing);
    expect(find.byKey(const Key('character-add-female')), findsOneWidget);
    expect(find.byKey(const Key('character-add-male')), findsOneWidget);
    expect(find.byKey(const Key('character-add-other')), findsOneWidget);
    expect(find.byKey(const Key('character-add-from-library')), findsOneWidget);
  });

  testWidgets('默认折叠显示实时摘要，展开内容与生成角色状态不变', (tester) async {
    final container = createContainer();
    final before = container.read(characterPromptNotifierProvider);

    await tester.pumpWidget(subject(container, 700));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('character-stack-person-0')), findsOneWidget);
    expect(find.byKey(const Key('character-stack-person-1')), findsOneWidget);
    expect(find.byKey(const Key('character-stack-person-2')), findsNothing);
    expect(find.byType(InlineCharacterCard), findsNothing);

    await tester.tap(find.byKey(const Key('collapsible-chevron-角色')));
    await tester.pumpAndSettle();

    expect(find.byType(InlineCharacterCard), findsNWidgets(2));
    expect(container.read(characterPromptNotifierProvider), before);

    await tester.tap(find.byKey(const Key('collapsible-chevron-角色')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('character-stack-person-0')), findsOneWidget);
    expect(find.byKey(const Key('character-stack-person-1')), findsOneWidget);
  });

  testWidgets('经典布局默认折叠且展开不会改变角色状态', (tester) async {
    final container = createContainer();
    final before = container.read(characterPromptNotifierProvider);

    await tester.pumpWidget(
      subject(container, 1180, child: const ClassicCharacterSection()),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('classic-character-count')), findsOneWidget);
    expect(find.byType(InlineCharacterCard), findsNothing);

    await tester.tap(find.byKey(const Key('collapsible-chevron-角色')));
    await tester.pumpAndSettle();

    expect(find.byType(InlineCharacterCard), findsNWidgets(2));
    expect(container.read(characterPromptNotifierProvider), before);

    await tester.tap(find.byKey(const Key('collapsible-chevron-角色')));
    await tester.pumpAndSettle();
    expect(find.byType(InlineCharacterCard), findsNothing);
    expect(container.read(characterPromptNotifierProvider), before);
  });

  testWidgets('标题栏添加按钮新增角色且不会切换面板展开状态', (tester) async {
    final container = createContainer();
    await tester.pumpWidget(subject(container, 700));
    await tester.pumpAndSettle();

    final header = find.byKey(const Key('collapsible-header-角色')).first;
    expect(
      find.descendant(
        of: header,
        matching: find.byKey(const Key('character-add-male')),
      ),
      findsOneWidget,
    );
    final centeredActions = find.byKey(
      const ValueKey('collapsible-centered-actions-角色'),
    );
    expect(centeredActions, findsOneWidget);
    expect(
      tester.getCenter(centeredActions).dx,
      closeTo(tester.getCenter(header).dx, 0.5),
    );

    await tester.tap(find.byKey(const Key('character-add-male')));
    await tester.pumpAndSettle();

    expect(
      container.read(characterPromptNotifierProvider).characters,
      hasLength(3),
    );
    expect(find.byKey(const Key('character-stack-person-2')), findsOneWidget);
    expect(find.byType(InlineCharacterCard), findsNothing);
  });

  testWidgets('折叠态悬停 350ms 后显示只读角色预览，点击立即收起并展开', (tester) async {
    final container = createContainer();
    await tester.pumpWidget(subject(container, 700));
    await tester.pumpAndSettle();

    final header = find.byKey(const Key('collapsible-header-角色')).first;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(header));

    await tester.pump(const Duration(milliseconds: 349));
    expect(find.byKey(const Key('character-hover-preview')), findsNothing);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    final preview = find.byKey(const Key('character-hover-preview'));
    expect(preview, findsOneWidget);
    final previewSize = tester.getSize(preview);
    expect(previewSize.width, lessThanOrEqualTo(380));
    expect(previewSize.height, lessThan(300));
    expect(find.text('角色预览'), findsOneWidget);
    expect(find.text('2 / 2 启用'), findsOneWidget);
    expect(find.text('girl · red hair'), findsOneWidget);
    expect(find.text('boy · blue hair'), findsOneWidget);

    await tester.tap(find.byKey(const Key('collapsible-chevron-角色')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('character-hover-preview')), findsNothing);
    expect(find.byType(InlineCharacterCard), findsNWidgets(2));
  });

  testWidgets('悬浮预览显示期间更新角色状态不会在 build 阶段刷新 Overlay', (tester) async {
    final container = createContainer();
    await tester.pumpWidget(subject(container, 700));
    await tester.pumpAndSettle();

    final header = find.byKey(const Key('collapsible-header-角色')).first;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(header));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();
    expect(find.text('2 / 2 启用'), findsOneWidget);

    (container.read(characterPromptNotifierProvider.notifier)
            as _TestCharacterPromptNotifier)
        .setEnabledForTest('alice', false);
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pump();
    expect(find.text('1 / 2 启用'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('悬浮预览最多显示三个角色并标出停用与剩余数量', (tester) async {
    final container = createContainer(many: true);
    await tester.pumpWidget(subject(container, 700));
    await tester.pumpAndSettle();

    final header = find.byKey(const Key('collapsible-header-角色')).first;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(header));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    expect(find.byKey(const Key('character-hover-item-alice')), findsOneWidget);
    expect(find.byKey(const Key('character-hover-item-bob')), findsOneWidget);
    expect(find.byKey(const Key('character-hover-item-robot')), findsOneWidget);
    expect(find.byKey(const Key('character-hover-item-carol')), findsNothing);
    expect(find.text('已禁用'), findsOneWidget);
    expect(find.text('还有 1 个角色'), findsOneWidget);
    expect(
      find.byKey(const Key('character-stack-overflow-count')),
      findsOneWidget,
    );
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('girl · red hair · green eyes'), findsOneWidget);
    expect(find.textContaining('smile'), findsNothing);
    expect(tester.takeException(), isNull);

    await mouse.moveTo(Offset.zero);
    await tester.pump(const Duration(milliseconds: 119));
    expect(find.byKey(const Key('character-hover-preview')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.byKey(const Key('character-hover-preview')), findsNothing);
  });

  testWidgets('无角色时悬停不会创建预览', (tester) async {
    final container = createContainer(empty: true);
    await tester.pumpWidget(subject(container, 700));
    await tester.pumpAndSettle();

    final header = find.byKey(const Key('collapsible-header-角色')).first;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(header));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const Key('character-hover-preview')), findsNothing);
  });

  for (final width in [700.0, 840.0, 1180.0, 1600.0]) {
    testWidgets('角色菜单在 $width 宽度无 RenderFlex overflow', (tester) async {
      final container = createContainer();
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(subject(container, width));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('collapsible-chevron-角色')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(InlineCharacterCard), findsNWidgets(2));
    });
  }
}
