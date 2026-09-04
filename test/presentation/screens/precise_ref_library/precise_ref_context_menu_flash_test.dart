// 回归：精准参考库右键菜单必须在抬起后打开且不扰动指针设备检测器；
// 设备类型翻转重建卡片时，缩略图内存缓存保证首帧不闪占位符。
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/precise_ref/precise_ref_library_entry.dart';
import 'package:nai_launcher/data/services/precise_ref_library_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/precise_ref_library_provider.dart';
import 'package:nai_launcher/presentation/screens/precise_ref_library/precise_ref_library_screen.dart';
import 'package:nai_launcher/presentation/screens/precise_ref_library/widgets/precise_ref_card.dart';
import 'package:super_native_extensions/raw_drag_drop.dart' as raw;

const List<int> _kTransparentPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82, //
];

class _ProbeStorage extends PreciseRefLibraryStorageService {
  final List<String> thumbnailFetches = <String>[];
  final Map<String, Uint8List> _memory = {};

  @override
  Uint8List? peekDisplayThumbnail(String id) => _memory[id];

  @override
  Future<Uint8List?> getDisplayThumbnail(
    String id, {
    bool Function()? isCancelled,
  }) async {
    thumbnailFetches.add(id);
    await Future<void>.delayed(const Duration(milliseconds: 1));
    final bytes = Uint8List.fromList(_kTransparentPng);
    _memory[id] = bytes;
    return bytes;
  }

  @override
  Future<Uint8List?> readImageBytes(String id) async => _memory[id];
}

class _ProbeNotifier extends PreciseRefLibraryNotifier {
  _ProbeNotifier(this._entries);

  final List<PreciseRefLibraryEntry> _entries;

  @override
  PreciseRefLibraryState build() =>
      PreciseRefLibraryState(entries: _entries, filteredEntries: _entries);

  @override
  Future<void> initialize() async {}
}

Future<_ProbeStorage> _pumpLibrary(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1280, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final entries = [
    for (var i = 0; i < 3; i++)
      PreciseRefLibraryEntry(
        id: 'entry-$i',
        name: '参考 $i',
        imagePath: 'C:/probe/entry-$i.png',
        createdAt: DateTime(2026, 1, 1 + i),
      ),
  ];
  final storage = _ProbeStorage();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        preciseRefLibraryStorageServiceProvider.overrideWithValue(storage),
        preciseRefLibraryNotifierProvider.overrideWith(
          () => _ProbeNotifier(entries),
        ),
      ],
      child: const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: PreciseRefLibraryScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();

  // 先用一次鼠标点击把全局设备检测器归一到 mouse（空白区域，不命中卡片）
  await tester.tapAt(const Offset(1200, 760), kind: PointerDeviceKind.mouse);
  await tester.pumpAndSettle();
  return storage;
}

void main() {
  testWidgets('右键菜单在抬起后打开且不触发指针设备类型翻转', (tester) async {
    final storage = await _pumpLibrary(tester);
    final detector = raw.PointerDeviceKindDetector.instance.current;
    expect(detector.value, PointerDeviceKind.mouse);

    final kindChanges = <PointerDeviceKind>[];
    void onKindChanged() => kindChanges.add(detector.value);
    detector.addListener(onKindChanged);
    addTearDown(() => detector.removeListener(onKindChanged));

    final fetchesBefore = storage.thumbnailFetches.length;

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(PreciseRefCard).first),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryButton,
    );
    addTearDown(gesture.removePointer);
    await tester.pump(const Duration(milliseconds: 50));

    // 按住期间不得弹菜单：此时 push 会触发合成 touch 取消事件
    expect(find.byType(PopupMenuItem<bool>), findsNothing);

    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(PopupMenuItem<bool>), findsOneWidget);
    expect(kindChanges, isEmpty, reason: '弹菜单扰动了全局指针设备检测器');
    expect(storage.thumbnailFetches.length, fetchesBefore);

    // 关闭菜单，避免遗留路由
    await tester.tapAt(const Offset(1200, 760), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
  });

  testWidgets('设备类型翻转重建卡片时，内存缓存保证首帧仍有图', (tester) async {
    final storage = await _pumpLibrary(tester);
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
}
