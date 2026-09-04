import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/vibe/vibe_import_progress.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_category.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/providers/selection_mode_provider.dart';
import 'package:nai_launcher/presentation/providers/vibe_library_category_provider.dart';
import 'package:nai_launcher/presentation/providers/vibe_library_provider.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/vibe_library_commands.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/vibe_library_screen.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/vibe_library_screen_controller.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/vibe_library_workspace.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/widgets/category/vibe_category_item.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/widgets/menus/vibe_import_menu.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/widgets/vibe_card.dart';
import 'package:nai_launcher/presentation/widgets/common/pro_context_menu.dart';
import 'package:nai_launcher/presentation/widgets/common/pagination_bar.dart';
import 'package:nai_launcher/presentation/widgets/gallery/gallery_sidebar.dart';
import 'package:nai_launcher/presentation/widgets/gallery/gallery_library_toolbar.dart';

void main() {
  test('vibe grid uses fewer larger cards at 3x text scale', () {
    final normal = computeVibeLibraryGridLayout(1160, 1);
    final scaled = computeVibeLibraryGridLayout(1160, 3);
    final phone = computeVibeLibraryGridLayout(288, 1);

    expect(scaled.columns, lessThan(normal.columns));
    expect(scaled.itemWidth, greaterThan(normal.itemWidth));
    expect(phone.columns, 1);
  });

  for (final width in [320.0, 600.0, 840.0, 1180.0, 1600.0]) {
    testWidgets(
      'non-empty vibe library keeps toolbar, search and multi-select reachable at ${width.toInt()}px',
      (tester) async {
        await _setViewport(tester, Size(width, 800));
        final commands = <VibeLibraryCommand>[];
        final searches = <String>[];
        final controller = VibeLibraryScreenController(
          onSearch: (query) async => searches.add(query),
        );
        addTearDown(controller.dispose);
        await _pumpWorkspace(tester, controller, commands);

        expect(find.text('测试 Vibe'), findsOneWidget);
        expect(find.byType(GalleryLibraryToolbar), findsOneWidget);
        expect(find.byType(GalleryLibrarySearchField), findsOneWidget);
        expect(
          find.byType(GalleryLibrarySortMenu<VibeLibrarySortOrder>),
          findsOneWidget,
        );
        for (final label in ['分类', '多选', '导入', '导出', '刷新']) {
          expect(
            find.descendant(
              of: find.byType(GalleryLibraryToolbar),
              matching: find.text(label),
            ),
            findsOneWidget,
          );
        }
        final cardSize = tester.getSize(find.byType(VibeCard).first);
        expect(
          cardSize.width / cardSize.height,
          closeTo(vibeCardAspectRatio, 0.001),
        );
        expect(find.byTooltip('进入选择模式'), findsOneWidget);
        expect(
          find.byTooltip('导入 Vibe 文件或 PNG/JPG/JPEG/WEBP 图片（右键查看更多选项）'),
          findsOneWidget,
        );

        final search = find.byType(TextField);
        expect(search, findsOneWidget);
        await tester.enterText(search, '测试');
        await tester.pump(const Duration(milliseconds: 300));
        expect(searches, contains('测试'));

        await tester.tap(find.byTooltip('进入选择模式'));
        await tester.pump();
        expect(commands.whereType<EnterSelectionModeCommand>(), hasLength(1));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('touch import tap opens the explicit import choices', (
    tester,
  ) async {
    await _setViewport(tester, const Size(320, 800));
    final commands = <VibeLibraryCommand>[];
    final controller = VibeLibraryScreenController(onSearch: (_) async {});
    addTearDown(controller.dispose);
    await _pumpWorkspace(
      tester,
      controller,
      commands,
      interactionPolicy: InteractionPolicy.touchFirst,
    );

    await _revealToolbarImport(tester);

    await tester.tap(
      find.byTooltip('导入 Vibe 文件或 PNG/JPG/JPEG/WEBP 图片（右键查看更多选项）'),
    );
    await tester.pump();

    expect(commands.whereType<ShowImportMenuCommand>(), hasLength(1));
    expect(commands.whereType<ImportVibesCommand>(), isEmpty);
  });

  testWidgets('desktop reuses gallery sidebar and pagination contracts', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1600, 900));
    final commands = <VibeLibraryCommand>[];
    final controller = VibeLibraryScreenController(onSearch: (_) async {});
    addTearDown(controller.dispose);
    final category = VibeLibraryCategory(
      id: 'portraits',
      name: '肖像',
      sortOrder: 0,
      createdAt: DateTime(2026),
    );
    final template = _PopulatedVibeLibraryNotifier.initialState.entries.single;
    final entries = List.generate(
      120,
      (index) => template.copyWith(
        id: 'vibe-$index',
        name: 'Vibe $index',
        categoryId: index < 3 ? category.id : null,
        isFavorite: index < 2,
      ),
    );
    await _pumpWorkspace(
      tester,
      controller,
      commands,
      libraryState: VibeLibraryState(entries: entries, pageSize: 20),
      categoryState: VibeLibraryCategoryState(categories: [category]),
    );

    expect(find.byKey(const ValueKey('vibe-library-all')), findsOneWidget);
    expect(find.text('全部 Vibe'), findsOneWidget);
    expect(find.text('收藏'), findsOneWidget);
    expect(find.text('肖像'), findsOneWidget);
    expect(find.text('文件夹'), findsNothing);
    expect(find.byType(GallerySidebarNavigationItem), findsOneWidget);
    const toolbarKey = ValueKey('vibe-library-toolbar');
    expect(
      tester.getSize(find.byKey(toolbarKey)).height,
      GalleryCollectionChrome.toolbarHeight,
    );
    expect(
      find.descendant(
        of: find.byKey(toolbarKey),
        matching: find.text('Vibe 库'),
      ),
      findsOneWidget,
    );
    expect(tester.getTopLeft(find.byKey(toolbarKey)).dx, 0);
    expect(tester.getSize(find.byKey(toolbarKey)).width, 1600);

    double navigationIconX(String label) {
      final row = find.ancestor(
        of: find.text(label),
        matching: find.byType(InkWell),
      );
      return tester
          .getCenter(
            find.descendant(of: row, matching: find.byType(Icon)).first,
          )
          .dx;
    }

    expect(navigationIconX('肖像'), closeTo(navigationIconX('收藏'), 0.1));
    expect(
      tester
          .widget<VibeCategoryItem>(
            find.byKey(const ValueKey('vibe-library-category-portraits')),
          )
          .count,
      3,
    );
    expect(find.byType(PaginationBar), findsOneWidget);

    final pagination = tester.widget<PaginationBar>(find.byType(PaginationBar));
    final paginationRect = tester.getRect(find.byType(PaginationBar));
    expect(paginationRect.height, lessThanOrEqualTo(112));
    expect(paginationRect.bottom, 900);
    expect(pagination.tonalCard, isTrue);
    expect(pagination.totalPages, 6);
    expect(pagination.totalItems, 120);
    pagination.onPageChanged(1);
    expect(commands.whereType<ChangePageCommand>().single.page, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('touch import choices use an adaptive action panel', (
    tester,
  ) async {
    await _setViewport(tester, const Size(320, 800));
    var selected = false;
    await tester.pumpWidget(
      MaterialApp(
        home: InteractionPolicyScope(
          initialPolicy: InteractionPolicy.touchFirst,
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => context.showImportMenu(
                  position: Offset.zero,
                  items: [
                    const ProMenuItem(id: 'file', label: 'Vibe 文件'),
                    ProMenuItem(
                      id: 'image',
                      label: '图片',
                      onTap: () => selected = true,
                    ),
                    const ProMenuItem(id: 'clipboard', label: '剪贴板'),
                  ],
                ),
                child: const Text('导入'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('导入'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('adaptive-bottom-sheet')), findsOneWidget);
    expect(find.text('Vibe 文件'), findsOneWidget);
    expect(find.text('图片'), findsOneWidget);
    expect(find.text('剪贴板'), findsOneWidget);

    await tester.tap(find.text('图片'));
    await tester.pumpAndSettle();
    expect(selected, isTrue);
  });

  testWidgets(
    'touch-first import reaches the image action and SafeArea progress overlay',
    (tester) async {
      await _setViewport(
        tester,
        const Size(320, 720),
        padding: const FakeViewPadding(top: 24, bottom: 24),
      );
      final commands = <VibeLibraryCommand>[];
      final controller = VibeLibraryScreenController(onSearch: (_) async {});
      addTearDown(controller.dispose);
      await _pumpTouchImportFlow(tester, controller, commands);

      await _revealToolbarImport(tester);

      await tester.tap(
        find.byTooltip('导入 Vibe 文件或 PNG/JPG/JPEG/WEBP 图片（右键查看更多选项）'),
      );
      await tester.pumpAndSettle();

      expect(commands.whereType<ShowImportMenuCommand>(), hasLength(1));
      final panel = find.byKey(const ValueKey('adaptive-bottom-sheet'));
      expect(panel, findsOneWidget);
      expect(tester.getRect(panel).top, greaterThanOrEqualTo(24));
      expect(find.text('从图片导入').hitTestable(), findsOneWidget);

      await tester.tap(find.text('从图片导入'));
      await tester.pumpAndSettle();

      expect(find.text('正在导入...'), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.text('正在读取图片'), findsOneWidget);
      final overlayCenter = find.ancestor(
        of: find.text('正在导入...'),
        matching: find.byType(Center),
      );
      expect(overlayCenter, findsOneWidget);
      final overlayRect = tester.getRect(overlayCenter);
      expect(overlayRect.top, greaterThanOrEqualTo(24));
      expect(overlayRect.bottom, lessThanOrEqualTo(720 - 24));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('precise pointer primary tap keeps the default file import', (
    tester,
  ) async {
    final commands = await _pumpPointerWorkspace(tester);
    final importButton = find.byTooltip(
      '导入 Vibe 文件或 PNG/JPG/JPEG/WEBP 图片（右键查看更多选项）',
    );

    await tester.tapAt(
      tester.getCenter(importButton),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();

    expect(commands.whereType<ImportVibesCommand>(), hasLength(1));
    expect(commands.whereType<ShowImportMenuCommand>(), isEmpty);
  });

  testWidgets('precise pointer secondary tap keeps the anchored menu', (
    tester,
  ) async {
    final commands = await _pumpPointerWorkspace(tester);
    final secondaryTargets = find.byWidgetPredicate(
      (widget) => widget is GestureDetector && widget.onSecondaryTapUp != null,
    );
    expect(secondaryTargets, findsWidgets);
    for (final target in secondaryTargets.evaluate()) {
      (target.widget as GestureDetector).onSecondaryTapUp!(
        TapUpDetails(
          globalPosition: const Offset(400, 200),
          kind: PointerDeviceKind.mouse,
        ),
      );
    }
    await tester.pump();

    expect(commands.whereType<ShowImportMenuCommand>(), hasLength(1));
    expect(commands.whereType<ImportVibesCommand>(), isEmpty);
  });

  testWidgets(
    'category destination list supports 320px, 3x text, IME and SafeArea',
    (tester) async {
      final categories = _buildCategories(20);
      await _setViewport(
        tester,
        const Size(320, 720),
        padding: const FakeViewPadding(top: 24, bottom: 24),
        viewInsets: const FakeViewPadding(bottom: 220),
      );
      await _pumpCategoryPanelHost(
        tester,
        categories: categories,
        textScale: 3,
      );

      await tester.tap(find.text('open categories'));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('adaptive-bottom-sheet')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('vibe-category-destination-list')),
        findsOneWidget,
      );
      final surface = tester.getRect(
        find.byKey(const ValueKey('adaptive-bottom-sheet')),
      );
      expect(surface.top, greaterThanOrEqualTo(24));
      expect(surface.bottom, lessThanOrEqualTo(720 - 220));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('category destination list uses a bounded centered form', (
    tester,
  ) async {
    await _setViewport(tester, const Size(1600, 900));
    String? selected;
    await _pumpCategoryPanelHost(
      tester,
      categories: _buildCategories(4),
      onResult: (value) => selected = value,
    );

    await tester.tap(find.text('open categories'));
    await tester.pumpAndSettle();

    final surface = find.byKey(const ValueKey('adaptive-centered-form'));
    expect(surface, findsOneWidget);
    expect(tester.getSize(surface).width, 440);
    await tester.tap(find.text('Category 2'));
    await tester.pumpAndSettle();
    expect(selected, 'category-2');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '320px 3x text with SafeArea and IME keeps vibe actions scroll-free and reachable',
    (tester) async {
      await _setViewport(
        tester,
        const Size(320, 720),
        padding: const FakeViewPadding(top: 24, bottom: 24),
        viewInsets: const FakeViewPadding(bottom: 220),
      );
      final controller = VibeLibraryScreenController(onSearch: (_) async {});
      addTearDown(controller.dispose);
      await _pumpWorkspace(
        tester,
        controller,
        <VibeLibraryCommand>[],
        textScale: 3,
      );

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byTooltip('进入选择模式'), findsOneWidget);
      expect(
        find.byTooltip('导入 Vibe 文件或 PNG/JPG/JPEG/WEBP 图片（右键查看更多选项）'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

Future<void> _pumpTouchImportFlow(
  WidgetTester tester,
  VibeLibraryScreenController controller,
  List<VibeLibraryCommand> commands,
) async {
  final state = _PopulatedVibeLibraryNotifier.initialState;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        vibeLibraryNotifierProvider.overrideWith(
          _PopulatedVibeLibraryNotifier.new,
        ),
        vibeLibraryCategoryNotifierProvider.overrideWith(
          _ResponsiveVibeLibraryCategoryNotifier.new,
        ),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InteractionPolicyScope(
          initialPolicy: InteractionPolicy.touchFirst,
          child: Builder(
            builder: (context) => Scaffold(
              body: AnimatedBuilder(
                animation: controller,
                builder: (context, _) => VibeLibraryWorkspace(
                  libraryState: state,
                  categoryState: const VibeLibraryCategoryState(),
                  selectionState: const SelectionModeState(),
                  currentModel: 'nai-diffusion-4-full',
                  controller: controller,
                  onCommand: (command) {
                    commands.add(command);
                    if (command is! ShowImportMenuCommand) return;
                    context.showImportMenu(
                      position: command.position,
                      items: [
                        const ProMenuItem(id: 'file', label: '从 Vibe 文件导入'),
                        ProMenuItem(
                          id: 'image',
                          label: '从图片导入',
                          onTap: () => controller.beginOperation(
                            progress: const ImportProgress(
                              current: 1,
                              total: 3,
                              message: '正在读取图片',
                            ),
                          ),
                        ),
                        const ProMenuItem(id: 'clipboard', label: '从剪贴板导入'),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<List<VibeLibraryCommand>> _pumpPointerWorkspace(
  WidgetTester tester,
) async {
  await _setViewport(tester, const Size(1180, 800));
  final commands = <VibeLibraryCommand>[];
  final controller = VibeLibraryScreenController(onSearch: (_) async {});
  addTearDown(controller.dispose);
  await _pumpWorkspace(
    tester,
    controller,
    commands,
    interactionPolicy: const InteractionPolicy(
      modality: InteractionModality.pointer,
      touchAvailable: false,
      precisePointerAvailable: true,
    ),
  );
  return commands;
}

Future<void> _setViewport(
  WidgetTester tester,
  Size size, {
  FakeViewPadding? padding,
  FakeViewPadding? viewInsets,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = padding ?? const FakeViewPadding();
  tester.view.viewInsets = viewInsets ?? const FakeViewPadding();
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetPadding();
    tester.view.resetViewInsets();
  });
}

Future<void> _pumpWorkspace(
  WidgetTester tester,
  VibeLibraryScreenController controller,
  List<VibeLibraryCommand> commands, {
  double textScale = 1,
  InteractionPolicy interactionPolicy = InteractionPolicy.neutral,
  VibeLibraryState? libraryState,
  VibeLibraryCategoryState categoryState = const VibeLibraryCategoryState(),
}) async {
  final state = libraryState ?? _PopulatedVibeLibraryNotifier.initialState;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        vibeLibraryNotifierProvider.overrideWith(
          _PopulatedVibeLibraryNotifier.new,
        ),
        vibeLibraryCategoryNotifierProvider.overrideWith(
          _ResponsiveVibeLibraryCategoryNotifier.new,
        ),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: InteractionPolicyScope(
          initialPolicy: interactionPolicy,
          child: Scaffold(
            body: VibeLibraryWorkspace(
              libraryState: state,
              categoryState: categoryState,
              selectionState: const SelectionModeState(),
              currentModel: 'nai-diffusion-4-full',
              controller: controller,
              onCommand: commands.add,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _revealToolbarImport(WidgetTester tester) async {
  final actions = find.byKey(const ValueKey('gallery-library-toolbar-actions'));
  if (actions.evaluate().isNotEmpty) {
    await tester.drag(actions, const Offset(-500, 0));
    await tester.pumpAndSettle();
  }
}

List<VibeLibraryCategory> _buildCategories(int count) => List.generate(
  count,
  (index) => VibeLibraryCategory(
    id: 'category-$index',
    name: 'Category $index',
    sortOrder: index,
    createdAt: DateTime(2026),
  ),
);

class _ResponsiveVibeLibraryCategoryNotifier
    extends VibeLibraryCategoryNotifier {
  @override
  VibeLibraryCategoryState build() => const VibeLibraryCategoryState();
}

Future<void> _pumpCategoryPanelHost(
  WidgetTester tester, {
  required List<VibeLibraryCategory> categories,
  double textScale = 1,
  ValueChanged<String?>? onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              onPressed: () async {
                final result = await VibeCategoryDestinationPanel.show(
                  context,
                  categories: categories,
                );
                onResult?.call(result);
              },
              child: const Text('open categories'),
            ),
          ),
        ),
      ),
    ),
  );
}

class _PopulatedVibeLibraryNotifier extends VibeLibraryNotifier {
  static final initialState = VibeLibraryState(
    entries: [
      VibeLibraryEntry(
        id: 'vibe-1',
        name: '测试 Vibe',
        vibeDisplayName: '测试 Vibe',
        vibeEncoding: 'ZW5jb2RlZA==',
        strength: 0.6,
        infoExtracted: 0.7,
        sourceTypeIndex: VibeSourceType.naiv4vibe.index,
        tags: const ['人物'],
        isFavorite: true,
        createdAt: DateTime(2026),
      ),
    ],
  );

  @override
  VibeLibraryState build() => initialState;
}
