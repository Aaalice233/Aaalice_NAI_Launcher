import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_entry.dart';
import 'package:nai_launcher/data/models/fixed_tag/fixed_tag_prompt_type.dart';
import 'package:nai_launcher/data/models/tag_library/tag_library_category.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/fixed_tags_sidebar.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/fixed_tags_sidebar_slot.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/resize_handle.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/sidebar_entry_tile.dart';
import 'package:nai_launcher/presentation/widgets/common/tile_action_button.dart';

const _pointerPolicy = InteractionPolicy(
  modality: InteractionModality.pointer,
  touchAvailable: false,
  precisePointerAvailable: true,
);

// 触屏与鼠标混用：操作按钮按触屏放大，链接锚点仍按精确指针收紧。
const _hybridTouchPolicy = InteractionPolicy(
  modality: InteractionModality.touch,
  touchAvailable: true,
  precisePointerAvailable: true,
);

const _policies = {
  'pointer': _pointerPolicy,
  'hybrid-touch': _hybridTouchPolicy,
  'touch-only': InteractionPolicy.touchFirst,
};

const _sidebarWidths = [230.0, 320.0, 401.0];
const _textScales = [1.0, 3.0];

void main() {
  late Directory hiveDir;

  setUpAll(() async {
    hiveDir = Directory.systemTemp.createTempSync('fixed_tags_narrow_hive_');
    Hive.init(hiveDir.path);
    // 内存后端：落盘写一旦从 widget test 的 FakeAsync 时钟发起就不会完成，会锁死 box
    await Hive.openBox(StorageKeys.settingsBox, bytes: Uint8List(0));
  });

  setUp(() async {
    await Hive.box(StorageKeys.settingsBox).clear();
  });

  tearDownAll(() async {
    // 有界等待：box 被锁死时快速失败，不把整个测试分片拖到看门狗超时
    await Hive.close().timeout(const Duration(seconds: 10));
    if (await hiveDir.exists()) {
      await hiveDir.delete(recursive: true);
    }
  });

  for (final policyEntry in _policies.entries) {
    for (final viewMode in const ['list', 'grid']) {
      testWidgets(
        '$viewMode entries under ${policyEntry.key} input keep names and '
        'actions within narrow sidebars',
        (tester) async {
          for (final width in _sidebarWidths) {
            for (final scale in _textScales) {
              final scenario = '${policyEntry.key} $viewMode $width/${scale}x';
              await _pumpSidebar(
                tester,
                _NarrowSidebarStorage(viewMode: viewMode),
                width: width,
                textScale: scale,
                policy: policyEntry.value,
              );

              expect(tester.takeException(), isNull, reason: scenario);
              for (final type in FixedTagPromptType.values) {
                await _expectFirstEntryUsable(
                  tester,
                  promptType: type,
                  policy: policyEntry.value,
                  scenario: '$scenario ${type.name}',
                );
              }
            }
          }
        },
      );
    }
  }

  for (final policyEntry in _policies.entries) {
    testWidgets(
      'sidebar chrome under ${policyEntry.key} input fits narrow widths',
      (tester) async {
        for (final width in _sidebarWidths) {
          for (final scale in _textScales) {
            final scenario = '${policyEntry.key} $width/${scale}x';
            await _pumpSidebar(
              tester,
              _NarrowSidebarStorage(),
              width: width,
              textScale: scale,
              policy: policyEntry.value,
            );

            expect(tester.takeException(), isNull, reason: scenario);
            final sidebar = tester.getRect(find.byType(FixedTagsSidebar));
            for (final key in const [
              'fixed-tags-top-card',
              'fixed-tags-positive-card',
              'fixed-tags-negative-card',
              'fixed-tags-collapse-sidebar',
              'fixed-tags-positive-enabled-only',
              'fixed-tags-negative-enabled-only',
            ]) {
              final finder = find.byKey(ValueKey(key));
              expect(finder.hitTestable(), findsOneWidget, reason: scenario);
              _expectHorizontallyInside(
                tester.getRect(finder),
                sidebar,
                reason: '$scenario $key',
              );
            }
            final title = tester.getRect(find.text('固定词侧栏'));
            expect(
              title.width,
              greaterThanOrEqualTo(
                MediaQuery.textScalerOf(
                  tester.element(find.byType(FixedTagsSidebar)),
                ).scale(14),
              ),
              reason: '$scenario 侧栏标题被挤没',
            );
          }
        }
      },
    );
  }

  testWidgets(
    'slot keeps the touch-sized resize handle inside its reserved width',
    (tester) async {
      for (final policyEntry in _policies.entries) {
        for (final sidebarWidth in const [240.0, 393.0]) {
          final scenario = '${policyEntry.key} $sidebarWidth';
          final storage = _NarrowSidebarStorage(sidebarWidth: sidebarWidth);
          late double reservedWidth;
          await tester.pumpWidget(
            _app(
              key: ValueKey(scenario),
              storage: storage,
              policy: policyEntry.value,
              child: Builder(
                builder: (context) {
                  reservedWidth = sidebarWidth + ResizeHandle.extentOf(context);
                  return Align(
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: reservedWidth,
                      height: 760,
                      child: const FixedTagsSidebarSlot(),
                    ),
                  );
                },
              ),
            ),
          );
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull, reason: scenario);
          final handle = tester.getRect(find.byType(ResizeHandle));
          expect(handle.right, closeTo(reservedWidth, 0.01), reason: scenario);
          expect(
            handle.width,
            greaterThanOrEqualTo(
              policyEntry.value.prefersTouchPresentation ? 44.0 : 0.0,
            ),
            reason: scenario,
          );
          expect(handle.left, closeTo(sidebarWidth, 0.01), reason: scenario);
        }
      }
    },
  );

  // 外层只给出偏窄的宽度时，侧栏收窄而不是把拖拽手柄挤出去。
  testWidgets('slot shrinks the sidebar when its reserved width is short', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        storage: _NarrowSidebarStorage(sidebarWidth: 393),
        policy: InteractionPolicy.touchFirst,
        child: const Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 401,
            height: 760,
            child: FixedTagsSidebarSlot(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(tester.getRect(find.byType(ResizeHandle)).right, closeTo(401, 0.01));
    expect(find.byType(ResizeHandle).hitTestable(), findsOneWidget);
  });
}

