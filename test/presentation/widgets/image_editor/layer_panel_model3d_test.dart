import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart'
    show
        InAppWebViewPlatform,
        PlatformInAppWebViewController,
        PlatformInAppWebViewWidget,
        PlatformInAppWebViewWidgetCreationParams;
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/layers/model3d_layer_data.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/widgets/panels/layer_panel.dart';
import 'package:nai_launcher/presentation/widgets/model3d_editor/model3d_editor_screen.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 记录 push 事件的观察器(断言 3D 编辑器路由确实被推入)
class _RecordingNavigatorObserver extends NavigatorObserver {
  final List<Route<dynamic>> pushed = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushed.add(route);
    super.didPush(route, previousRoute);
  }
}

class _TestPathProviderPlatform extends PathProviderPlatform {
  _TestPathProviderPlatform(this.appSupportPath);

  final String appSupportPath;

  @override
  Future<String?> getApplicationSupportPath() async => appSupportPath;
}

/// 最小 InAppWebView 平台桩:被推入的 Model3dEditorScreen 在本地
/// 资产服务就绪后会真实构建 InAppWebView,测试里渲染为空盒即可。
/// 未覆盖的工厂(含 WebViewEnvironment 静态查询)保持默认
/// UnimplementedError,恰好驱动 _ensureWebView2Available 的兜底分支。
class _StubInAppWebViewPlatform extends InAppWebViewPlatform {
  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) =>
      _StubInAppWebViewWidget(params);
}

class _StubInAppWebViewWidget extends PlatformInAppWebViewWidget {
  _StubInAppWebViewWidget(super.params) : super.implementation();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();

  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) =>
      throw UnimplementedError();

  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // EditorState 构造时 ToolManager 会异步读取 SharedPreferences
    SharedPreferences.setMockInitialValues({});
    // 双击 3D 层会 push Model3dEditorScreen,其 initState 里
    // _defaultLibrary() 调 getApplicationSupportDirectory(),需 mock
    PathProviderPlatform.instance =
        _TestPathProviderPlatform(Directory.systemTemp.path);
    InAppWebViewPlatform.instance = _StubInAppWebViewPlatform();
  });

  /// 挂载图层面板:一个普通层 + 一个 3D 层(空图层即可,避免真实图像解码)
  Future<(EditorState, _RecordingNavigatorObserver)> pumpPanel(
    WidgetTester tester,
  ) async {
    final state = EditorState();
    addTearDown(state.dispose);

    state.layerManager.addLayer(name: 'Normal Layer');
    final layer3d = state.layerManager.addLayer(name: 'Pose Layer');
    layer3d.model3d = const Model3dLayerData(
      modelRef: 'builtin:mannequin',
      sceneState: {'version': 1},
    );

    final observer = _RecordingNavigatorObserver();
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        navigatorObservers: [observer],
        home: Scaffold(body: LayerPanel(state: state)),
      ),
    );
    // 消化 addLayer 触发的快照失效防抖计时器(100ms 一次性、回调为空)
    // 与缩略图批处理的 zero-delay 计时器,避免测试收尾报 pending timer
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump();
    observer.pushed.clear(); // 丢弃初始路由的 push 记录
    return (state, observer);
  }

  Future<void> doubleTapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text(text));
    await tester.pump();
    // 推进时钟,消化第二次点击的 kDoubleTapMinTime(40ms)倒计时计时器
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('header shows the add-3d-layer button', (tester) async {
    await pumpPanel(tester);

    expect(find.byIcon(Icons.view_in_ar), findsOneWidget);
    expect(find.byTooltip('Add 3D Model Layer'), findsOneWidget);
  });

  testWidgets('3D badge shows only on model3d layers', (tester) async {
    await pumpPanel(tester);

    // 两个图层中仅 3D 层显示角标
    expect(find.text('3D'), findsOneWidget);
    expect(find.text('Pose Layer'), findsOneWidget);
    expect(find.text('Normal Layer'), findsOneWidget);
    // 角标与 3D 层名字同处一个 tile 行
    final badgeRow = find.ancestor(
      of: find.text('3D'),
      matching: find.ancestor(
        of: find.text('Pose Layer'),
        matching: find.byType(Row),
      ),
    );
    expect(badgeRow, findsWidgets);
  });

  testWidgets(
      'double-tapping 3d layer name opens the editor instead of rename',
      (tester) async {
    final (_, observer) = await pumpPanel(tester);

    await doubleTapText(tester, 'Pose Layer');
    // _onEdit3dLayer 内有 await(WebView2 检查),多 pump 两帧让 push 发生
    await tester.pump();
    await tester.pump();

    // 重命名未激活
    expect(find.byType(ThemedInput), findsNothing);
    // 3D 编辑器路由已推入
    expect(observer.pushed, hasLength(1));
    expect(find.byType(Model3dEditorScreen), findsOneWidget);

    // 收尾:卸载整棵树,释放编辑器路由(其加载指示动画不会自然停止)
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('double-tapping normal layer name still opens rename',
      (tester) async {
    final (_, observer) = await pumpPanel(tester);

    await doubleTapText(tester, 'Normal Layer');
    await tester.pump();

    // 重命名激活,且没有推入任何路由
    expect(find.byType(ThemedInput), findsOneWidget);
    expect(observer.pushed, isEmpty);
    expect(find.byType(Model3dEditorScreen), findsNothing);

    // 收尾:卸载树,终止重命名输入框的光标闪烁计时器
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
