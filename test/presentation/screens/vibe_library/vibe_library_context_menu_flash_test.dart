// 回归：右键菜单必须在抬起后打开且不扰动指针设备检测器；
// 设备类型翻转重建卡片时，缩略图内存缓存保证首帧不闪占位符。
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_category.dart';
import 'package:nai_launcher/data/services/vibe_library_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/vibe_library_provider.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/widgets/vibe_card.dart';
import 'package:nai_launcher/presentation/screens/vibe_library/widgets/vibe_library_content_view.dart';
import 'package:nai_launcher/presentation/widgets/common/desktop_window_frame.dart';
import 'package:nai_launcher/presentation/widgets/common/pro_context_menu.dart';
import 'package:super_native_extensions/raw_drag_drop.dart' as raw;

const List<int> _kTransparentPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82, //
];

class _ProbeStorage extends VibeLibraryStorageService {
  final List<String> thumbnailFetches = <String>[];
  final Map<String, Uint8List> _memory = {};

  @override
  Future<List<VibeLibraryCategory>> getAllCategories() async => [];

  @override
  Uint8List? peekDisplayThumbnail(String id) => _memory[id];

  @override
  Future<Uint8List?> getDisplayThumbnail(String id) async {
    thumbnailFetches.add(id);
    await Future<void>.delayed(const Duration(milliseconds: 1));
    final bytes = Uint8List.fromList(_kTransparentPng);
    _memory[id] = bytes;
    return bytes;
  }

  @override
  Future<VibeLibraryDetailData?> getDetailData(String id) async => null;
}

class _ProbeNotifier extends VibeLibraryNotifier {
  _ProbeNotifier(this._entries);

  final List<VibeLibraryEntry> _entries;

  @override
  VibeLibraryState build() => VibeLibraryState(entries: _entries);

  @override
  Future<void> initialize() async {}
}

Future<_ProbeStorage> _pumpVibeGrid(
  WidgetTester tester, {
  Widget Function(Widget content)? shell,
}) async {
  await tester.binding.setSurfaceSize(const Size(1280, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final entries = [
    for (var i = 0; i < 3; i++)
      VibeLibraryEntry(
        id: 'vibe-$i',
        name: 'Vibe $i',
        vibeDisplayName: 'Vibe $i',
        vibeEncoding: 'encoding-$i',
        createdAt: DateTime(2026, 1, 1 + i),
      ),
  ];
  final storage = _ProbeStorage();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        vibeLibraryStorageServiceProvider.overrideWithValue(storage),
        vibeLibraryNotifierProvider.overrideWith(() => _ProbeNotifier(entries)),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: shell == null
              ? const VibeLibraryContentView(columns: 4, itemWidth: 280)
              : shell(const VibeLibraryContentView(columns: 4, itemWidth: 280)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // 先用一次鼠标点击把全局设备检测器归一到 mouse（空白区域，不命中卡片）
  await tester.tapAt(const Offset(1200, 760), kind: PointerDeviceKind.mouse);
  await tester.pumpAndSettle();
  return storage;
}

List<State> _cardStates(WidgetTester tester) => [
  for (final element in find.byType(VibeCard).evaluate())
    (element as StatefulElement).state,
];

void main() {
  testWidgets('右键菜单在抬起后打开且不触发指针设备类型翻转', (tester) async {
    final storage = await _pumpVibeGrid(tester);
    final detector = raw.PointerDeviceKindDetector.instance.current;
    expect(detector.value, PointerDeviceKind.mouse);

    final kindChanges = <PointerDeviceKind>[];
    void onKindChanged() => kindChanges.add(detector.value);
    detector.addListener(onKindChanged);
    addTearDown(() => detector.removeListener(onKindChanged));

    final statesBefore = _cardStates(tester);
    final fetchesBefore = storage.thumbnailFetches.length;

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(VibeCard).first),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryButton,
    );
    addTearDown(gesture.removePointer);
    await tester.pump(const Duration(milliseconds: 50));

    // 按住期间不得弹菜单：此时 push 会触发合成 touch 取消事件
    expect(find.byType(ProContextMenu), findsNothing);

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(ProContextMenu), findsOneWidget);
    expect(kindChanges, isEmpty, reason: '弹菜单扰动了全局指针设备检测器');

    final statesAfter = _cardStates(tester);
    expect(statesAfter.length, statesBefore.length);
    for (var i = 0; i < statesAfter.length; i++) {
      expect(
        identical(statesAfter[i], statesBefore[i]),
        isTrue,
        reason: '第 $i 张卡片 State 被重建',
      );
    }
    expect(storage.thumbnailFetches.length, fetchesBefore);

    // 点击空白关闭菜单，避免遗留路由
    await tester.tapAt(const Offset(1200, 760), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
  });

  testWidgets('设备类型翻转重建卡片时，内存缓存保证首帧仍有图', (tester) async {
    final storage = await _pumpVibeGrid(tester);
    final imagesBefore = find.byType(Image).evaluate().length;
    final fetchesBefore = storage.thumbnailFetches.length;
    expect(imagesBefore, 3);

    // 模拟输入设备切换：一次 touch 触点翻转全局检测器
    await tester.tapAt(const Offset(1200, 760), kind: PointerDeviceKind.touch);
    await tester.pump();

    expect(
      find.byType(Image).evaluate().length,
      imagesBefore,
      reason: '卡片重建后首帧丢失了缩略图（内存缓存未生效）',
    );
    expect(
      storage.thumbnailFetches.length,
      fetchesBefore,
      reason: '重建后未同步命中内存缓存，走了异步重读',
    );

    await tester.pumpAndSettle();
    expect(find.byType(Image).evaluate().length, imagesBefore);
  });

  testWidgets('壳层偏移 overlay 下 Vibe 卡片菜单出现在点击位置', (tester) async {
    // 生产壳层结构：真实 DesktopWindowFrame 提供 40px 自绘标题栏，
    // 内容区 Navigator 在 200px 主导航栏右侧。Vibe 卡片的自定义
    // _ContextMenuRoute 铺在该 Navigator 的 overlay 上，直接把手势
    // 窗口全局坐标当 overlay 局部坐标会让菜单偏移一个壳层边距。
    final storage = await _pumpVibeGrid(
      tester,
      shell: (content) => DesktopWindowFrame(
        enabled: true,
        child: Row(
          children: [
            const SizedBox(width: 200),
            Expanded(
              child: Navigator(
                onGenerateRoute: (_) =>
                    PageRouteBuilder(pageBuilder: (_, __, ___) => content),
              ),
            ),
          ],
        ),
      ),
    );
    expect(storage, isNotNull);

    final cardCenter = tester.getCenter(find.byType(VibeCard).first);
    final tapPosition = cardCenter - const Offset(60, 0);
    final gesture = await tester.startGesture(
      tapPosition,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryButton,
    );
    addTearDown(gesture.removePointer);
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.byType(ProContextMenu), findsOneWidget);
    final menuTopLeft = tester.getTopLeft(find.byType(ProContextMenu));
    expect((menuTopLeft - tapPosition).distance, lessThan(1.0));

    // 点击空白关闭菜单，避免遗留路由
    await tester.tapAt(const Offset(1200, 760), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
  });
}