Future<void> _expectFirstEntryUsable(
  WidgetTester tester, {
  required FixedTagPromptType promptType,
  required InteractionPolicy policy,
  required String scenario,
}) async {
  final card = find.byKey(ValueKey('fixed-tags-${promptType.name}-card'));
  final tile = find.descendant(
    of: card,
    matching: find.byType(SidebarEntryTile),
  );
  expect(tile, findsWidgets, reason: '$scenario 没有可见条目');
  final firstTile = tile.first;
  await tester.ensureVisible(firstTile);
  await tester.pumpAndSettle();
  final entry = tester.widget<SidebarEntryTile>(firstTile).entry;
  final tileRect = tester.getRect(firstTile);
  _expectHorizontallyInside(
    tileRect,
    tester.getRect(card),
    reason: '$scenario 条目越出面板',
  );

  final name = find.descendant(of: firstTile, matching: find.text(entry.name));
  final nameRect = tester.getRect(name);
  final glyphWidth = MediaQuery.textScalerOf(
    tester.element(firstTile),
  ).scale(14);
  expect(
    nameRect.width,
    greaterThanOrEqualTo(glyphWidth),
    reason: '$scenario 名称被挤没',
  );
  _expectHorizontallyInside(nameRect, tileRect, reason: '$scenario 名称越界');

  final buttons = find.descendant(
    of: firstTile,
    matching: find.byType(TileActionButton),
  );
  final menu = find.descendant(
    of: firstTile,
    matching: find.byKey(const ValueKey('sidebar-entry-more-actions')),
  );
  final minimumExtent = policy.touchAvailable ? 44.0 : 0.0;
  if (menu.evaluate().isEmpty) {
    expect(buttons, findsNWidgets(3), reason: scenario);
    for (final icon in const [
      Icons.copy_rounded,
      Icons.edit_rounded,
      Icons.delete_outline_rounded,
    ]) {
      final action = find.descendant(
        of: firstTile,
        matching: find.byIcon(icon),
      );
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      expect(action.hitTestable(), findsOneWidget, reason: '$scenario $icon');
      final button = find.ancestor(
        of: action,
        matching: find.byType(TileActionButton),
      );
      final rect = tester.getRect(button);
      _expectHorizontallyInside(rect, tileRect, reason: '$scenario $icon 越界');
      expect(
        rect.shortestSide,
        greaterThanOrEqualTo(minimumExtent),
        reason: '$scenario $icon 命中区不足',
      );
    }
    return;
  }

  await tester.ensureVisible(menu);
  await tester.pumpAndSettle();
  expect(menu.hitTestable(), findsOneWidget, reason: scenario);
  final menuRect = tester.getRect(menu);
  _expectHorizontallyInside(menuRect, tileRect, reason: '$scenario 菜单越界');
  expect(
    menuRect.shortestSide,
    greaterThanOrEqualTo(minimumExtent),
    reason: '$scenario 更多菜单命中区不足',
  );
  await tester.tap(menu);
  await tester.pumpAndSettle();
  for (final label in const ['复制', '编辑', '删除']) {
    expect(
      find.text(label).hitTestable(),
      findsOneWidget,
      reason: '$scenario 菜单缺少 $label',
    );
  }
  await tester.tapAt(Offset.zero);
  await tester.pumpAndSettle();
}

