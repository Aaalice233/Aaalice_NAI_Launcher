import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/services/image_metadata_service.dart';
import 'package:nai_launcher/data/services/metadata/cache_manager.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/fixed_tags_provider.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/components/detail_metadata_panel.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/components/detail_thumbnail_bar.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/components/detail_top_bar.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/file_image_detail_data.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/image_detail_data.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/image_detail_viewer.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/fixed_tag_usage_fixture.dart';

const _tag = 'rabbit ears';
const _model = 'nai-diffusion-4-5-full';
const _metadata = NaiImageMetadata(prompt: '1girl, $_tag', model: _model);
const _waitLimit = ImageDetailViewer.metadataPrefetchWaitLimit;
// 真实读盘只验证结果在首帧前到位，时限远超读盘耗时；超时行为由 Completer 用例覆盖
const _realReadWaitLimit = Duration(seconds: 20);
// 非 Windows 平台路由有淡入淡出，等过它再断言
const _routeTransition = Duration(milliseconds: 300);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('元数据只在 L2 时，详情面板首帧即显示', (tester) async {
    await _useDesktopSurface(tester);
    const tag = 'silver hair';
    final service = ImageMetadataService();
    late Directory directory;
    late String path;
    await tester.runAsync(() async {
      directory = await Directory.systemTemp.createTemp('detail-l2-prefetch-');
      Hive.init(directory.path);
      await service.initialize();
      final file = File(p.join(directory.path, 'saved.png'));
      await file.writeAsBytes(await novelAiPngBytes('1girl, $tag'));
      path = file.path;
      expect((await service.getMetadata(path))?.prompt, contains(tag));
      MetadataCacheManager().clearMemory();
    });
    // 放行真实事件循环后标签翻译会去问 path_provider，桩成临时目录即可
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_pathProvider, (call) async => directory.path);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_pathProvider, null),
    );

    try {
      expect(service.getCached(path), isNull);
      final observer = _DetailRouteObserver();
      await tester.pumpWidget(_app(observers: [observer]));

      final context = tester.element(find.byType(Scaffold));
      await tester.runAsync(() async {
        unawaited(
          ImageDetailViewer.show(
            context,
            images: [FileImageDetailData(filePath: path)],
            prefetchWaitLimit: _realReadWaitLimit,
          ),
        );
        await observer.firstPush;
      });
      expect(observer.pushed, isTrue);

      // 路由首帧为 Hero 测量处于 offstage，面板已按这一帧的数据构建
      await tester.pump();

      expect(
        find.byType(DetailMetadataPanel, skipOffstage: false),
        findsOneWidget,
      );
      expect(find.textContaining(tag, skipOffstage: false), findsWidgets);

      await tester.pumpWidget(const SizedBox());
    } finally {
      await tester.runAsync(() async {
        service.clearMemoryCache();
        await Hive.close();
        await _deleteBestEffort(directory);
      });
    }
  });

  testWidgets('预取在时限内读完时等它读完再打开，首帧即有元数据', (tester) async {
    await _useDesktopSurface(tester);
    final read = Completer<NaiImageMetadata?>();
    final observer = _DetailRouteObserver();
    await _openViewer(tester, observer, [_imageReadingFrom(read)]);

    await tester.pump(_waitLimit ~/ 2);
    expect(observer.pushed, isFalse);

    read.complete(_metadata);
    await tester.pump();
    expect(observer.pushed, isTrue);

    // 路由首帧为 Hero 测量处于 offstage，面板已按这一帧的数据构建
    await tester.pump();

    expect(
      find.byType(DetailMetadataPanel, skipOffstage: false),
      findsOneWidget,
    );
    expect(_loadingText(), findsNothing);
    expect(find.textContaining(_tag, skipOffstage: false), findsWidgets);
    expect(_topBarModel(), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('预取超过时限时照常打开，读完后回填面板与顶栏', (tester) async {
    await _useDesktopSurface(tester);
    final read = Completer<NaiImageMetadata?>();
    final observer = _DetailRouteObserver();
    await _openViewer(tester, observer, [_imageReadingFrom(read)]);

    await tester.pump(_waitLimit - const Duration(milliseconds: 1));
    expect(observer.pushed, isFalse);
    await tester.pump(const Duration(milliseconds: 1));
    expect(observer.pushed, isTrue);
    await tester.pump(_routeTransition);

    expect(_loadingText(), findsOneWidget);
    expect(find.textContaining(_tag, skipOffstage: false), findsNothing);
    expect(_topBarModel(), findsNothing);

    read.complete(_metadata);
    await tester.pump();

    expect(_loadingText(), findsNothing);
    expect(find.textContaining(_tag, skipOffstage: false), findsWidgets);
    expect(_topBarModel(), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('预取读完前关闭详情页，读完后不报错也不回写', (tester) async {
    await _useDesktopSurface(tester);
    final read = Completer<NaiImageMetadata?>();
    final observer = _DetailRouteObserver();
    await _openViewer(tester, observer, [_imageReadingFrom(read)]);
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));

    await tester.pump(_waitLimit);
    await tester.pump(_routeTransition);
    expect(find.byType(ImageDetailViewer), findsOneWidget);
    expect(_loadingText(), findsOneWidget);

    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.byType(ImageDetailViewer, skipOffstage: false), findsNothing);

    read.complete(_metadata);
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(observer.pushes, 1);
    expect(find.byType(ImageDetailViewer, skipOffstage: false), findsNothing);
    expect(find.textContaining(_tag, skipOffstage: false), findsNothing);
  });

  testWidgets('缩略图跳转等待预取时又切到别的页，旧的跳转作废', (tester) async {
    await _useDesktopSurface(tester);
    final slowRead = Completer<NaiImageMetadata?>();
    final images = [
      FileImageDetailData(
        filePath: _neverCreatedPath('first'),
        initialMetadata: _metadata,
      ),
      FileImageDetailData(
        filePath: _neverCreatedPath('second'),
        readCachedMetadata: (_) async => _metadata,
      ),
      FileImageDetailData(
        filePath: _neverCreatedPath('third'),
        readCachedMetadata: (_) => slowRead.future,
      ),
    ];
    await tester.pumpWidget(_app(home: ImageDetailViewer(images: images)));
    await tester.pump();
    expect(_topBarIndex('1 / 3'), findsOneWidget);

    await tester.tap(_thumbnailOf(images[2]));
    await tester.pump();
    await tester.tap(_thumbnailOf(images[1]));
    await tester.pump();
    expect(_topBarIndex('2 / 3'), findsOneWidget);

    await tester.pump(_waitLimit);
    expect(_topBarIndex('2 / 3'), findsOneWidget);

    slowRead.complete(null);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('缩略图跳转等待预取时滑动换页，旧的跳转作废', (tester) async {
    await _useDesktopSurface(tester);
    final slowRead = Completer<NaiImageMetadata?>();
    final images = [
      FileImageDetailData(
        filePath: _neverCreatedPath('first'),
        initialMetadata: _metadata,
      ),
      FileImageDetailData(
        filePath: _neverCreatedPath('second'),
        initialMetadata: _metadata,
      ),
      FileImageDetailData(
        filePath: _neverCreatedPath('third'),
        readCachedMetadata: (_) => slowRead.future,
      ),
    ];
    await tester.pumpWidget(_app(home: ImageDetailViewer(images: images)));
    await tester.pump();

    await tester.tap(_thumbnailOf(images[2]));
    await tester.pump();
    // 滑动在等待时限内完成；fling 按距离与速度推进假时钟
    await tester.fling(find.byType(PageView), const Offset(-500, 0), 5000);
    await tester.pump();
    expect(_topBarIndex('2 / 3'), findsOneWidget);

    await tester.pump(_waitLimit);
    await tester.pump(const Duration(seconds: 1));
    expect(_topBarIndex('2 / 3'), findsOneWidget);

    slowRead.complete(null);
    await tester.pumpWidget(const SizedBox());
  });
}

const _pathProvider = MethodChannel('plugins.flutter.io/path_provider');

Future<void> _useDesktopSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1200, 800));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

String _neverCreatedPath(String name) =>
    p.join(Directory.systemTemp.path, 'detail_prefetch_never_created_$name.png');

FileImageDetailData _imageReadingFrom(Completer<NaiImageMetadata?> read) {
  return FileImageDetailData(
    filePath: _neverCreatedPath('pending'),
    readCachedMetadata: (_) => read.future,
  );
}

Future<void> _openViewer(
  WidgetTester tester,
  NavigatorObserver observer,
  List<ImageDetailData> images,
) async {
  await tester.pumpWidget(_app(observers: [observer]));
  unawaited(
    ImageDetailViewer.show(
      tester.element(find.byType(Scaffold)),
      images: images,
    ),
  );
}

Finder _loadingText() => find.text(
  lookupAppLocalizations(const Locale('en')).detail_parsingMetadata,
  skipOffstage: false,
);

Finder _topBarModel() => _inTopBar(find.text(_model, skipOffstage: false));

Finder _topBarIndex(String label) =>
    _inTopBar(find.text(label, skipOffstage: false));

Finder _inTopBar(Finder matching) => find.descendant(
  of: find.byType(DetailTopBar, skipOffstage: false),
  matching: matching,
  skipOffstage: false,
);

Finder _thumbnailOf(ImageDetailData image) => find.descendant(
  of: find.byType(DetailThumbnailBar),
  matching: find.byKey(ValueKey(image.identifier)),
);

// 图片读取可能在 fake async 结束后才释放句柄，清理尽力而为
Future<void> _deleteBestEffort(Directory directory) async {
  for (var attempt = 0; attempt < 10; attempt++) {
    try {
      if (directory.existsSync()) await directory.delete(recursive: true);
      return;
    } on FileSystemException {
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
  }
}

Widget _app({
  List<NavigatorObserver> observers = const [],
  Widget home = const Scaffold(body: SizedBox.shrink()),
}) {
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
      navigatorObservers: observers,
      home: home,
    ),
  );
}

class _DetailRouteObserver extends NavigatorObserver {
  // 等待方在 runAsync 的真实 zone；异步 Completer 生于 fake zone，通知会卡在永不冲刷的微任务队列
  final _firstPush = Completer<void>.sync();
  int pushes = 0;

  bool get pushed => pushes > 0;

  Future<void> get firstPush => _firstPush.future;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PageRouteBuilder) return;
    pushes++;
    if (!_firstPush.isCompleted) _firstPush.complete();
  }
}

class _FakeShortcutConfigNotifier extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() async => ShortcutConfig.createDefault();
}

class _EmptyFixedTagsNotifier extends FixedTagsNotifier {
  @override
  FixedTagsState build() => const FixedTagsState();
}
