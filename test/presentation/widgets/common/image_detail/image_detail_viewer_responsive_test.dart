import 'dart:convert';
import 'dart:io';

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
import 'package:nai_launcher/presentation/widgets/common/themed_confirm_dialog.dart';
import 'package:nai_launcher/presentation/widgets/shortcuts/shortcut_aware_widget.dart';
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

  for (final menu in ['右键菜单', '窄屏更多菜单']) {
    testWidgets('翻页途中打开的$menu不能确认或删除下一张图', (tester) async {
      final contextMenu = menu == '右键菜单';
      await tester.binding.setSurfaceSize(Size(contextMenu ? 840 : 320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final dir = Directory.systemTemp.createTempSync('viewer_menu_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final files = {
        for (final name in ['a.png', 'b.png'])
          name: File('${dir.path}/$name')..writeAsBytesSync(_validPngBytes),
      };
      final confirmations = <String>[];
      await _pumpViewer(
        tester,
        images: [
          for (final name in files.keys) _TestImageData(name, _validPngBytes),
        ],
        callbacks: ImageDetailCallbacks(
          onDelete: (image) async {
            confirmations.add(image.identifier);
            if (await ThemedConfirmDialog.showDelete(
              context: tester.element(find.byType(ImageDetailViewer)),
              itemName: image.identifier,
            )) {
              files[image.identifier]!.deleteSync();
              return ImageDetailDeletePage([
                _TestImageData('a.png', _validPngBytes),
              ], previousPage: false);
            }
            return null;
          },
        ),
      );
      await tester.pumpAndSettle();
      final pageView = find.byType(PageView);
      final rightClick = contextMenu
          ? await tester.startGesture(
              tester.getCenter(pageView),
              kind: PointerDeviceKind.mouse,
              buttons: kSecondaryMouseButton,
            )
          : null;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final scroll = tester.widget<PageView>(pageView).controller!;
      expect(scroll.page, inExclusiveRange(0, 0.5));
      if (rightClick != null) {
        await rightClick.up();
      } else {
        await tester.tap(find.byIcon(Icons.more_vert));
      }
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      expect(find.text('Delete'), findsOneWidget);
      expect(scroll.page, inExclusiveRange(0, 0.5));
      await tester.pumpAndSettle();
      expect(scroll.page, 1);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(confirmations, isEmpty);
      expect(find.byType(ThemedConfirmDialog), findsNothing);
      expect(files.values.every((file) => file.existsSync()), isTrue);
      if (contextMenu) {
        await tester.tap(
          pageView,
          kind: PointerDeviceKind.mouse,
          buttons: kSecondaryMouseButton,
        );
      } else {
        await tester.tap(find.byIcon(Icons.more_vert));
      }
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.textContaining('b.png'), findsOneWidget);
      expect(confirmations, ['b.png']);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(files['b.png']!.existsSync(), isFalse);
      expect(files['a.png']!.existsSync(), isTrue);
    });
  }

  for (final entry in ['toolbar', 'menu', 'shortcut', 'right click']) {
    testWidgets('$entry only confirms once for the displayed image', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(
        Size(entry == 'menu' ? 320 : 840, 700),
      );
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final targets = <String>[];
      await _pumpViewer(
        tester,
        images: [
          for (final id in ['one', 'two']) _TestImageData(id, _validPngBytes),
        ],
        callbacks: ImageDetailCallbacks(
          onDelete: (image) async {
            targets.add(image.identifier);
            await ThemedConfirmDialog.showDelete(
              context: tester.element(find.byType(ImageDetailViewer)),
              itemName: image.identifier,
            );
            return null;
          },
        ),
      );
      await _press(tester, LogicalKeyboardKey.end);
      switch (entry) {
        case 'toolbar':
          await tester.tap(find.byTooltip('Delete'));
        case 'menu':
          await tester.tap(find.byIcon(Icons.more_vert));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Delete'));
        case 'right click':
          await tester.tap(
            find.byType(PageView),
            kind: PointerDeviceKind.mouse,
            buttons: kSecondaryMouseButton,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Delete'));
        default:
          await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      }
      await tester.pumpAndSettle();
      await _press(tester, LogicalKeyboardKey.delete);
      expect(targets, ['two']);
      expect(find.textContaining('two'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
    });
  }

  for (final (width, height, scale) in [
    (320.0, 700.0, 3.0),
    (600.0, 320.0, 1.0),
    (840.0, 700.0, 1.0),
    (1180.0, 700.0, 1.0),
    (1600.0, 700.0, 1.0),
  ]) {
    testWidgets(
      'deletion target remains reachable at $width × $height, text $scale',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, height));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        const colors = ColorScheme.dark(error: Color(0xFFF9DEDC));
        await _pumpViewer(
          tester,
          theme: ThemeData(colorScheme: colors),
          images: [_TestImageData('image', _validPngBytes)],
          callbacks: ImageDetailCallbacks(
            onDelete: (_) async => null,
            onSave: (_) async {},
            onSendToImg2Img: (_, closeViewer) async {},
          ),
          textScaler: TextScaler.linear(scale),
        );
        await tester.pump();
        Finder target;
        if (width < 720) {
          expect(find.byTooltip('Delete'), findsNothing);
          await tester.tap(find.byIcon(Icons.more_vert));
          await tester.pumpAndSettle();
          final label = find.text('Delete');
          final icon = find.byIcon(Icons.delete_outline);
          target = find.ancestor(
            of: label,
            matching: find.byWidgetPredicate(
              (widget) => widget is PopupMenuItem,
            ),
          );
          await tester.ensureVisible(target);
          expect(find.byType(PopupMenuDivider), findsOneWidget);
          expect(tester.widget<Text>(label).style?.color, colors.error);
          expect(IconTheme.of(tester.element(icon)).color, colors.error);
        } else {
          target = find.byTooltip('Delete');
          expect(
            tester.widget<Icon>(find.byIcon(Icons.delete_outline)).color,
            colors.error,
          );
        }
        expect(target.hitTestable(), findsOneWidget);
        expect(tester.getSize(target).shortestSide, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final mode in ['rebound', 'binding off', 'all off']) {
    testWidgets('viewer deletion follows $mode shortcut configuration', (
      tester,
    ) async {
      final defaults = ShortcutConfig.createDefault();
      var count = 0;
      await _pumpViewer(
        tester,
        images: [_TestImageData('image', _validPngBytes)],
        config: switch (mode) {
          'rebound' => defaults.setCustomShortcut(
            ShortcutIds.deleteImage,
            'ctrl+d',
          ),
          'binding off' => defaults.setEnabled(ShortcutIds.deleteImage, false),
          _ => defaults.copyWith(enableShortcuts: false),
        },
        callbacks: ImageDetailCallbacks(
          onDelete: (_) async {
            count++;
            return null;
          },
        ),
      );
      await tester.pump();
      await _press(tester, LogicalKeyboardKey.delete);
      expect(count, 0);
      await _press(tester, LogicalKeyboardKey.keyD, control: true);
      expect(count, mode == 'rebound' ? 1 : 0);
    });
  }

  testWidgets(
    'a viewer without delete capability has no binding, menu action or button',
    (tester) async {
      final image = _TestImageData('other-source', _validPngBytes);
      for (final width in [840.0, 320.0]) {
        await tester.binding.setSurfaceSize(Size(width, 700));
        await _pumpViewer(
          tester,
          images: [image],
          callbacks: ImageDetailCallbacks(onSave: (_) async {}),
        );
        await tester.pump();
        expect(
          tester.widget<PageShortcuts>(find.byType(PageShortcuts)).shortcuts,
          isNot(contains(ShortcutIds.deleteImage)),
        );
        await _press(tester, LogicalKeyboardKey.delete);
        expect(find.byIcon(Icons.delete_outline), findsNothing);
        if (width == 320) {
          await tester.tap(find.byIcon(Icons.more_vert));
          await tester.pumpAndSettle();
          expect(find.text('Delete'), findsNothing);
        }
      }
      await tester.binding.setSurfaceSize(null);
    },
  );

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
  ThemeData? theme,
}) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        shortcutConfigNotifierProvider.overrideWith(
          () => _FakeShortcutConfigNotifier(config),
        ),
      ],
      child: MaterialApp(
        theme: theme,
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