void _expectHorizontallyInside(Rect inner, Rect outer, {String? reason}) {
  expect(inner.left, greaterThanOrEqualTo(outer.left - 0.01), reason: reason);
  expect(inner.right, lessThanOrEqualTo(outer.right + 0.01), reason: reason);
}

Future<void> _pumpSidebar(
  WidgetTester tester,
  _NarrowSidebarStorage storage, {
  required double width,
  required double textScale,
  required InteractionPolicy policy,
}) async {
  tester.view.physicalSize = Size(width, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _app(
      key: ValueKey('$width-$textScale-$policy-${storage.viewMode}'),
      storage: storage,
      policy: policy,
      textScale: textScale,
      child: SizedBox(
        width: width,
        height: 1400,
        child: const FixedTagsSidebar(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _app({
  Key? key,
  required _NarrowSidebarStorage storage,
  required InteractionPolicy policy,
  double textScale = 1,
  required Widget child,
}) {
  return ProviderScope(
    key: key,
    overrides: [localStorageServiceProvider.overrideWith((ref) => storage)],
    child: MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: true,
        ),
        child: child!,
      ),
      home: Scaffold(
        body: InteractionPolicyScope(initialPolicy: policy, child: child),
      ),
    ),
  );
}

class _NarrowSidebarStorage extends LocalStorageService {
  _NarrowSidebarStorage({this.viewMode = 'list', this.sidebarWidth = 320});

  static final _category = TagLibraryCategory.create(name: '分组', sortOrder: 0);

  static final _entries = [
    for (final type in FixedTagPromptType.values)
      for (var index = 0; index < 4; index++)
        FixedTagEntry.create(
          name: '${type.name} entry name $index',
          content: 'long content tag $index, another tag',
          enabled: index.isEven,
          promptType: type,
          categoryId: _category.id,
          sortOrder: index,
        ),
  ];

  String viewMode;
  final double sidebarWidth;
  double _negativeHeight = 260;
  String _linksJson = '[]';

  @override
  bool getFixedTagsSidebarExpanded() => true;

  @override
  double getFixedTagsSidebarWidth() => sidebarWidth;

  @override
  String getFixedTagsSidebarViewMode() => viewMode;

  @override
  Future<void> setFixedTagsSidebarViewMode(String mode) async {
    viewMode = mode;
  }

  @override
  double getFixedTagsNegativeHeight() => _negativeHeight;

  @override
  Future<void> setFixedTagsNegativeHeight(double height) async {
    _negativeHeight = height;
  }

  @override
  bool getFixedTagsNegativePanelExpanded() => true;

  @override
  String? getFixedTagsJson() =>
      jsonEncode(_entries.map((entry) => entry.toJson()).toList());

  @override
  Future<void> setFixedTagsJson(String json) async {}

  @override
  String? getFixedTagLinksJson() => _linksJson;

  @override
  Future<void> setFixedTagLinksJson(String json) async {
    _linksJson = json;
  }

  @override
  String? getTagLibraryEntriesJson() => '[]';

  @override
  String? getTagLibraryCategoriesJson() => jsonEncode([_category.toJson()]);

  @override
  bool getEnableAutocomplete() => false;

  @override
  bool getHighlightEmphasis() => false;
}
