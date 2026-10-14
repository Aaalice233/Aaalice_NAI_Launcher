import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/shortcuts/default_shortcuts.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/horizontal_resize_handle.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/components/detail_metadata_panel.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/components/detail_thumbnail_bar.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/image_detail_data.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/image_detail_viewer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'single image adapts from compact to wide metadata presentation',
    (tester) async {
      final image = _TestImageData('single', _validPngBytes);

      for (final width in [360.0, 700.0, 900.0, 1200.0, 1600.0]) {
        await tester.binding.setSurfaceSize(Size(width, 700));
        await _pumpViewer(tester, images: [image]);
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('1 / 1'), findsOneWidget, reason: 'width=$width');
        expect(find.byType(DetailThumbnailBar), findsNothing);
        expect(
          find.byType(DetailMetadataPanel),
          width >= 1100 ? findsOneWidget : findsNothing,
          reason: 'width=$width',
        );
        expect(tester.takeException(), isNull, reason: 'width=$width');
      }

      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets(
    'wide metadata panel can be resized without squeezing the image',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpViewer(
        tester,
        images: [
          GeneratedImageDetailData(
            imageBytes: _validPngBytes,
            metadata: const NaiImageMetadata(
              source: 'NovelAI Diffusion V4.5 Full',
              prompt: '1girl, detailed background',
              seed: 123456789,
              steps: 28,
              width: 1024,
              height: 1024,
            ),
          ),
        ],
      );
      await tester.pump(const Duration(milliseconds: 200));

      final panel = find.byType(DetailMetadataPanel);
      final handle = find.byKey(
        const ValueKey('image-detail-metadata-resize-handle'),
      );
      final initialPanelWidth = tester.getSize(panel).width;

      expect(handle, findsOneWidget);
      expect(tester.getSize(handle).width, ResizeHandle.defaultWidth);
      expect(initialPanelWidth, 420);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: tester.getCenter(handle));
      await mouse.down(tester.getCenter(handle));
      await mouse.moveBy(const Offset(-80, 0));
      await mouse.up();
      await tester.pump();

      expect(tester.getSize(panel).width, closeTo(500, 0.01));
      expect(tester.getTopLeft(panel).dx, greaterThanOrEqualTo(480 + 8));

      await mouse.down(tester.getCenter(handle));
      await mouse.moveBy(const Offset(240, 0));
      await mouse.up();
      await tester.pump();

      expect(tester.getSize(panel).width, 320);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('three-times text scale keeps metadata action reachable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpViewer(
      tester,
      images: [_TestImageData('scaled', _validPngBytes)],
      textScaler: const TextScaler.linear(3),
    );
    await tester.pump();

    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact metadata action opens the adaptive panel', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpViewer(
      tester,
      images: [_TestImageData('panel', _validPngBytes)],
      textScaler: const TextScaler.linear(3),
    );
    await tester.pump(const Duration(milliseconds: 50));

    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(DetailMetadataPanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('multiple images page with arrows, thumbnails, and keyboard', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(840, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final images = [
      _TestImageData('first', _validPngBytes),
      _TestImageData('second', _validPngBytes),
      _TestImageData('third', _validPngBytes),
    ];

    await _pumpViewer(tester, images: images);
    await tester.pump();

    expect(find.byType(DetailThumbnailBar), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.home);
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('焦点退回路由作用域后查看器按键仍然生效', (tester) async {
    await tester.binding.setSurfaceSize(const Size(840, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpViewer(
      tester,
      images: [
        _TestImageData('first', _validPngBytes),
        _TestImageData('second', _validPngBytes),
        _TestImageData('third', _validPngBytes),
      ],
    );
    await tester.pump();

    // 可选中文本点外部失焦时同样走这条路径
    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.end);
    await tester.pumpAndSettle();

    expect(find.text('3 / 3'), findsOneWidget);
  });

  testWidgets('failed image replaces loading state with explicit error', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpViewer(
      tester,
      images: [
        _TestImageData('broken', Uint8List.fromList([1, 2, 3])),
      ],
      showMetadataPanel: false,
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.broken_image), findsOneWidget);
    expect(find.text('Failed to load image'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('top-bar operations dispatch for the current page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(840, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final saved = <String>[];
    final images = [
      _TestImageData('one', _validPngBytes),
      _TestImageData('two', _validPngBytes),
    ];

    await _pumpViewer(
      tester,
      images: images,
      callbacks: ImageDetailCallbacks(
        onSave: (image) async {
          saved.add(image.identifier);
        },
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.save_alt));
    await tester.pump();

    expect(saved, ['two']);
  });

  testWidgets('close action returns to the previous route', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final image = _TestImageData('route', _validPngBytes);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          shortcutConfigNotifierProvider.overrideWith(
            _FakeShortcutConfigNotifier.new,
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => ImageDetailViewer.showSingle(
                  context,
                  image: image,
                  showMetadataPanel: false,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(ImageDetailViewer), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(ImageDetailViewer), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  group('查看器按键读取快捷键配置', () {
    List<ImageDetailData> threeImages() => [
      _TestImageData('first', _validPngBytes),
      _TestImageData('second', _validPngBytes),
      _TestImageData('third', _validPngBytes),
    ];

    Future<void> pumpThree(
      WidgetTester tester, {
      ShortcutConfig? config,
    }) async {
      await tester.binding.setSurfaceSize(const Size(840, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pumpViewer(tester, images: threeImages(), config: config);
      await tester.pump();
    }

    testWidgets('默认 ←/→ 翻页、Home/End 跳到首尾', (tester) async {
      await pumpThree(tester);

      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(find.text('2 / 3'), findsOneWidget);
      await _press(tester, LogicalKeyboardKey.arrowLeft);
      expect(find.text('1 / 3'), findsOneWidget);
      await _press(tester, LogicalKeyboardKey.end);
      expect(find.text('3 / 3'), findsOneWidget);
      await _press(tester, LogicalKeyboardKey.home);
      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('改绑翻页与首尾键后，原 ←/→/Home/End 不再翻页', (tester) async {
      await pumpThree(
        tester,
        config: ShortcutConfig.createDefault()
            .setCustomShortcut(ShortcutIds.previousImage, 'arrowup')
            .setCustomShortcut(ShortcutIds.nextImage, 'arrowdown')
            .setCustomShortcut(ShortcutIds.firstImage, 'ctrl+home')
            .setCustomShortcut(ShortcutIds.lastImage, 'ctrl+end'),
      );

      await _press(tester, LogicalKeyboardKey.arrowRight);
      await _press(tester, LogicalKeyboardKey.end);
      expect(find.text('1 / 3'), findsOneWidget);

      await _press(tester, LogicalKeyboardKey.arrowDown);
      expect(find.text('2 / 3'), findsOneWidget);
      await _press(tester, LogicalKeyboardKey.arrowLeft);
      await _press(tester, LogicalKeyboardKey.home);
      expect(find.text('2 / 3'), findsOneWidget);
      await _press(tester, LogicalKeyboardKey.arrowUp);
      expect(find.text('1 / 3'), findsOneWidget);

      await _press(tester, LogicalKeyboardKey.end, control: true);
      expect(find.text('3 / 3'), findsOneWidget);
      await _press(tester, LogicalKeyboardKey.home, control: true);
      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('单项禁用后对应按键不再处理', (tester) async {
      await pumpThree(
        tester,
        config: ShortcutConfig.createDefault()
            .setEnabled(ShortcutIds.nextImage, false)
            .setEnabled(ShortcutIds.lastImage, false),
      );

      await _press(tester, LogicalKeyboardKey.arrowRight);
      await _press(tester, LogicalKeyboardKey.end);
      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('快捷键总开关关闭后翻页与首尾键不处理', (tester) async {
      await pumpThree(
        tester,
        config: ShortcutConfig.createDefault().copyWith(enableShortcuts: false),
      );

      await _press(tester, LogicalKeyboardKey.arrowRight);
      await _press(tester, LogicalKeyboardKey.end);
      expect(find.text('1 / 3'), findsOneWidget);
    });

    testWidgets('默认 Esc 关闭查看器', (tester) async {
      await _pumpViewerRoute(
        tester,
        image: _TestImageData('route', _validPngBytes),
      );

      await _press(tester, LogicalKeyboardKey.escape);
      expect(find.byType(ImageDetailViewer), findsNothing);
    });

    testWidgets('改绑关闭键后 Esc 不再关闭，新键关闭', (tester) async {
      await _pumpViewerRoute(
        tester,
        image: _TestImageData('route', _validPngBytes),
        config: ShortcutConfig.createDefault().setCustomShortcut(
          ShortcutIds.closeViewer,
          'ctrl+w',
        ),
      );

      await _press(tester, LogicalKeyboardKey.escape);
      expect(find.byType(ImageDetailViewer), findsOneWidget);

      await _press(tester, LogicalKeyboardKey.keyW, control: true);
      expect(find.byType(ImageDetailViewer), findsNothing);
    });

    testWidgets('快捷键总开关关闭后 Esc 不关闭查看器', (tester) async {
      await _pumpViewerRoute(
        tester,
        image: _TestImageData('route', _validPngBytes),
        config: ShortcutConfig.createDefault().copyWith(enableShortcuts: false),
      );

      await _press(tester, LogicalKeyboardKey.escape);
      expect(find.byType(ImageDetailViewer), findsOneWidget);
    });
  });

  group('画面静止时关闭立即生效', () {
    testWidgets('按默认 Esc 立即关闭', (tester) async {
      await _pumpViewerRoute(
        tester,
        image: _TestImageData('route', _validPngBytes),
      );
      await _settleIdle(tester);

      await _press(tester, LogicalKeyboardKey.escape);
      expect(find.byType(ImageDetailViewer), findsNothing);
    });

    testWidgets('按改绑后的关闭键立即关闭', (tester) async {
      await _pumpViewerRoute(
        tester,
        image: _TestImageData('route', _validPngBytes),
        config: ShortcutConfig.createDefault().setCustomShortcut(
          ShortcutIds.closeViewer,
          'ctrl+w',
        ),
      );
      await _settleIdle(tester);

      await _press(tester, LogicalKeyboardKey.keyW, control: true);
      expect(find.byType(ImageDetailViewer), findsNothing);
    });

    testWidgets('点关闭按钮立即关闭', (tester) async {
      await _pumpViewerRoute(
        tester,
        image: _TestImageData('route', _validPngBytes),
      );
      await _settleIdle(tester);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      expect(find.byType(ImageDetailViewer), findsNothing);
    });
  });
}

// 首次按键会切换焦点高亮模式并顺带排帧，先按一次无关键把画面带到真正静止
Future<void> _settleIdle(WidgetTester tester) async {
  await _press(tester, LogicalKeyboardKey.keyQ);
  expect(find.byType(ImageDetailViewer), findsOneWidget);
  expect(tester.binding.hasScheduledFrame, isFalse);
}

Future<void> _press(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool control = false,
}) async {
  if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pumpAndSettle();
}

Future<void> _pumpViewerRoute(
  WidgetTester tester, {
  required ImageDetailData image,
  ShortcutConfig? config,
}) async {
  await tester.binding.setSurfaceSize(const Size(840, 700));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        shortcutConfigNotifierProvider.overrideWith(
          () => _FakeShortcutConfigNotifier(config),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => ImageDetailViewer.showSingle(
                context,
                image: image,
                showMetadataPanel: false,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  expect(find.byType(ImageDetailViewer), findsOneWidget);
}

Future<void> _pumpViewer(
  WidgetTester tester, {
  required List<ImageDetailData> images,
  ImageDetailCallbacks? callbacks,
  bool showMetadataPanel = true,
  TextScaler textScaler = TextScaler.noScaling,
  ShortcutConfig? config,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        shortcutConfigNotifierProvider.overrideWith(
          () => _FakeShortcutConfigNotifier(config),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: child!,
        ),
        home: ImageDetailViewer(
          images: images,
          callbacks: callbacks,
          showMetadataPanel: showMetadataPanel,
        ),
      ),
    ),
  );
}

final Uint8List _validPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

class _FakeShortcutConfigNotifier extends ShortcutConfigNotifier {
  _FakeShortcutConfigNotifier([this.config]);

  final ShortcutConfig? config;

  @override
  Future<ShortcutConfig> build() async =>
      config ?? ShortcutConfig.createDefault();
}

class _TestImageData extends ImageDetailData {
  _TestImageData(this.identifier, this.bytes);

  final Uint8List bytes;

  @override
  final String identifier;

  @override
  FileInfo? get fileInfo => null;

  @override
  ImageProvider<Object> getImageProvider() => MemoryImage(bytes);

  @override
  Future<Uint8List> getImageBytes() async => bytes;

  @override
  bool get isFavorite => false;

  @override
  NaiImageMetadata? get metadata => null;

  @override
  bool get preserveOriginalBytesOnSave => true;

  @override
  bool get showCopyButton => false;

  @override
  bool get showSaveAsButton => false;

  @override
  bool get showFavoriteButton => false;

  @override
  bool get showSaveButton => true;
}
