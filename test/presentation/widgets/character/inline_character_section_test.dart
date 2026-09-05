import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/providers/character_prompt_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/translated_tag_text.dart';
import 'package:nai_launcher/presentation/widgets/character/inline_character_card.dart';
import 'package:nai_launcher/presentation/widgets/character/inline_character_editor.dart';
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
    InteractionPolicy? interactionPolicy,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: InteractionPolicyScope(
          initialPolicy: interactionPolicy,
          child: Scaffold(
            body: SizedBox(width: width, child: child),
          ),
        ),
      ),
    );
  }

  testWidgets('无角色时标题显示空态动态图标和全部添加入口', (tester) async {
    final container = createContainer(empty: true);

    await tester.pumpWidget(subject(container, 300));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('character-stack-icon')), findsOneWidget);
    expect(find.byKey(const Key('character-stack-person-0')), findsNothing);
    expect(find.byKey(const Key('character-add-female')), findsOneWidget);
    expect(find.byKey(const Key('character-add-male')), findsOneWidget);
    expect(find.byKey(const Key('character-add-other')), findsOneWidget);
    expect(find.byKey(const Key('character-add-from-library')), findsOneWidget);
  });

  testWidgets('角色标题栏有足够空间时添加入口保持同一行', (tester) async {
    final container = createContainer(empty: true);

    await tester.pumpWidget(subject(container, 500));
    await tester.pumpAndSettle();

    final buttons = [
      find.byKey(const Key('character-add-female')),
      find.byKey(const Key('character-add-male')),
      find.byKey(const Key('character-add-other')),
      find.byKey(const Key('character-add-from-library')),
    ];
    final top = tester.getTopLeft(buttons.first).dy;
    for (final button in buttons.skip(1)) {
      expect(tester.getTopLeft(button).dy, closeTo(top, 0.1));
    }
    expect(tester.takeException(), isNull);
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
    final leadingActions = find.byKey(
      const ValueKey('collapsible-leading-actions-角色'),
    );
    expect(leadingActions, findsOneWidget);
    expect(
      tester.getTopLeft(leadingActions).dx,
      lessThan(tester.getCenter(header).dx),
    );
    final chevron = find.byKey(const Key('collapsible-chevron-角色')).first;
    expect(
      tester.getRect(header).right - tester.getRect(chevron).right,
      closeTo(12, 0.5),
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
    expect(find.text('girl, red hair'), findsOneWidget);
    expect(find.text('boy, blue hair'), findsOneWidget);

    await tester.tap(find.byKey(const Key('collapsible-chevron-角色')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('character-hover-preview')), findsNothing);
    expect(find.byType(InlineCharacterCard), findsNWidgets(2));
  });

  testWidgets('宽屏根 Overlay 不会把角色悬浮预览拉伸到整行', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1920, 1080));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final container = createContainer();
    await tester.pumpWidget(subject(container, 1840));
    await tester.pumpAndSettle();

    final header = find.byKey(const Key('collapsible-header-角色')).first;
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(header));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump();

    final preview = find.byKey(const Key('character-hover-preview'));
    final positioned = find.byKey(
      const ValueKey('collapsed-hover-preview-positioned'),
    );
    final follower = find.byKey(
      const ValueKey('collapsed-hover-preview-follower'),
    );
    expect(preview, findsOneWidget);
    expect(positioned, findsOneWidget);
    expect(follower, findsOneWidget);
    expect(tester.widget<Positioned>(positioned).width, 380);
    expect(tester.getSize(follower).width, 380);
    expect(tester.getSize(preview).width, 380);
    expect(
      tester.getSize(preview).width,
      lessThan(tester.getSize(header).width),
    );
    expect(tester.takeException(), isNull);
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

  testWidgets('悬浮预览显示全部角色及完整提示词', (tester) async {
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
    expect(find.byKey(const Key('character-hover-item-carol')), findsOneWidget);
    expect(find.text('已禁用'), findsOneWidget);
    expect(
      find.byKey(const Key('character-stack-overflow-count')),
      findsOneWidget,
    );
    expect(find.text('+1'), findsOneWidget);
    expect(find.text('girl, red hair, green eyes, smile'), findsOneWidget);
    expect(find.text('girl, black hair, hat'), findsOneWidget);
    for (final prompt in tester.widgetList<TranslatedPromptText>(
      find.descendant(
        of: find.byKey(const Key('character-hover-preview')),
        matching: find.byType(TranslatedPromptText),
      ),
    )) {
      expect(prompt.maxLines, isNull);
      expect(prompt.includeUntranslated, isTrue);
    }
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
        interactionPolicy: const InteractionPolicy(
          modality: InteractionModality.pointer,
          touchAvailable: false,
          precisePointerAvailable: true,
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
    expect(
      find.descendant(
        of: positiveArea,
        matching: find.byKey(const ValueKey('tag-mode-button')),
      ),
      findsNothing,
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('tag-mode-button'))).bottom,
      lessThanOrEqualTo(tester.getRect(positiveArea).top),
    );

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

  testWidgets('角色助手在编辑区内展开且不挤动页签和清空入口', (tester) async {
    final container = createContainer();
    container.read(localStorageServiceProvider).setAutoFormatPrompt(false);
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
        interactionPolicy: const InteractionPolicy(
          modality: InteractionModality.pointer,
          touchAvailable: false,
          precisePointerAvailable: true,
        ),
      ),
    );
    await tester.pump();

    final toolbar = find.byKey(
      const ValueKey(
        'prompt_assistant_toolbar_generation_character_alice_prompt',
      ),
    );
    final area = find.byKey(
      const ValueKey('character-prompt-editor-area-positive'),
    );
    final clear = find.byKey(const ValueKey('character-prompt-clear-button'));
    final originalArea = tester.getRect(area);
    final originalClear = tester.getRect(clear);
    final collapsedRect = tester.getRect(toolbar);
    expect(collapsedRect.size, const Size(44, 44));
    expect(originalArea.contains(collapsedRect.topLeft), isTrue);
    expect(originalArea.contains(collapsedRect.bottomRight), isTrue);
    expect(originalClear.bottom, lessThanOrEqualTo(originalArea.top));
    expect(find.text('助手'), findsNothing);

    await tester.tap(
      find.byIcon(Icons.auto_awesome_rounded),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    final expandedRect = tester.getRect(toolbar);
    expect(tester.getRect(area), originalArea);
    expect(tester.getRect(clear), originalClear);
    expect(expandedRect.right, closeTo(collapsedRect.right, 0.1));
    expect(expandedRect.bottom, closeTo(collapsedRect.bottom, 0.1));
    expect(expandedRect.left, greaterThanOrEqualTo(originalArea.left));
    for (final icon in [
      Icons.translate,
      Icons.auto_fix_high,
      Icons.tune_rounded,
      Icons.manage_accounts_rounded,
      Icons.more_horiz,
      Icons.keyboard_arrow_down_rounded,
    ]) {
      expect(
        find.descendant(of: toolbar, matching: find.byIcon(icon)).hitTestable(),
        findsOneWidget,
      );
    }
    expect(find.text('正向提示词').hitTestable(), findsOneWidget);
    expect(find.text('负向提示词').hitTestable(), findsOneWidget);

    await tester.tap(
      find.byIcon(Icons.keyboard_arrow_down_rounded),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.getRect(toolbar), collapsedRect);

    await tester.tap(clear, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(find.text('确定要清空输入内容吗？'), findsOneWidget);
    await tester.tap(find.text('清除').last, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(clear, findsNothing);
    final editable = tester.widget<EditableText>(
      find.descendant(of: area, matching: find.byType(EditableText)),
    );
    expect(editable.controller.text, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('点击角色助手不会退出角色编辑态', (tester) async {
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
        interactionPolicy: const InteractionPolicy(
          modality: InteractionModality.pointer,
          touchAvailable: false,
          precisePointerAvailable: true,
        ),
      ),
    );
    await tester.pump();
    await tester.tap(
      find.text('girl, red hair'),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(find.byType(CharacterPromptEditor), findsOneWidget);

    await tester.tap(
      find.byIcon(Icons.auto_awesome_rounded),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await tester.pump();
    await tester.tap(
      find.byIcon(Icons.keyboard_arrow_down_rounded),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    await tester.pump();

    expect(container.read(selectedCharacterIdProvider), 'alice');
    expect(find.byType(CharacterPromptEditor), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.takeException(), isNull);
  });

  testWidgets('窄屏角色助手完整显示且 resize 受视口上限约束', (tester) async {
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
        interactionPolicy: const InteractionPolicy(
          modality: InteractionModality.touch,
          touchAvailable: true,
          precisePointerAvailable: false,
        ),
      ),
    );
    await tester.pump();

    final slot = find.byKey(
      const ValueKey(
        'prompt_assistant_toolbar_generation_character_alice_prompt',
      ),
    );
    expect(tester.getSize(slot), const Size(48, 48));
    final clearButton = find.byKey(
      const ValueKey('character-prompt-clear-button'),
    );
    expect(tester.getSize(clearButton), const Size(48, 48));
    expect(
      tester.getRect(clearButton).bottom,
      lessThanOrEqualTo(
        tester
            .getRect(
              find.byKey(
                const ValueKey('character-prompt-editor-area-positive'),
              ),
            )
            .top,
      ),
    );
    await tester.tap(find.byIcon(Icons.auto_awesome_rounded));
    await tester.pump();
    await tester.pump();

    final toolbar = find.byKey(
      const ValueKey(
        'prompt_assistant_toolbar_generation_character_alice_prompt',
      ),
    );
    final toolbarRect = tester.getRect(toolbar);
    expect(clearButton, findsOneWidget);
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
    final collapseButton = find.ancestor(
      of: find.descendant(
        of: toolbar,
        matching: find.byIcon(Icons.keyboard_arrow_down_rounded),
      ),
      matching: find.byType(IconButton),
    );
    expect(
      tester.getRect(collapseButton).right,
      closeTo(tester.getRect(slot).right, 0.1),
    );

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

  for (final size in [const Size(320, 480), const Size(1200, 800)]) {
    testWidgets('清空角色真实入口在 $size 自适应并保留返回语义', (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      final container = createContainer();
      await tester.pumpWidget(
        subject(
          container,
          size.width,
          textScaler: size.width < 600
              ? const TextScaler.linear(1.5)
              : TextScaler.noScaling,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('collapsible-chevron-角色')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('character-clear-all')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          ValueKey(
            size.width < 840
                ? 'adaptive-bottom-sheet'
                : 'adaptive-centered-form',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('清空所有角色'), findsOneWidget);
      expect(tester.takeException(), isNull);

      if (size.width < 600) {
        await tester.tap(find.widgetWithText(TextButton, '取消'));
        await tester.pumpAndSettle();
        expect(
          container.read(characterPromptNotifierProvider).characters,
          hasLength(2),
        );
      } else {
        await tester.tap(find.widgetWithText(FilledButton, '清除'));
        await tester.pumpAndSettle();
        expect(
          container.read(characterPromptNotifierProvider).characters,
          isEmpty,
        );
      }
    });
  }

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
