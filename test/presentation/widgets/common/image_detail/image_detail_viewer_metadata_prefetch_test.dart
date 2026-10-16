import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/data/services/image_metadata_service.dart';
import 'package:nai_launcher/data/services/metadata/cache_manager.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/fixed_tags_provider.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/components/detail_metadata_panel.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/file_image_detail_data.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/image_detail_viewer.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/fixed_tag_usage_fixture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('元数据只在 L2 时，详情面板首帧即显示', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
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
      await tester.pumpWidget(_app(observer));

      final context = tester.element(find.byType(Scaffold));
      await tester.runAsync(() async {
        unawaited(
          ImageDetailViewer.show(
            context,
            images: [FileImageDetailData(filePath: path)],
          ),
        );
        for (var attempt = 0; attempt < 100 && !observer.pushed; attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
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
}

const _pathProvider = MethodChannel('plugins.flutter.io/path_provider');

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

Widget _app(NavigatorObserver observer) {
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
      navigatorObservers: [observer],
      home: const Scaffold(body: SizedBox.shrink()),
    ),
  );
}

class _DetailRouteObserver extends NavigatorObserver {
  bool pushed = false;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRouteBuilder) pushed = true;
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
