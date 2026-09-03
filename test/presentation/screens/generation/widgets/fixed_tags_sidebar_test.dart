import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_entry.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_link.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_prompt_type.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_category.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_entry.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_resource_drop_region.dart';
import 'package:nai_launcher/presentation/providers/fixed_tags_provider.dart';
import 'package:nai_launcher/presentation/providers/layout_state_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/fixed_tags_sidebar.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/sidebar_entry_tile.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/sidebar_link_painter.dart';
import 'package:nai_launcher/presentation/widgets/common/hover_image_preview.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_switch.dart';
import 'package:nai_launcher/presentation/widgets/common/thumbnail_display.dart';
import 'package:nai_launcher/presentation/widgets/prompt/fixed_tag_edit_dialog.dart';
import 'package:nai_launcher/presentation/widgets/prompt/fixed_tag_entry_tile.dart';
import 'package:nai_launcher/presentation/widgets/prompt/fixed_tags_button.dart';
import 'package:nai_launcher/presentation/widgets/prompt/fixed_tags_dialog.dart';

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = Directory.systemTemp.createTempSync('fixed_tags_sidebar_hive_');
    Hive.init(hiveDir.path);
    await Hive.openBox(StorageKeys.settingsBox);
  });

  setUp(() async {
    await Hive.box(StorageKeys.settingsBox).clear();
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  testWidgets('management tile body toggles the entry switch', (tester) async {
    final entry = FixedTagEntry.create(
      name: 'clickable fixed tag',
      content: 'masterpiece',
      enabled: false,
    );
    final storage = _SidebarTestStorage(
      fixedEntries: [entry],
      categories: const [],
      libraryEntries: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: FixedTagsDialog()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final tile = find.ancestor(
      of: find.text('clickable fixed tag'),
      matching: find.byType(FixedTagEntryTile),
    );
    final entrySwitch = find.descendant(
      of: tile,
      matching: find.byType(ThemedSwitch),
    );
    expect(tester.widget<ThemedSwitch>(entrySwitch).value, isFalse);

    await tester.tap(find.text('clickable fixed tag'));
    await tester.pumpAndSettle();

    expect(tester.widget<ThemedSwitch>(entrySwitch).value, isTrue);
  });

  testWidgets('select-all action follows input hit targets', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = _SidebarTestStorage(
      fixedEntries: const [],
      categories: const [],
      libraryEntries: const [],
    );

    Future<void> pump(InteractionPolicy policy) async {
      await tester.pumpWidget(
        ProviderScope(
          key: ValueKey(policy),
          overrides: [
            localStorageServiceProvider.overrideWith((ref) => storage),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: InteractionPolicyScope(
                key: ValueKey(policy),
                initialPolicy: policy,
                child: const FixedTagsDialog(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    const touchPolicy = InteractionPolicy.touchFirst;
    await pump(touchPolicy);
    final selectAll = find.byKey(
      const ValueKey('fixed-tags-toggle-all-positive'),
    );
    expect(tester.getSize(selectAll), const Size.square(48));

    await pump(
      const InteractionPolicy(
        modality: InteractionModality.pointer,
        touchAvailable: false,
        precisePointerAvailable: true,
      ),
    );
    expect(tester.getSize(selectAll), const Size.square(40));
  });

  testWidgets('mobile entries scroll before a long-press starts reordering', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = _SidebarTestStorage(
      fixedEntries: [
        for (var index = 0; index < 20; index++)
          FixedTagEntry.create(
            name: 'mobile fixed tag $index',
            content: 'tag_$index',
          ),
      ],
      categories: const [],
      libraryEntries: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
        child: const InteractionPolicyScope(
          initialPolicy: InteractionPolicy(
            modality: InteractionModality.touch,
            touchAvailable: true,
            precisePointerAvailable: false,
          ),
          child: MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: FixedTagsDialog()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ReorderableDelayedDragStartListener), findsWidgets);
    expect(find.byType(ReorderableDragStartListener), findsNothing);
    expect(find.byType(AgentResourceDragSource), findsNothing);

    final firstCenter = tester.getCenter(find.text('mobile fixed tag 0'));
    final thirdCenter = tester.getCenter(find.text('mobile fixed tag 2'));
    final reorderGesture = await tester.startGesture(firstCenter);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await reorderGesture.moveTo(thirdCenter + const Offset(0, 24));
    await tester.pump(const Duration(milliseconds: 300));
    await reorderGesture.up();
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(FixedTagsDialog)),
    );
    expect(
      container
          .read(fixedTagsNotifierProvider)
          .positiveEntries
          .sortedByOrder()
          .first
          .name,
      isNot('mobile fixed tag 0'),
    );
    expect(tester.takeException(), isNull);

    final scrollable = find
        .descendant(
          of: find.byType(ReorderableListView),
          matching: find.byType(Scrollable),
        )
        .first;
    final position = tester.state<ScrollableState>(scrollable).position;
    expect(position.pixels, 0);

    await tester.drag(find.text('mobile fixed tag 0'), const Offset(0, -240));
    await tester.pumpAndSettle();

    expect(position.pixels, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'empty expanded management dialog keeps column creation actions visible',
    (tester) async {
      final storage = _SidebarTestStorage(
        fixedEntries: const [],
        categories: const [],
        libraryEntries: const [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWith((ref) => storage),
          ],
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: FixedTagsDialog()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('正向固定词 · 0/0'), findsOneWidget);
      expect(find.text('负向固定词 · 0/0'), findsOneWidget);
      expect(find.text('新建'), findsNWidgets(2));
      expect(find.text('词库'), findsNWidgets(2));
      expect(find.text('暂无固定词'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('desktop fixed-tag manager opens as a centered dialog', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final storage = _SidebarTestStorage(
      fixedEntries: const [],
      categories: const [],
      libraryEntries: const [],
    )..fixedSidebarExpanded = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: Center(child: FixedTagsButton())),
        ),
      ),
    );

    await tester.tap(find.byType(FixedTagsButton));
    await tester.pumpAndSettle();

    final surface = find.byKey(const ValueKey('adaptive-centered-form'));
    expect(surface, findsOneWidget);
    expect(find.byKey(const ValueKey('adaptive-side-sheet')), findsNothing);
    final rect = tester.getRect(surface);
    expect(rect.width, 980);
    expect(rect.center, const Offset(800, 450));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'mobile fixed-tag manager uses one adaptive column without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = _SidebarTestStorage(
        fixedEntries: const [],
        categories: const [],
        libraryEntries: const [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWith((ref) => storage),
          ],
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: FixedTagsDialog()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('fixed-tags-mobile-tab-positive')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('fixed-tags-mobile-tab-negative')),
        findsOneWidget,
      );
      expect(find.text('新建'), findsOneWidget);
      expect(find.text('从词库添加'), findsOneWidget);
      final dialogRect = tester.getRect(
        find.byKey(const ValueKey('fixed-tags-dialog-surface')),
      );
      expect(dialogRect.left, 0);
      expect(dialogRect.right, 320);
      expect(tester.takeException(), isNull);

      await tester.tap(
        find.byKey(const ValueKey('fixed-tags-mobile-tab-negative')),
      );
      await tester.pumpAndSettle();

      expect(find.text('新建'), findsOneWidget);
      expect(find.text('从词库添加'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'compact fixed-tag editor survives 3x text, SafeArea, IME and back',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = _SidebarTestStorage(
        fixedEntries: const [],
        categories: const [],
        libraryEntries: const [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWith((ref) => storage),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(3),
                padding: const EdgeInsets.only(top: 24, bottom: 16),
                viewPadding: const EdgeInsets.only(top: 24, bottom: 16),
                viewInsets: const EdgeInsets.only(bottom: 180),
              ),
              child: child!,
            ),
            home: const Scaffold(body: FixedTagsDialog()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('新建'));
      await tester.pumpAndSettle();
      expect(find.byType(FixedTagEditDialog), findsOneWidget);
      expect(
        find.byKey(const ValueKey('adaptive-full-screen-form')),
        findsOneWidget,
      );
      final frameRect = tester.getRect(
        find.byKey(const ValueKey('adaptive-full-screen-form')),
      );
      expect(frameRect.top, greaterThanOrEqualTo(24));
      expect(frameRect.bottom, lessThanOrEqualTo(720));
      expect(tester.takeException(), isNull);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(FixedTagEditDialog), findsNothing);
      expect(find.byType(FixedTagsDialog), findsOneWidget);
    },
  );

  testWidgets(
    'mobile fixed-tag cards keep actions and link management usable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final positive = FixedTagEntry.create(
        name: '很长的正向固定词名称用于验证手机窄屏布局',
        content: 'masterpiece, best quality, extremely detailed',
      );
      final negative = FixedTagEntry.create(
        name: '负向固定词',
        content: 'bad hands, low quality',
        promptType: FixedTagPromptType.negative,
      );
      final storage = _SidebarTestStorage(
        fixedEntries: [positive, negative],
        categories: const [],
        libraryEntries: const [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWith((ref) => storage),
          ],
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: FixedTagsDialog()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(positive.name), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(
        find.byKey(ValueKey('fixed-tag-mobile-link-${positive.id}')),
      );
      await tester.pumpAndSettle();

      expect(find.text('管理联动'), findsOneWidget);
      expect(find.text(negative.name), findsWidgets);
      expect(tester.takeException(), isNull);

      await tester.tap(
        find.byKey(ValueKey('fixed-tag-link-option-${negative.id}')),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(FixedTagsDialog)),
      );
      expect(container.read(fixedTagsNotifierProvider).links, hasLength(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fixed-tag overlay stays scrollable at 320 3x with SafeArea and IME',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final positiveEntries = [
        for (var index = 0; index < 12; index++)
          FixedTagEntry.create(
            name: 'positive fixed tag $index',
            content: 'positive_$index',
          ),
      ];
      final negativeEntries = [
        for (var index = 0; index < 12; index++)
          FixedTagEntry.create(
            name: 'negative fixed tag $index',
            content: 'negative_$index',
            promptType: FixedTagPromptType.negative,
          ),
      ];
      final storage = _SidebarTestStorage(
        fixedEntries: [...positiveEntries, ...negativeEntries],
        categories: const [],
        libraryEntries: const [],
      )..fixedSidebarExpanded = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWith((ref) => storage),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(3),
                padding: const EdgeInsets.only(top: 24, bottom: 16),
                viewPadding: const EdgeInsets.only(top: 24, bottom: 16),
                viewInsets: const EdgeInsets.only(bottom: 180),
              ),
              child: child!,
            ),
            home: const Scaffold(
              body: SafeArea(child: Center(child: FixedTagsButton())),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FixedTagsButton));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('fixed-tags-dialog-surface')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('fixed-tags-mobile-tab-positive')),
        findsOneWidget,
      );

      final positiveList = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView),
      );
      await _jumpToEndUntilVisible(
        tester,
        positiveList.scrollController!,
        find.text('positive fixed tag 11'),
      );
      expect(find.text('positive fixed tag 11').hitTestable(), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('fixed-tags-mobile-tab-negative')),
      );
      await tester.pumpAndSettle();
      final negativeList = tester.widget<ReorderableListView>(
        find.byType(ReorderableListView),
      );
      await _jumpToEndUntilVisible(
        tester,
        negativeList.scrollController!,
        find.text('negative fixed tag 11'),
      );
      final lastNegative = find.text('negative fixed tag 11');
      expect(lastNegative.hitTestable(), findsOneWidget);
      await tester.tap(lastNegative);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(FixedTagsDialog)),
      );
      expect(
        container
            .read(fixedTagsNotifierProvider)
            .entries
            .firstWhere((entry) => entry.id == negativeEntries.last.id)
            .enabled,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'renders enabled categorized entries without duplicate key errors',
    (tester) async {
      final category = TagLibraryCategory.create(name: '画师');
      final enabled = FixedTagEntry.create(
        name: 'artist enabled',
        content: 'artist:fuzichoco',
        categoryId: category.id,
        enabled: true,
      );
      final quality = FixedTagEntry.create(
        name: 'quality',
        content: 'masterpiece',
        categoryId: category.id,
        enabled: false,
      );
      final negative = FixedTagEntry.create(
        name: 'negative',
        content: 'bad hands',
        promptType: FixedTagPromptType.negative,
      );
      final storage = _SidebarTestStorage(
        fixedEntries: [enabled, quality, negative],
        categories: [category],
        libraryEntries: [
          TagLibraryEntry.create(
            name: enabled.name,
            content: enabled.content,
            categoryId: category.id,
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWith((ref) => storage),
          ],
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 340,
                height: 620,
                child: FixedTagsSidebar(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.descendant(
          of: find.byType(SidebarEntryTile),
          matching: find.text('artist enabled'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(SidebarEntryTile),
          matching: find.text('quality'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.enterText(find.byType(TextField), 'quality');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.descendant(
          of: find.byType(SidebarEntryTile),
          matching: find.text('quality'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(SidebarEntryTile),
          matching: find.text('artist enabled'),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('category chips wrap when the sidebar is narrow', (tester) async {
    final categories = [
      TagLibraryCategory.create(name: '质量词'),
      TagLibraryCategory.create(name: '画风'),
      TagLibraryCategory.create(name: '角色'),
      TagLibraryCategory.create(name: '构图'),
    ];
    final entries = [
      for (final category in categories)
        FixedTagEntry.create(
          name: category.name,
          content: 'tag ${category.name}',
          categoryId: category.id,
        ),
    ];
    final storage = _SidebarTestStorage(
      fixedEntries: entries,
      categories: categories,
      libraryEntries: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(width: 260, height: 620, child: FixedTagsSidebar()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final wrappedChip = find.text('角色 1');
    expect(wrappedChip, findsOneWidget);

    final firstTop = tester.getTopLeft(find.text('已启用 4')).dy;
    final wrappedTop = tester.getTopLeft(wrappedChip).dy;

    expect(wrappedTop, greaterThan(firstTop + 20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('FixedTagsButton 预览区分正负面与前后缀', (tester) async {
    final storage = _SidebarTestStorage(
      fixedEntries: [
        FixedTagEntry.create(name: '正面前缀条目', content: 'best quality'),
        FixedTagEntry.create(
          name: '正面后缀条目',
          content: 'cinematic lighting',
          position: FixedTagPosition.suffix,
        ),
        FixedTagEntry.create(
          name: '负面前缀条目',
          content: 'lowres',
          promptType: FixedTagPromptType.negative,
        ),
        FixedTagEntry.create(
          name: '负面后缀条目',
          content: 'watermark',
          position: FixedTagPosition.suffix,
          promptType: FixedTagPromptType.negative,
        ),
      ],
      categories: const [],
      libraryEntries: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: Center(child: FixedTagsButton())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(FixedTagsButton)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final positiveSection = find.byKey(
      const ValueKey('fixed-tags-tooltip-positive'),
    );
    final negativeSection = find.byKey(
      const ValueKey('fixed-tags-tooltip-negative'),
    );
    expect(positiveSection, findsOneWidget);
    expect(negativeSection, findsOneWidget);
    expect(
      find.descendant(of: positiveSection, matching: find.text('正面')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: negativeSection, matching: find.text('负面')),
      findsOneWidget,
    );
    for (final section in [positiveSection, negativeSection]) {
      expect(
        find.descendant(of: section, matching: find.text('前缀 1')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: section, matching: find.text('后缀 1')),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(of: positiveSection, matching: find.text('正面前缀条目')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: negativeSection, matching: find.text('负面后缀条目')),
      findsOneWidget,
    );

    final positiveDecoration =
        tester.widget<Container>(positiveSection).decoration! as BoxDecoration;
    final negativeDecoration =
        tester.widget<Container>(negativeSection).decoration! as BoxDecoration;
    expect(positiveDecoration.color, isNot(negativeDecoration.color));
    expect(tester.takeException(), isNull);
  });

  testWidgets('FixedTagsButton 经典工具栏紧凑模式不会拉伸', (tester) async {
    final storage = _SidebarTestStorage(
      fixedEntries: const [],
      categories: const [],
      libraryEntries: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(
              width: 1000,
              child: Align(
                alignment: Alignment.topLeft,
                child: FixedTagsButton(compact: true),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final surface = find.byKey(const Key('fixed-tags-button-surface'));
    expect(tester.getSize(surface).height, 36);
    expect(tester.getSize(surface).width, lessThan(100));
  });

  testWidgets(
    'FixedTagsButton long press toggles sidebar and tap keeps it open',
    (tester) async {
      final storage = _SidebarTestStorage(
        fixedEntries: const [],
        categories: const [],
        libraryEntries: const [],
      )..fixedSidebarExpanded = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWith((ref) => storage),
          ],
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: Center(child: FixedTagsButton())),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(FixedTagsButton)),
      );
      expect(
        container.read(layoutStateNotifierProvider).fixedTagsSidebarExpanded,
        isFalse,
      );

      await tester.longPress(find.byType(FixedTagsButton));
      await tester.pumpAndSettle();

      expect(
        container.read(layoutStateNotifierProvider).fixedTagsSidebarExpanded,
        isTrue,
      );
      expect(storage.fixedSidebarExpanded, isTrue);

      await tester.tap(find.byType(FixedTagsButton));
      await tester.pumpAndSettle();

      expect(
        container.read(layoutStateNotifierProvider).fixedTagsSidebarExpanded,
        isTrue,
      );
      expect(storage.fixedSidebarExpanded, isTrue);

      await tester.longPress(find.byType(FixedTagsButton));
      await tester.pumpAndSettle();

      expect(
        container.read(layoutStateNotifierProvider).fixedTagsSidebarExpanded,
        isFalse,
      );
      expect(storage.fixedSidebarExpanded, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'list mode reorders from tile body without default drag handles',
    (tester) async {
      PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
        TargetPlatform.windows,
      );
      addTearDown(() => PlatformCapabilities.debugOverride = null);
      final first = FixedTagEntry.create(name: 'first', content: 'one');
      final second = FixedTagEntry.create(name: 'second', content: 'two');
      final storage = _SidebarTestStorage(
        fixedEntries: [first, second],
        categories: const [],
        libraryEntries: const [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWith((ref) => storage),
          ],
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 340,
                height: 620,
                child: FixedTagsSidebar(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.drag_handle), findsNothing);

      final firstTileText = find.descendant(
        of: find.byType(SidebarEntryTile),
        matching: find.text('first'),
      );
      final secondTileText = find.descendant(
        of: find.byType(SidebarEntryTile),
        matching: find.text('second'),
      );
      final start = tester.getCenter(firstTileText);
      final end = tester.getCenter(secondTileText);
      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.down(start);
      await tester.pump();
      await gesture.moveBy(end - start + const Offset(0, 64));
      await gesture.up();
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(FixedTagsSidebar)),
      );
      expect(
        container
            .read(fixedTagsNotifierProvider)
            .positiveEntries
            .map((entry) => entry.id),
        [second.id, first.id],
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dropping a positive link anchor on a negative tile creates a link',
    (tester) async {
      final positive = FixedTagEntry.create(
        name: 'artist',
        content: 'artist:fuzichoco',
        enabled: true,
      );
      final negative = FixedTagEntry.create(
        name: 'negative',
        content: 'bad hands',
        promptType: FixedTagPromptType.negative,
      );
      final storage = _SidebarTestStorage(
        fixedEntries: [positive, negative],
        categories: const [],
        libraryEntries: const [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWith((ref) => storage),
          ],
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 340,
                height: 620,
                child: FixedTagsSidebar(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final linkIcons = find.byIcon(Icons.link_rounded);
      expect(linkIcons, findsNWidgets(2));

      final start = tester.getCenter(linkIcons.first);
      final negativeTile = find.ancestor(
        of: find.text('negative'),
        matching: find.byType(SidebarEntryTile),
      );
      final end = tester.getCenter(negativeTile);
      await tester.dragFrom(start, end - start);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(FixedTagsSidebar)),
      );
      expect(container.read(fixedTagsNotifierProvider).links, hasLength(1));
      expect(storage.linksJson, isNot('[]'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dropping an existing link pair again removes the link', (
    tester,
  ) async {
    final positive = FixedTagEntry.create(
      name: 'artist',
      content: 'artist:fuzichoco',
      enabled: true,
    );
    final negative = FixedTagEntry.create(
      name: 'negative',
      content: 'bad hands',
      promptType: FixedTagPromptType.negative,
    );
    final existingLink = FixedTagLink.create(
      positiveEntryId: positive.id,
      negativeEntryId: negative.id,
    );
    final storage = _SidebarTestStorage(
      fixedEntries: [positive, negative],
      categories: const [],
      libraryEntries: const [],
    )..linksJson = jsonEncode([existingLink.toJson()]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(width: 340, height: 620, child: FixedTagsSidebar()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(FixedTagsSidebar)),
    );
    expect(container.read(fixedTagsNotifierProvider).links, hasLength(1));

    final start = tester.getCenter(find.byIcon(Icons.link_rounded).first);
    final negativeTile = find.ancestor(
      of: find.text('negative'),
      matching: find.byType(SidebarEntryTile),
    );
    final end = tester.getCenter(negativeTile);
    await tester.dragFrom(start, end - start);
    await tester.pumpAndSettle();

    expect(container.read(fixedTagsNotifierProvider).links, isEmpty);
    expect(storage.linksJson, '[]');
    expect(tester.takeException(), isNull);
  });

  for (final viewMode in ['list', 'grid']) {
    testWidgets('link drag preview follows the cursor in $viewMode mode', (
      tester,
    ) async {
      final positive = FixedTagEntry.create(
        name: 'artist',
        content: 'artist:fuzichoco',
        enabled: true,
      );
      final negative = FixedTagEntry.create(
        name: 'negative',
        content: 'bad hands',
        promptType: FixedTagPromptType.negative,
      );
      final storage = _SidebarTestStorage(
        fixedEntries: [positive, negative],
        categories: const [],
        libraryEntries: const [],
      )..fixedSidebarViewMode = viewMode;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWith((ref) => storage),
          ],
          child: const MaterialApp(
            locale: Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SizedBox(
                width: 340,
                height: 620,
                child: FixedTagsSidebar(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final start = tester.getCenter(find.byIcon(Icons.link_rounded).first);
      final gesture = await tester.startGesture(
        start,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      await gesture.moveBy(const Offset(58, 36));
      await tester.pump();

      expect(_linkPainterHasPreview(tester), isTrue);

      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'dragging an existing link endpoint away removes the link in $viewMode mode',
      (tester) async {
        final positive = FixedTagEntry.create(
          name: 'artist',
          content: 'artist:fuzichoco',
          enabled: true,
        );
        final negative = FixedTagEntry.create(
          name: 'negative',
          content: 'bad hands',
          promptType: FixedTagPromptType.negative,
        );
        final existingLink = FixedTagLink.create(
          positiveEntryId: positive.id,
          negativeEntryId: negative.id,
        );
        final storage =
            _SidebarTestStorage(
                fixedEntries: [positive, negative],
                categories: const [],
                libraryEntries: const [],
              )
              ..fixedSidebarViewMode = viewMode
              ..linksJson = jsonEncode([existingLink.toJson()]);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              localStorageServiceProvider.overrideWith((ref) => storage),
            ],
            child: const MaterialApp(
              locale: Locale('zh'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: SizedBox(
                  width: 340,
                  height: 620,
                  child: FixedTagsSidebar(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final container = ProviderScope.containerOf(
          tester.element(find.byType(FixedTagsSidebar)),
        );
        expect(container.read(fixedTagsNotifierProvider).links, hasLength(1));

        final endpoint = find.byIcon(Icons.link_rounded).last;
        final endpointCenter = tester.getCenter(endpoint);
        await tester.dragFrom(endpointCenter, const Offset(12, 0));
        await tester.pumpAndSettle();
        expect(container.read(fixedTagsNotifierProvider).links, hasLength(1));

        await tester.dragFrom(endpointCenter, const Offset(72, 0));
        await tester.pumpAndSettle();

        expect(container.read(fixedTagsNotifierProvider).links, isEmpty);
        expect(storage.linksJson, '[]');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('touch layout exposes copy, edit and delete without hover', (
    tester,
  ) async {
    final entry = FixedTagEntry.create(
      name: 'touch entry',
      content: 'tag',
      enabled: true,
    );
    final storage = _SidebarTestStorage(
      fixedEntries: [entry],
      categories: const [],
      libraryEntries: const [],
    );

    await _pumpSidebar(
      tester,
      storage,
      interactionPolicy: const InteractionPolicy(
        modality: InteractionModality.touch,
        touchAvailable: true,
        precisePointerAvailable: true,
      ),
    );

    final menu = find.byKey(const ValueKey('sidebar-entry-actions-menu'));
    expect(menu, findsOneWidget);
    await tester.tap(menu);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
    expect(find.byIcon(Icons.edit_rounded), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'sidebar edit uses an adaptive form at 320px, 3x text, SafeArea and IME',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final existing = FixedTagEntry.create(
        name: 'existing fixed tag',
        content: 'original content',
        weight: 1.4,
        position: FixedTagPosition.suffix,
        enabled: false,
        promptType: FixedTagPromptType.negative,
      );
      final storage = _SidebarTestStorage(
        fixedEntries: [existing],
        categories: const [],
        libraryEntries: const [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            localStorageServiceProvider.overrideWith((ref) => storage),
          ],
          child: MaterialApp(
            locale: const Locale('zh'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: const TextScaler.linear(3),
                padding: const EdgeInsets.only(top: 24, bottom: 16),
                viewPadding: const EdgeInsets.only(top: 24, bottom: 16),
                viewInsets: const EdgeInsets.only(bottom: 180),
              ),
              child: child!,
            ),
            home: const Scaffold(
              body: InteractionPolicyScope(
                initialPolicy: InteractionPolicy(
                  modality: InteractionModality.touch,
                  touchAvailable: true,
                  precisePointerAvailable: false,
                ),
                child: SafeArea(
                  child: SizedBox(width: 320, child: FixedTagsSidebar()),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('sidebar-entry-actions-menu')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_rounded));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('adaptive-full-screen-form')),
        findsOneWidget,
      );
      final existingContentField = find.byWidgetPredicate(
        (widget) =>
            widget is EditableText &&
            widget.controller.text == 'original content',
      );
      expect(existingContentField, findsOneWidget);
      await tester.tap(find.text('保存').hitTestable());
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(FixedTagsSidebar)),
      );
      final edited = container.read(fixedTagsNotifierProvider).entries.single;
      expect(edited.id, existing.id);
      expect(edited.content, 'original content');
      expect(edited.weight, 1.4);
      expect(edited.position, FixedTagPosition.suffix);
      expect(edited.enabled, isFalse);
      expect(edited.promptType, FixedTagPromptType.negative);
      expect(
        find.byKey(const ValueKey('adaptive-full-screen-form')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'sidebar add returns every fixed-tag field through adaptive form',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final storage = _SidebarTestStorage(
        fixedEntries: const [],
        categories: const [],
        libraryEntries: const [],
      );
      await _pumpSidebar(tester, storage);

      final addMenu = find.byWidgetPredicate(
        (widget) => widget is PopupMenuButton && widget.tooltip == '添加',
      );
      await tester.tap(addMenu);
      await tester.pumpAndSettle();
      await tester.tap(find.text('新增负向固定词'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('adaptive-full-screen-form')),
        findsOneWidget,
      );
      final contentField = find.byWidgetPredicate(
        (widget) =>
            widget is EditableText &&
            widget.keyboardType == TextInputType.multiline,
      );
      expect(contentField, findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FixedTagsSidebar)),
      );
      await tester.enterText(contentField, ',');
      await tester.pump();
      await tester.tap(find.text('保存').hitTestable());
      for (
        var attempt = 0;
        attempt < 10 &&
            container.read(fixedTagsNotifierProvider).entries.isEmpty;
        attempt++
      ) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      final added = container.read(fixedTagsNotifierProvider).entries.single;
      expect(added.content, ',');
      expect(added.promptType, FixedTagPromptType.negative);
      expect(added.position, FixedTagPosition.prefix);
      expect(added.enabled, isTrue);
      expect(added.weight, 1.0);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('grid mode preserves readable cards with library thumbnails', (
    tester,
  ) async {
    final libraryEntries = [
      TagLibraryEntry.create(
        name: 'thumb one',
        content: 'one',
        thumbnail: 'missing-one.png',
      ),
      TagLibraryEntry.create(
        name: 'thumb two',
        content: 'two',
        thumbnail: 'missing-two.png',
      ),
      TagLibraryEntry.create(
        name: 'thumb three',
        content: 'three',
        thumbnail: 'missing-three.png',
      ),
    ];
    final fixedEntries = [
      for (final entry in libraryEntries)
        FixedTagEntry.create(
          name: entry.name,
          content: entry.content,
          sourceEntryId: entry.id,
        ),
    ];
    final storage = _SidebarTestStorage(
      fixedEntries: fixedEntries,
      categories: const [],
      libraryEntries: libraryEntries,
    )..fixedSidebarViewMode = 'grid';

    await tester.pumpWidget(
      ProviderScope(
        overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
        child: const MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SizedBox(width: 360, height: 900, child: FixedTagsSidebar()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ThumbnailDisplay), findsNWidgets(2));

    final tiles = find.byType(SidebarEntryTile);
    expect(tiles, findsNWidgets(2));
    final firstTop = tester.getTopLeft(tiles.at(0)).dy;
    expect(tester.getTopLeft(tiles.at(1)).dy, closeTo(firstTop, 1));

    final scrollView = tester.widget<CustomScrollView>(
      find.byType(CustomScrollView),
    );
    scrollView.controller!.jumpTo(
      scrollView.controller!.position.maxScrollExtent,
    );
    await tester.pumpAndSettle();
    expect(find.text('thumb three'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'positive list keeps exact scroll metrics across uneven sections and search changes',
    (tester) async {
      final fixture = _buildUnevenPositiveFixture();
      final storage = _SidebarTestStorage(
        fixedEntries: fixture.entries,
        categories: fixture.categories,
        libraryEntries: const [],
      );

      await _pumpSidebar(tester, storage, textScale: 1.35);

      final positiveScrollView = find.byType(CustomScrollView);
      final controller = tester
          .widget<CustomScrollView>(positiveScrollView)
          .controller!;
      final initialMax = await _expectStableScrollMetrics(
        tester,
        controller: controller,
        scrollable: positiveScrollView,
      );

      controller.jumpTo(0);
      await tester.enterText(find.byType(TextField), 'section-3-');
      await tester.pumpAndSettle();

      final filteredMax = controller.position.maxScrollExtent;
      expect(filteredMax, greaterThan(0));
      expect(filteredMax, lessThan(initialMax));
      await _expectStableScrollMetrics(
        tester,
        controller: controller,
        scrollable: positiveScrollView,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'positive grid keeps exact scroll metrics across uneven sections',
    (tester) async {
      final fixture = _buildUnevenPositiveFixture();
      final storage = _SidebarTestStorage(
        fixedEntries: fixture.entries,
        categories: fixture.categories,
        libraryEntries: const [],
      )..fixedSidebarViewMode = 'grid';

      await _pumpSidebar(tester, storage);

      final positiveScrollView = find.byType(CustomScrollView);
      final controller = tester
          .widget<CustomScrollView>(positiveScrollView)
          .controller!;
      await _expectStableScrollMetrics(
        tester,
        controller: controller,
        scrollable: positiveScrollView,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('negative list keeps exact scroll metrics while scrolling', (
    tester,
  ) async {
    final entries = [
      for (var index = 0; index < 32; index++)
        FixedTagEntry.create(
          name: 'negative-$index',
          content: 'negative tag $index',
          enabled: false,
          promptType: FixedTagPromptType.negative,
          sortOrder: index,
        ),
    ];
    final storage = _SidebarTestStorage(
      fixedEntries: entries,
      categories: const [],
      libraryEntries: const [],
    );

    await _pumpSidebar(tester, storage, textScale: 1.35);

    final negativeList = find.byType(ReorderableListView);
    expect(negativeList, findsOneWidget);
    final controller = tester
        .widget<ReorderableListView>(negativeList)
        .scrollController!;
    await _expectStableScrollMetrics(
      tester,
      controller: controller,
      scrollable: negativeList,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'category chip scrolls to a section beyond the initial viewport',
    (tester) async {
      final near = TagLibraryCategory.create(name: 'Near', sortOrder: 0);
      final far = TagLibraryCategory.create(name: 'Far', sortOrder: 1);
      final entries = [
        for (var index = 0; index < 30; index++)
          FixedTagEntry.create(
            name: 'near-$index',
            content: 'near tag $index',
            enabled: false,
            categoryId: near.id,
            sortOrder: index,
          ),
        FixedTagEntry.create(
          name: 'far-entry',
          content: 'far tag',
          enabled: false,
          categoryId: far.id,
          sortOrder: 30,
        ),
      ];
      final storage = _SidebarTestStorage(
        fixedEntries: entries,
        categories: [near, far],
        libraryEntries: const [],
      );

      await _pumpSidebar(
        tester,
        storage,
        interactionPolicy: const InteractionPolicy(
          modality: InteractionModality.pointer,
          touchAvailable: false,
          precisePointerAvailable: true,
        ),
      );

      final positiveScrollView = find.byType(CustomScrollView);
      final controller = tester
          .widget<CustomScrollView>(positiveScrollView)
          .controller!;
      final initialMax = controller.position.maxScrollExtent;

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('Far 1')));
      await mouse.down(tester.getCenter(find.text('Far 1')));
      await mouse.up();
      await tester.pumpAndSettle();

      expect(controller.offset, greaterThan(0));
      expect(controller.position.maxScrollExtent, closeTo(initialMax, 0.01));
      expect(
        tester
            .getRect(positiveScrollView)
            .overlaps(tester.getRect(find.text('Far'))),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'SidebarEntryTile shows a linked preview image after the hover delay',
    (tester) async {
      tester.view.physicalSize = const Size(1000, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final entry = FixedTagEntry.create(name: 'tile', content: 'tag');
      final libraryEntry = TagLibraryEntry.create(
        name: 'tile',
        content: 'tag',
        thumbnail: 'missing-preview.png',
        thumbnailOffsetX: 0.25,
        thumbnailOffsetY: -0.5,
        thumbnailScale: 1.4,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 280,
                child: SidebarEntryTile(
                  entry: entry,
                  libraryEntry: libraryEntry,
                  categoryColor: Colors.blue,
                  isListMode: true,
                  onToggle: () {},
                  onEdit: () {},
                  onDelete: () {},
                ),
              ),
            ),
          ),
        ),
      );

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byType(SidebarEntryTile)));
      await tester.pump(const Duration(milliseconds: 299));

      const previewKey = ValueKey('hover-image-preview-overlay');
      expect(find.byKey(previewKey), findsNothing);

      await tester.pump(const Duration(milliseconds: 1));

      expect(find.byKey(previewKey), findsOneWidget);
      final previewThumbnail = tester.widget<ThumbnailDisplay>(
        find.descendant(
          of: find.byKey(previewKey),
          matching: find.byType(ThumbnailDisplay),
        ),
      );
      expect(previewThumbnail.imagePath, libraryEntry.thumbnail);
      expect(previewThumbnail.offsetX, libraryEntry.thumbnailOffsetX);
      expect(previewThumbnail.offsetY, libraryEntry.thumbnailOffsetY);
      expect(previewThumbnail.scale, libraryEntry.thumbnailScale);

      final previewRect = tester.getRect(find.byKey(previewKey));
      expect(previewRect.width, 320);
      expect(previewRect.height, 180);
      expect(previewRect.left, greaterThanOrEqualTo(16));
      expect(previewRect.right, lessThanOrEqualTo(984));
      expect(previewRect.top, greaterThanOrEqualTo(16));
      expect(previewRect.bottom, lessThanOrEqualTo(584));

      await mouse.moveTo(const Offset(16, 16));
      await tester.pump();

      expect(find.byKey(previewKey), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('SidebarEntryTile skips hover preview without an image', (
    tester,
  ) async {
    final entry = FixedTagEntry.create(name: 'tile', content: 'tag');
    final libraryEntry = TagLibraryEntry.create(name: 'tile', content: 'tag');

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 280,
              child: SidebarEntryTile(
                entry: entry,
                libraryEntry: libraryEntry,
                categoryColor: Colors.blue,
                isListMode: true,
                onToggle: () {},
                onEdit: () {},
                onDelete: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.byType(HoverImagePreview), findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byType(SidebarEntryTile)));
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byKey(const ValueKey('hover-image-preview-overlay')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'SidebarEntryTile pointer actions remain full-size and invoke commands at 320',
    (tester) async {
      tester.view.physicalSize = const Size(320, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var edited = 0;
      var deleted = 0;
      String? copiedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final entry = FixedTagEntry.create(name: 'tile', content: 'copied tag');
      await _pumpEntryTile(
        tester,
        entry: entry,
        width: 288,
        policy: const InteractionPolicy(
          modality: InteractionModality.pointer,
          touchAvailable: false,
          precisePointerAvailable: true,
        ),
        onEdit: () => edited++,
        onDelete: () => deleted++,
      );

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer();
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.byType(SidebarEntryTile)));
      await tester.pumpAndSettle();

      expect(find.byType(FittedBox), findsNothing);
      for (final icon in const [
        Icons.copy_rounded,
        Icons.edit_rounded,
        Icons.delete_outline_rounded,
      ]) {
        final iconFinder = find.byIcon(icon);
        expect(iconFinder, findsOneWidget);
        expect(tester.getSize(iconFinder), const Size.square(15));
      }

      await tester.tap(find.byIcon(Icons.copy_rounded));
      await tester.tap(find.byIcon(Icons.edit_rounded));
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));

      expect(copiedText, 'copied tag');
      expect(edited, 1);
      expect(deleted, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('SidebarEntryTile touch menu invokes edit and delete callbacks', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var edited = 0;
    var deleted = 0;
    await _pumpEntryTile(
      tester,
      entry: FixedTagEntry.create(name: 'tile', content: 'tag'),
      width: 288,
      policy: const InteractionPolicy(
        modality: InteractionModality.touch,
        touchAvailable: true,
        precisePointerAvailable: false,
      ),
      onEdit: () => edited++,
      onDelete: () => deleted++,
    );

    final menu = find.byKey(const ValueKey('sidebar-entry-actions-menu'));
    expect(menu, findsOneWidget);

    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_rounded));
    await tester.pumpAndSettle();

    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline_rounded));
    await tester.pumpAndSettle();

    expect(edited, 1);
    expect(deleted, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'SidebarEntryTile 3x menu invokes copy, edit and delete without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var edited = 0;
      var deleted = 0;
      String? copiedText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copiedText =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      final entry = FixedTagEntry.create(name: 'tile', content: 'copied tag');
      await _pumpEntryTile(
        tester,
        entry: entry,
        width: 288,
        textScale: 3,
        policy: const InteractionPolicy(
          modality: InteractionModality.pointer,
          touchAvailable: false,
          precisePointerAvailable: true,
        ),
        onEdit: () => edited++,
        onDelete: () => deleted++,
      );

      final menu = find.byKey(const ValueKey('sidebar-entry-actions-menu'));
      expect(menu, findsOneWidget);
      expect(find.byType(FittedBox), findsNothing);

      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.copy_rounded));
      await tester.pumpAndSettle();

      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.edit_rounded));
      await tester.pumpAndSettle();

      await tester.tap(menu);
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      expect(copiedText, 'copied tag');
      expect(edited, 1);
      expect(deleted, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('SidebarEntryTile triggers edit action after hover', (
    tester,
  ) async {
    var edited = false;
    final entry = FixedTagEntry.create(name: 'tile', content: 'tag');

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: InteractionPolicyScope(
            initialPolicy: const InteractionPolicy(
              modality: InteractionModality.pointer,
              touchAvailable: false,
              precisePointerAvailable: true,
            ),
            child: Center(
              child: SizedBox(
                width: 320,
                child: SidebarEntryTile(
                  entry: entry,
                  categoryColor: Colors.blue,
                  isListMode: true,
                  onToggle: () {},
                  onEdit: () => edited = true,
                  onDelete: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer();
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.byType(SidebarEntryTile)));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.remove_rounded), findsNothing);
    expect(find.byIcon(Icons.add_rounded), findsNothing);

    await tester.tap(find.byIcon(Icons.edit_rounded));

    expect(edited, isTrue);
  });
}

Future<void> _jumpToEndUntilVisible(
  WidgetTester tester,
  ScrollController controller,
  Finder target,
) async {
  for (var i = 0; i < 10 && target.evaluate().isEmpty; i++) {
    controller.jumpTo(controller.position.maxScrollExtent);
    await tester.pump();
  }
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pump();
}

Future<void> _pumpEntryTile(
  WidgetTester tester, {
  required FixedTagEntry entry,
  required double width,
  required InteractionPolicy policy,
  required VoidCallback onEdit,
  required VoidCallback onDelete,
  double textScale = 1,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: InteractionPolicyScope(
          initialPolicy: policy,
          child: Center(
            child: SizedBox(
              width: width,
              child: SidebarEntryTile(
                entry: entry,
                categoryColor: Colors.blue,
                isListMode: true,
                onToggle: () {},
                onEdit: onEdit,
                onDelete: onDelete,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

({List<TagLibraryCategory> categories, List<FixedTagEntry> entries})
_buildUnevenPositiveFixture() {
  const counts = [1, 18, 3, 24];
  final categories = [
    for (var index = 0; index < counts.length; index++)
      TagLibraryCategory.create(name: 'Section $index', sortOrder: index),
  ];
  final entries = <FixedTagEntry>[
    for (var sectionIndex = 0; sectionIndex < categories.length; sectionIndex++)
      for (var entryIndex = 0; entryIndex < counts[sectionIndex]; entryIndex++)
        FixedTagEntry.create(
          name: 'section-$sectionIndex-entry-$entryIndex',
          content: 'tag section-$sectionIndex-$entryIndex',
          enabled: false,
          categoryId: categories[sectionIndex].id,
          sortOrder: entryIndex,
        ),
  ];
  return (categories: categories, entries: entries);
}

Future<void> _pumpSidebar(
  WidgetTester tester,
  _SidebarTestStorage storage, {
  double textScale = 1,
  InteractionPolicy? interactionPolicy,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          );
        },
        home: Scaffold(
          body: InteractionPolicyScope(
            initialPolicy: interactionPolicy,
            child: const SizedBox(
              width: 340,
              height: 620,
              child: FixedTagsSidebar(),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<double> _expectStableScrollMetrics(
  WidgetTester tester, {
  required ScrollController controller,
  required Finder scrollable,
}) async {
  expect(controller.hasClients, isTrue);
  controller.jumpTo(0);
  await tester.pump();

  final initialMax = controller.position.maxScrollExtent;
  final initialViewport = controller.position.viewportDimension;
  final initialVisibleFraction =
      initialViewport / (initialMax + initialViewport);
  expect(initialMax, greaterThan(0));

  await tester.sendEventToBinding(
    PointerScrollEvent(
      kind: PointerDeviceKind.mouse,
      position: tester.getCenter(scrollable),
      scrollDelta: const Offset(0, 120),
    ),
  );
  await tester.pump();

  expect(controller.offset, greaterThan(0));
  _expectScrollMetrics(
    controller,
    maxScrollExtent: initialMax,
    viewportDimension: initialViewport,
    visibleFraction: initialVisibleFraction,
  );

  controller.jumpTo(0);
  await tester.pump();
  var previousOffset = controller.offset;
  for (final fraction in const [0.2, 0.5, 0.8, 0.98]) {
    final target = initialMax * fraction;
    controller.jumpTo(target);
    await tester.pump();

    expect(controller.offset, greaterThan(previousOffset));
    expect(controller.offset, closeTo(target, 0.01));
    _expectScrollMetrics(
      controller,
      maxScrollExtent: initialMax,
      viewportDimension: initialViewport,
      visibleFraction: initialVisibleFraction,
    );
    previousOffset = controller.offset;
  }

  return initialMax;
}

void _expectScrollMetrics(
  ScrollController controller, {
  required double maxScrollExtent,
  required double viewportDimension,
  required double visibleFraction,
}) {
  final position = controller.position;
  expect(position.maxScrollExtent, closeTo(maxScrollExtent, 0.01));
  expect(position.viewportDimension, closeTo(viewportDimension, 0.01));
  expect(
    position.viewportDimension /
        (position.maxScrollExtent + position.viewportDimension),
    closeTo(visibleFraction, 0.0001),
  );
}

bool _linkPainterHasPreview(WidgetTester tester) {
  final customPaints = tester.widgetList<CustomPaint>(find.byType(CustomPaint));
  for (final customPaint in customPaints) {
    final painter = customPaint.painter;
    if (painter is! SidebarLinkPainter) continue;
    try {
      final dynamic linkPainter = painter;
      return linkPainter.previewStart != null && linkPainter.previewEnd != null;
    } catch (_) {
      return false;
    }
  }
  return false;
}

class _SidebarTestStorage extends LocalStorageService {
  _SidebarTestStorage({
    required this.fixedEntries,
    required this.categories,
    required this.libraryEntries,
  });

  final List<FixedTagEntry> fixedEntries;
  final List<TagLibraryCategory> categories;
  final List<TagLibraryEntry> libraryEntries;

  bool fixedSidebarExpanded = true;
  bool promptMaximized = false;
  double fixedSidebarWidth = 320.0;
  String fixedSidebarViewMode = 'list';
  double negativeHeight = 180.0;
  String linksJson = '[]';

  @override
  bool getLeftPanelExpanded() => true;

  @override
  bool getRightPanelExpanded() => true;

  @override
  double getLeftPanelWidth() => 300.0;

  @override
  double getRightPanelWidth() => 280.0;

  @override
  double getPromptAreaHeight() => 200.0;

  @override
  bool getPromptMaximized() => promptMaximized;

  @override
  Future<void> setPromptMaximized(bool maximized) async {
    promptMaximized = maximized;
  }

  @override
  bool getFixedTagsSidebarExpanded() => fixedSidebarExpanded;

  @override
  Future<void> setFixedTagsSidebarExpanded(bool expanded) async {
    fixedSidebarExpanded = expanded;
  }

  @override
  double getFixedTagsSidebarWidth() => fixedSidebarWidth;

  @override
  Future<void> setFixedTagsSidebarWidth(double width) async {
    fixedSidebarWidth = width;
  }

  @override
  String getFixedTagsSidebarViewMode() => fixedSidebarViewMode;

  @override
  Future<void> setFixedTagsSidebarViewMode(String mode) async {
    fixedSidebarViewMode = mode;
  }

  @override
  double getFixedTagsNegativeHeight() => negativeHeight;

  @override
  Future<void> setFixedTagsNegativeHeight(double height) async {
    negativeHeight = height;
  }

  @override
  String? getFixedTagsJson() {
    return jsonEncode(fixedEntries.map((entry) => entry.toJson()).toList());
  }

  @override
  Future<void> setFixedTagsJson(String json) async {}

  @override
  String? getFixedTagLinksJson() => linksJson;

  @override
  Future<void> setFixedTagLinksJson(String json) async {
    linksJson = json;
  }

  @override
  bool getFixedTagsNegativePanelExpanded() => true;

  @override
  String? getTagLibraryEntriesJson() {
    return jsonEncode(libraryEntries.map((entry) => entry.toJson()).toList());
  }

  @override
  String? getTagLibraryCategoriesJson() {
    return jsonEncode(categories.map((category) => category.toJson()).toList());
  }

  @override
  int getTagLibraryViewMode() => 1;

  @override
  bool getEnableAutocomplete() => false;

  @override
  bool getAutoFormatPrompt() => false;

  @override
  bool getHighlightEmphasis() => false;

  @override
  bool getSdSyntaxAutoConvert() => false;

  @override
  bool getEnableCooccurrenceRecommendation() => false;

  @override
  String getLastPrompt() => '';

  @override
  String getLastNegativePrompt() => '';

  @override
  String getDefaultModel() => 'nai-diffusion-4-5-full';

  @override
  String getDefaultSampler() => 'k_euler_ancestral';

  @override
  int getDefaultSteps() => 28;

  @override
  double getDefaultScale() => 5.0;
}
