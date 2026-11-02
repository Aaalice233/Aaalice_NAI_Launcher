import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/fixed_tags_provider.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/image_card_action.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/components/detail_image_page.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/components/detail_top_bar.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/file_image_detail_data.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/image_detail_data.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/image_detail_viewer.dart';
import 'package:nai_launcher/presentation/widgets/gallery/local_image_context_menu.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

const _metadata = NaiImageMetadata(prompt: '1girl', model: 'nai-diffusion-4-5');
final _l10n = lookupAppLocalizations(const Locale('en'));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    // 等图片读取失败时真实时间会流逝，元数据面板顺带触发的服务要找存储目录
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => Directory.systemTemp.path,
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          ),
    );
  });

  Future<void> useDesktopSurface(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  group('翻到相邻页', () {
    testWidgets('在本页最后一张继续向右，换成下一页并停在它的第一张', (tester) async {
      await useDesktopSurface(tester);
      var nextLoads = 0;
      final navigator = ImageDetailPageNavigator(
        hasMore: (forward) => forward,
        load: (forward) async {
          nextLoads++;
          return forward ? _images('next', 3) : null;
        },
      );
      await tester.pumpWidget(
        _app(
          ImageDetailViewer(
            images: _images('page1', 2),
            initialIndex: 1,
            pageNavigator: navigator,
          ),
        ),
      );
      await tester.pump();
      expect(_topBarIndex('2 / 2'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(nextLoads, 1);
      expect(_topBarIndex('1 / 3'), findsOneWidget);
      expect(find.byIcon(Icons.chevron_left), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('在本页第一张继续向左，换成上一页并停在它的最后一张', (tester) async {
      await useDesktopSurface(tester);
      final navigator = ImageDetailPageNavigator(
        hasMore: (forward) => !forward,
        load: (forward) async => forward ? null : _images('prev', 4),
      );
      await tester.pumpWidget(
        _app(
          ImageDetailViewer(
            images: _images('page2', 2),
            pageNavigator: navigator,
          ),
        ),
      );
      await tester.pump();
      expect(_topBarIndex('1 / 2'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(_topBarIndex('4 / 4'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('键盘 → 在最后一张换到下一页，← 在第一张换回上一页', (tester) async {
      await useDesktopSurface(tester);
      final navigator = ImageDetailPageNavigator(
        hasMore: (_) => true,
        load: (forward) async =>
            forward ? _images('next', 3) : _images('prev', 5),
      );
      await tester.pumpWidget(
        _app(
          ImageDetailViewer(
            images: _images('page', 2),
            initialIndex: 1,
            pageNavigator: navigator,
          ),
        ),
      );
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_topBarIndex('1 / 3'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_topBarIndex('5 / 5'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('没有相邻页时，头尾不出现继续翻页的按钮', (tester) async {
      await useDesktopSurface(tester);
      final navigator = ImageDetailPageNavigator(
        hasMore: (_) => false,
        load: (_) async => fail('不应加载'),
      );
      await tester.pumpWidget(
        _app(
          ImageDetailViewer(
            images: _images('only', 2),
            initialIndex: 1,
            pageNavigator: navigator,
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.byIcon(Icons.chevron_left), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('不传翻页接口时保持原行为：最后一张没有向右的按钮', (tester) async {
      await useDesktopSurface(tester);
      await tester.pumpWidget(
        _app(ImageDetailViewer(images: _images('plain', 2), initialIndex: 1)),
      );
      await tester.pump();

      expect(find.byIcon(Icons.chevron_right), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('加载期间重复点击只请求一次；加载失败时留在原地', (tester) async {
      await useDesktopSurface(tester);
      final load = Completer<List<ImageDetailData>?>();
      var loads = 0;
      final navigator = ImageDetailPageNavigator(
        hasMore: (forward) => forward,
        load: (_) {
          loads++;
          return load.future;
        },
      );
      await tester.pumpWidget(
        _app(
          ImageDetailViewer(
            images: _images('slow', 2),
            initialIndex: 1,
            pageNavigator: navigator,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      expect(loads, 1);

      load.complete(null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(_topBarIndex('2 / 2'), findsOneWidget);

      // 失败后可以再次尝试
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pump();
      expect(loads, 2);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('锁定缩放', () {
    testWidgets('只有一张图时不显示锁定按钮，多张图时显示并可切换', (tester) async {
      await useDesktopSurface(tester);
      await tester.pumpWidget(
        _app(ImageDetailViewer(images: _images('one', 1))),
      );
      await tester.pump();
      expect(find.byTooltip(_l10n.detail_lockZoom), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        _app(ImageDetailViewer(images: _images('two', 2))),
      );
      await tester.pump();
      expect(find.byTooltip(_l10n.detail_lockZoom), findsOneWidget);

      await tester.tap(find.byTooltip(_l10n.detail_lockZoom));
      await tester.pump();
      expect(find.byTooltip(_l10n.detail_unlockZoom), findsOneWidget);
      expect(find.byIcon(Icons.lock), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('锁定后切到下一张，缩放比例保持不变', (tester) async {
      await useDesktopSurface(tester);
      final images = _images('lock', 3);
      await tester.pumpWidget(_app(ImageDetailViewer(images: images)));
      await tester.pump();

      _controllerOf(tester, images[0]).value = Matrix4.diagonal3Values(2, 2, 1);
      await tester.tap(find.byTooltip(_l10n.detail_lockZoom));
      await tester.pump();

      await tester.tap(find.byIcon(Icons.chevron_right));
      await _settle(tester);

      expect(
        _controllerOf(tester, images[1]).value.getMaxScaleOnAxis(),
        closeTo(2, 0.001),
      );

      // 解除锁定后当前图保持现在的缩放，切图又回到适应窗口
      await tester.tap(find.byTooltip(_l10n.detail_unlockZoom));
      await tester.pump();
      expect(
        _controllerOf(tester, images[1]).value.getMaxScaleOnAxis(),
        closeTo(2, 0.001),
      );
      await tester.tap(find.byIcon(Icons.chevron_right));
      await _settle(tester);
      expect(
        _controllerOf(tester, images[2]).value.getMaxScaleOnAxis(),
        closeTo(1, 0.001),
      );

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('没有锁定时切图回到适应窗口', (tester) async {
      await useDesktopSurface(tester);
      final images = _images('free', 3);
      await tester.pumpWidget(_app(ImageDetailViewer(images: images)));
      await tester.pump();

      _controllerOf(tester, images[0]).value = Matrix4.diagonal3Values(2, 2, 1);
      await tester.tap(find.byIcon(Icons.chevron_right));
      await _settle(tester);

      expect(
        _controllerOf(tester, images[1]).value.getMaxScaleOnAxis(),
        closeTo(1, 0.001),
      );

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('加入相簿按钮', () {
    testWidgets('提供回调时出现在顶栏，点击对当前图片生效', (tester) async {
      await useDesktopSurface(tester);
      final images = _images('album', 2);
      final added = <ImageDetailData>[];
      await tester.pumpWidget(
        _app(
          ImageDetailViewer(
            images: images,
            initialIndex: 1,
            callbacks: ImageDetailCallbacks(
              onAddToAlbum: (image) async => added.add(image),
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byTooltip(_l10n.localGallery_addToAlbum));
      await tester.pump();

      expect(added, [images[1]]);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('没有回调时不显示', (tester) async {
      await useDesktopSurface(tester);
      await tester.pumpWidget(
        _app(ImageDetailViewer(images: _images('no', 2))),
      );
      await tester.pump();

      expect(find.byTooltip(_l10n.localGallery_addToAlbum), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });
  });

  group('右键菜单', () {
    testWidgets('放大后在图片上点右键也能弹出菜单，并可执行菜单项', (tester) async {
      await useDesktopSurface(tester);
      final images = _images('menu', 2);
      var invoked = 0;
      await tester.pumpWidget(
        _app(
          ImageDetailViewer(
            images: images,
            callbacks: ImageDetailCallbacks(
              contextMenuActions: (context, image) => [
                ImageCardAction(
                  id: ImageCardActionId.addToAlbum,
                  icon: Icons.photo_album_outlined,
                  label: 'Extra action',
                  invoke: () => invoked++,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      _controllerOf(tester, images[0]).value = Matrix4.diagonal3Values(3, 3, 1);
      // 图片文件不存在，等读取失败后加载中的遮罩才会撤掉
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await _settle(tester);

      await _rightClick(tester, tester.getCenter(find.byType(DetailImagePage)));
      await _settle(tester);

      expect(find.text('Extra action'), findsOneWidget);
      expect(find.text(_l10n.shortcut_action_copy_image), findsWidgets);

      await tester.tap(find.text('Extra action'));
      await _settle(tester);
      expect(invoked, 1);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('没有提供菜单项时右键不弹菜单', (tester) async {
      await useDesktopSurface(tester);
      await tester.pumpWidget(
        _app(ImageDetailViewer(images: _images('none', 2))),
      );
      await tester.pump();

      await _rightClick(tester, tester.getCenter(find.byType(DetailImagePage)));
      await _settle(tester);

      expect(find.text(_l10n.shortcut_action_copy_image), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('本地画廊的菜单里「加入相簿」紧跟在「移动到分类」后面', (tester) async {
      late List<ImageCardAction> actions;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              actions = LocalImageContextMenu.buildActions(
                context,
                onAction: (_) async {},
                hasImportableMetadata: true,
                hasPrompt: true,
                hasSeed: true,
                isKritaConnected: false,
              );
              return const SizedBox();
            },
          ),
        ),
      );

      final ids = actions.map((action) => action.id).toList();
      final classify = ids.indexOf(ImageCardActionId.classify);
      expect(classify, isNonNegative);
      expect(ids[classify + 1], ImageCardActionId.addToAlbum);
      expect(actions[classify + 1].label, _l10n.localGallery_addToAlbum);
    });

    testWidgets('只有在相簿里浏览时，菜单才有「移出相簿」，且紧跟在「加入相簿」后面', (tester) async {
      late List<ImageCardAction> inAlbum;
      late List<ImageCardAction> notInAlbum;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              List<ImageCardAction> build({required bool album}) =>
                  LocalImageContextMenu.buildActions(
                    context,
                    onAction: (_) async {},
                    hasImportableMetadata: true,
                    hasPrompt: true,
                    hasSeed: true,
                    isKritaConnected: false,
                    inAlbum: album,
                  );
              inAlbum = build(album: true);
              notInAlbum = build(album: false);
              return const SizedBox();
            },
          ),
        ),
      );

      final ids = inAlbum.map((action) => action.id).toList();
      expect(
        ids[ids.indexOf(ImageCardActionId.addToAlbum) + 1],
        ImageCardActionId.removeFromAlbum,
      );
      expect(
        notInAlbum.map((action) => action.id),
        isNot(contains(ImageCardActionId.removeFromAlbum)),
      );
    });
  });
}

Future<void> _rightClick(WidgetTester tester, Offset position) async {
  final gesture = await tester.startGesture(
    position,
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );
  await gesture.up();
}

// 图片读取失败的占位和元数据面板会一直有动画，pumpAndSettle 等不到静止
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

Finder _topBarIndex(String label) => find.descendant(
  of: find.byType(DetailTopBar, skipOffstage: false),
  matching: find.text(label, skipOffstage: false),
  skipOffstage: false,
);

TransformationController _controllerOf(
  WidgetTester tester,
  ImageDetailData image,
) {
  final viewer = find.descendant(
    of: find.byKey(ValueKey(image.identifier)),
    matching: find.byType(InteractiveViewer),
    skipOffstage: false,
  );
  return tester.widget<InteractiveViewer>(viewer).transformationController!;
}

List<ImageDetailData> _images(String prefix, int count) => [
  for (var i = 0; i < count; i++)
    FileImageDetailData(
      filePath: p.join(Directory.systemTemp.path, 'zoom_menu_${prefix}_$i.png'),
      initialMetadata: _metadata,
    ),
];

Widget _app(Widget home) {
  return ProviderScope(
    overrides: [
      shortcutConfigNotifierProvider.overrideWith(
        _FakeShortcutConfigNotifier.new,
      ),
      fixedTagsNotifierProvider.overrideWith(_EmptyFixedTagsNotifier.new),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

class _FakeShortcutConfigNotifier extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() async => ShortcutConfig.createDefault();
}

class _EmptyFixedTagsNotifier extends FixedTagsNotifier {
  @override
  FixedTagsState build() => const FixedTagsState();
}
