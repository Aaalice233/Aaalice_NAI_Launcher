import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/preview_transparency_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/preview_info_bar.dart';
import 'package:nai_launcher/presentation/widgets/common/transparency_background.dart';

GeneratedImage _image({int? seed}) {
  return GeneratedImage(
    id: 'preview-info-bar',
    bytes: Uint8List(0),
    width: 832,
    height: 1216,
    metadata: seed == null ? null : NaiImageMetadata(seed: seed),
  );
}

/// 造一张带 NovelAI `Comment` 文本块的 PNG，模拟接口返回的生成结果
Uint8List _naiPngBytes({required int seed}) {
  final canvas = img.Image(width: 2, height: 2);
  img.fill(canvas, color: img.ColorRgb8(12, 34, 56));
  return UnifiedMetadataParser.embedTextChunkOnly(
    Uint8List.fromList(img.encodePng(canvas)),
    'Comment',
    jsonEncode({'prompt': '1girl', 'seed': seed, 'steps': 28}),
  );
}

Future<ProviderContainer> _pumpBar(
  WidgetTester tester,
  GeneratedImage image, {
  double? width,
  InteractionPolicy? interactionPolicy,
  String defaultModel = 'nai-diffusion-4-5-full',
}) async {
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWith(
        (ref) => _FakeStorage(defaultModel: defaultModel),
      ),
    ],
  );
  addTearDown(container.dispose);

  Widget home = Scaffold(
    body: Center(
      // 与 image_preview.dart 的用法一致：定宽容器 + 左对齐，
      // 信息条本身拿到的是松约束，宽度由内容决定
      child: SizedBox(
        width: width,
        child: Align(
          alignment: Alignment.centerLeft,
          child: PreviewInfoBar(image: image),
        ),
      ),
    ),
  );
  if (interactionPolicy != null) {
    home = InteractionPolicyScope(
      initialPolicy: interactionPolicy,
      child: home,
    );
  }

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
  // 种子来自异步解析的 PNG 元数据，先让 FutureProvider 落定
  await tester.pump();
  await tester.pump();
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('分辨率胶囊显示图片实际宽高', (tester) async {
    await _pumpBar(tester, _image(seed: 4201934405));

    expect(find.text('832'), findsOneWidget);
    expect(find.text('1216'), findsOneWidget);
  });

  testWidgets('点击种子胶囊把这张图的种子写回生成参数', (tester) async {
    const seed = 4201934405;
    final container = await _pumpBar(tester, _image(seed: seed));

    expect(container.read(generationParamsNotifierProvider).seed, isNot(seed));

    await tester.tap(find.text('$seed'));
    await tester.pump();

    expect(container.read(generationParamsNotifierProvider).seed, seed);
  });

  testWidgets('生成结果不带 metadata 时从 PNG 字节解析出种子', (tester) async {
    const seed = 1234567890;
    await _pumpBar(
      tester,
      GeneratedImage(
        id: 'seed-from-bytes',
        bytes: _naiPngBytes(seed: seed),
        width: 832,
        height: 1216,
      ),
    );

    expect(find.text('$seed'), findsOneWidget);
  });

  testWidgets('信息条按内容收窄，种子胶囊不会被拉满剩余宽度', (tester) async {
    await _pumpBar(tester, _image(seed: 4201934405), width: 600);

    expect(tester.getSize(find.byType(PreviewInfoBar)).width, lessThan(400));
  });

  testWidgets('元数据没有种子时不显示种子胶囊', (tester) async {
    await _pumpBar(tester, _image());

    expect(find.byIcon(Icons.eco_outlined), findsNothing);
    // 分辨率与透明底色入口仍然在
    expect(find.text('832'), findsOneWidget);
    expect(find.byType(TransparencyBackgroundIcon), findsOneWidget);
  });

  testWidgets('容器窄到放不下时收起分辨率胶囊', (tester) async {
    await _pumpBar(tester, _image(seed: 4201934405), width: 200);

    expect(find.text('832'), findsNothing);
    expect(find.text('1216'), findsNothing);
    // 透明底色入口与种子仍然可用
    expect(find.byType(TransparencyBackgroundIcon), findsOneWidget);
    expect(find.byIcon(Icons.eco_outlined), findsOneWidget);
  });

  testWidgets('触屏主预览在种子右侧显示透明背景开关', (tester) async {
    const seed = 2889740361;
    final container = await _pumpBar(
      tester,
      _image(seed: seed),
      width: 280,
      defaultModel: 'nai-diffusion-5-curated',
      interactionPolicy: const InteractionPolicy(
        modality: InteractionModality.touch,
        touchAvailable: true,
        precisePointerAvailable: false,
      ),
    );

    final toggle = find.byKey(
      const ValueKey('generation_preview_transparent_background_toggle'),
    );
    final seedText = find.text('$seed');

    expect(toggle, findsOneWidget);
    expect(find.text('透明背景'), findsOneWidget);
    expect(
      tester.getRect(toggle).left,
      greaterThanOrEqualTo(tester.getRect(seedText).right),
    );
    expect(
      tester.getRect(toggle).right,
      closeTo(tester.getRect(find.byType(PreviewInfoBar)).right, 0.01),
    );
    expect(tester.getSize(toggle).height, greaterThanOrEqualTo(48));

    await tester.tap(toggle);
    await tester.pump();
    expect(
      container.read(generationParamsNotifierProvider).transparentBackground,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('触屏窄预览优先完整显示种子和透明背景开关', (tester) async {
    const seed = 2889740361;
    await _pumpBar(
      tester,
      _image(seed: seed),
      width: 360,
      defaultModel: 'nai-diffusion-5-curated',
      interactionPolicy: const InteractionPolicy(
        modality: InteractionModality.touch,
        touchAvailable: true,
        precisePointerAvailable: false,
      ),
    );

    final bar = find.byType(PreviewInfoBar);
    final seedText = find.text('$seed');
    final toggle = find.byKey(
      const ValueKey('generation_preview_transparent_background_toggle'),
    );

    expect(find.text('832'), findsNothing);
    expect(find.text('1216'), findsNothing);
    expect(seedText, findsOneWidget);
    expect(toggle, findsOneWidget);
    expect(
      tester.getRect(seedText).right,
      lessThanOrEqualTo(tester.getRect(toggle).left),
    );
    expect(
      tester.getRect(seedText).right,
      lessThanOrEqualTo(tester.getRect(bar).right),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('不支持透明背景的模型不显示主预览开关', (tester) async {
    await _pumpBar(
      tester,
      _image(seed: 1),
      width: 280,
      interactionPolicy: const InteractionPolicy(
        modality: InteractionModality.touch,
        touchAvailable: true,
        precisePointerAvailable: false,
      ),
    );

    expect(
      find.byKey(
        const ValueKey('generation_preview_transparent_background_toggle'),
      ),
      findsNothing,
    );
  });

  testWidgets('棋盘格入口弹出的浮层可切换透明底色档位', (tester) async {
    final container = await _pumpBar(tester, _image(seed: 1));

    await tester.tap(find.byType(TransparencyBackgroundIcon));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    expect(
      find.text(l10n.generation_transparencyBackgroundTitle),
      findsOneWidget,
    );

    await tester.tap(find.byTooltip(l10n.generation_transparencyCheckerDark));
    await tester.pump();

    expect(
      container.read(previewTransparencyNotifierProvider),
      TransparencyBackgrounds.checkerDark,
    );
  });

  testWidgets('透明底色浮层展开自定义颜色时不会溢出', (tester) async {
    await _pumpBar(tester, _image(seed: 1));

    await tester.tap(find.byType(TransparencyBackgroundIcon));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    await tester.tap(find.byTooltip(l10n.generation_transparencyCustom));
    await tester.pumpAndSettle();

    final svPanel = find.byKey(const ValueKey('hsv-color-picker-sv-panel'));
    expect(svPanel, findsOneWidget);
    expect(tester.getSize(svPanel).height, lessThan(120));
    expect(tester.takeException(), isNull);
  });

  testWidgets('窄屏下透明底色浮层会改向展开并保持在视口内', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpBar(tester, _image(seed: 1), width: 200);

    await tester.tap(find.byType(TransparencyBackgroundIcon));
    await tester.pumpAndSettle();

    final panel = find.byKey(
      const ValueKey('generation_transparency_background_panel'),
    );
    final panelRect = tester.getRect(panel);

    expect(panel, findsOneWidget);
    expect(panelRect.left, greaterThanOrEqualTo(0));
    expect(panelRect.right, lessThanOrEqualTo(320));
  });
}

/// 测试环境没有 Hive box，透明底色偏好走内存实现
class _FakeStorage extends LocalStorageService {
  _FakeStorage({required this.defaultModel});

  final String defaultModel;
  String? style;
  bool transparentBackground = false;

  @override
  String getDefaultModel() => defaultModel;

  @override
  bool getLastTransparentBackground() => transparentBackground;

  @override
  Future<void> setLastTransparentBackground(bool value) async {
    transparentBackground = value;
  }

  @override
  String? getPreviewTransparencyBackground() => style;

  @override
  Future<void> setPreviewTransparencyBackground(String value) async {
    style = value;
  }
}
