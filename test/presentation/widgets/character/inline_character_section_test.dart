import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/character_prompt_provider.dart';
import 'package:nai_launcher/presentation/widgets/character/inline_character_card.dart';
import 'package:nai_launcher/presentation/widgets/character/inline_character_editor.dart';
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

  testWidgets('角色提示词可拖拽调整高度且正负输入分别保留尺寸', (tester) async {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.windows,
    );
    addTearDown(() => PlatformCapabilities.debugOverride = null);
    final container = createContainer();

    await tester.pumpWidget(
      subject(
        container,
        420,
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: CharacterPromptEditor(
            character: CharacterPrompt(
              id: 'alice',
              name: 'Alice',
              prompt: 'girl, red hair',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final positiveArea = find.byKey(
      const ValueKey('character-prompt-editor-area-positive'),
    );
    final positiveHandle = find.byKey(
      const ValueKey('character-prompt-resize-handle-positive'),
    );
    expect(tester.getSize(positiveArea).height, 112);

    await tester.drag(positiveHandle, const Offset(0, 96));
    await tester.pump();
    final resizedPositiveHeight = tester.getSize(positiveArea).height;
    expect(resizedPositiveHeight, greaterThan(112));

    await tester.tap(find.text('负向提示词'));
    await tester.pump();
    final negativeArea = find.byKey(
      const ValueKey('character-prompt-editor-area-negative'),
    );
    expect(tester.getSize(negativeArea).height, 112);

    await tester.drag(
      find.byKey(const ValueKey('character-prompt-resize-handle-negative')),
      const Offset(0, 1000),
    );
    await tester.pump();
    expect(tester.getSize(negativeArea).height, 300);

    await tester.drag(
      find.byKey(const ValueKey('character-prompt-resize-handle-negative')),
      const Offset(0, -1000),
    );
    await tester.pump();
    expect(tester.getSize(negativeArea).height, 112);

    await tester.tap(find.text('正向提示词'));
    await tester.pump();
    expect(tester.getSize(positiveArea).height, resizedPositiveHeight);
    expect(tester.takeException(), isNull);
  });

  testWidgets('角色助手收起显示入口，展开后复用同一行', (tester) async {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.windows,
    );
    addTearDown(() => PlatformCapabilities.debugOverride = null);
    final container = createContainer();

    await tester.pumpWidget(
      subject(
        container,
        420,
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: CharacterPromptEditor(
            character: CharacterPrompt(
              id: 'alice',
              name: 'Alice',
              prompt: 'girl, red hair',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final slot = find.byKey(const ValueKey('character-prompt-assistant-slot'));
    final collapsedToolbar = find.byKey(
      const ValueKey(
        'prompt_assistant_toolbar_generation_character_alice_prompt',
      ),
    );
    final editor = find.byType(CharacterPromptEditor);
    final collapsedSlotRect = tester.getRect(slot);
    final editorRect = tester.getRect(editor);
    final collapsedAreaTop = tester
        .getRect(
          find.byKey(const ValueKey('character-prompt-editor-area-positive')),
        )
        .top;

    expect(collapsedSlotRect.right, closeTo(editorRect.right, 0.1));
    expect(collapsedSlotRect.height, 32);
    expect(collapsedSlotRect.width, inInclusiveRange(64, 95));
    final collapsedButton = find.byKey(
      const ValueKey('prompt_assistant_collapsed_button'),
    );
    final collapsedButtonRect = tester.getRect(collapsedButton);
    expect(collapsedButtonRect.left, closeTo(collapsedSlotRect.left, 0.1));
    expect(collapsedButtonRect.right, closeTo(collapsedSlotRect.right, 0.1));
    expect(collapsedButtonRect.top, closeTo(collapsedSlotRect.top, 0.1));
    expect(collapsedButtonRect.bottom, closeTo(collapsedSlotRect.bottom, 0.1));
    expect(
      find.descendant(
        of: collapsedToolbar,
        matching: find.byIcon(Icons.auto_awesome_rounded),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: collapsedToolbar, matching: find.text('助手')),
      findsOneWidget,
    );
    final clearButton = find.byKey(
      const ValueKey('character-prompt-clear-button'),
    );
    final clearButtonRect = tester.getRect(clearButton);
    expect(clearButton, findsOneWidget);
    expect(clearButtonRect.top, closeTo(collapsedSlotRect.top, 0.1));
    expect(clearButtonRect.bottom, closeTo(collapsedSlotRect.bottom, 0.1));
    expect(clearButtonRect.right, lessThan(collapsedSlotRect.left));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('character-prompt-editor-area-positive')),
        matching: clearButton,
      ),
      findsNothing,
    );

    await tester.tap(find.byIcon(Icons.auto_awesome_rounded));
    await tester.pump();

    final expandedToolbar = find.byKey(
      const ValueKey(
        'prompt_assistant_toolbar_generation_character_alice_prompt',
      ),
    );
    final expandedToolbarRect = tester.getRect(expandedToolbar);
    final expandedSlotRect = tester.getRect(slot);
    expect(
      find.ancestor(of: expandedToolbar, matching: editor),
      findsOneWidget,
    );
    expect(expandedSlotRect.left, closeTo(editorRect.left, 0.1));
    expect(expandedSlotRect.right, closeTo(editorRect.right, 0.1));
    expect(expandedSlotRect.height, 32);
    expect(expandedToolbarRect.top, closeTo(collapsedSlotRect.top, 0.1));
    expect(expandedToolbarRect.left, greaterThanOrEqualTo(editorRect.left));
    expect(expandedToolbarRect.right, lessThanOrEqualTo(editorRect.right));
    expect(find.text('正向提示词').hitTestable(), findsNothing);
    expect(find.text('负向提示词').hitTestable(), findsNothing);
    expect(clearButton, findsNothing);
    for (final icon in [
      Icons.translate,
      Icons.auto_fix_high,
      Icons.tune_rounded,
      Icons.manage_accounts_rounded,
      Icons.more_horiz,
      Icons.keyboard_arrow_down_rounded,
    ]) {
      final action = find.descendant(
        of: expandedToolbar,
        matching: find.byIcon(icon),
      );
      expect(action, findsOneWidget);
      final actionRect = tester.getRect(action);
      expect(actionRect.left, greaterThanOrEqualTo(expandedSlotRect.left));
      expect(actionRect.right, lessThanOrEqualTo(expandedSlotRect.right));
    }
    expect(
      find.descendant(of: expandedToolbar, matching: find.byIcon(Icons.undo)),
      findsNothing,
    );
    expect(
      find.descendant(of: expandedToolbar, matching: find.byIcon(Icons.redo)),
      findsNothing,
    );
    expect(
      tester
          .getRect(
            find.byKey(const ValueKey('character-prompt-editor-area-positive')),
          )
          .top,
      closeTo(collapsedAreaTop, 0.1),
    );

    await tester.tap(
      find.descendant(
        of: expandedToolbar,
        matching: find.byIcon(Icons.keyboard_arrow_down_rounded),
      ),
    );
    await tester.pump();
    expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    expect(find.text('助手'), findsOneWidget);
    expect(clearButton, findsOneWidget);
    expect(tester.getRect(slot).size, collapsedSlotRect.size);
    expect(
      tester
          .getRect(
            find.byKey(const ValueKey('character-prompt-editor-area-positive')),
          )
          .top,
      closeTo(collapsedAreaTop, 0.1),
    );
    await tester.tap(clearButton);
    await tester.pumpAndSettle();
    expect(find.text('确定要清空输入内容吗？'), findsOneWidget);
    await tester.tap(find.text('清除').last);
    await tester.pumpAndSettle();
    expect(clearButton, findsNothing);
    final editable = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('character-prompt-editor-area-positive')),
        matching: find.byType(EditableText),
      ),
    );
    expect(editable.controller.text, isEmpty);
    await tester.pump(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });

  testWidgets('点击角色助手不会退出角色编辑态', (tester) async {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.windows,
    );
    addTearDown(() => PlatformCapabilities.debugOverride = null);
    final container = createContainer();
    const character = CharacterPrompt(
      id: 'alice',
      name: 'Alice',
      prompt: 'girl, red hair',
    );

    await tester.pumpWidget(
      subject(
        container,
        420,
        child: const Padding(
          padding: EdgeInsets.all(12),
          child: InlineCharacterCard(character: character, index: 0, total: 1),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('girl, red hair'));
    await tester.pumpAndSettle();
    expect(find.byType(CharacterPromptEditor), findsOneWidget);

    await tester.tap(find.byIcon(Icons.auto_awesome_rounded));
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byIcon(Icons.keyboard_arrow_down_rounded));
    await tester.pump();
    await tester.pump();

    expect(container.read(selectedCharacterIdProvider), 'alice');
    expect(find.byType(CharacterPromptEditor), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('窄屏角色助手完整显示且 resize 受视口上限约束', (tester) async {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.android,
    );
    addTearDown(() => PlatformCapabilities.debugOverride = null);
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = createContainer();

    await tester.pumpWidget(
      subject(
        container,
        320,
        child: const Padding(
          padding: EdgeInsets.all(8),
          child: CharacterPromptEditor(
            character: CharacterPrompt(
              id: 'alice',
              name: 'Alice',
              prompt: 'girl, red hair',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final slot = find.byKey(const ValueKey('character-prompt-assistant-slot'));
    expect(tester.getSize(slot), const Size(48, 48));
    await tester.tap(find.byIcon(Icons.auto_awesome_rounded));
    await tester.pump();
    await tester.pump();

    final toolbar = find.byKey(
      const ValueKey(
        'prompt_assistant_toolbar_generation_character_alice_prompt',
      ),
    );
    final toolbarRect = tester.getRect(toolbar);
    expect(toolbarRect.left, greaterThanOrEqualTo(8));
    expect(toolbarRect.right, lessThanOrEqualTo(312));
    for (final icon in [
      Icons.translate,
      Icons.auto_fix_high,
      Icons.tune_rounded,
      Icons.manage_accounts_rounded,
      Icons.more_horiz,
      Icons.keyboard_arrow_down_rounded,
    ]) {
      expect(
        find.descendant(of: toolbar, matching: find.byIcon(icon)),
        findsOneWidget,
      );
    }

    await tester.drag(
      find.byKey(const ValueKey('character-prompt-resize-handle-positive')),
      const Offset(0, 1000),
    );
    await tester.pump();
    expect(
      tester
          .getSize(
            find.byKey(const ValueKey('character-prompt-editor-area-positive')),
          )
          .height,
      300,
    );
    expect(tester.takeException(), isNull);
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
