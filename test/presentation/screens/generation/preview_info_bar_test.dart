import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/gallery/nai_image_metadata.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
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

Future<ProviderContainer> _pumpBar(
  WidgetTester tester,
  GeneratedImage image, {
  double? width,
}) async {
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWith((ref) => _FakeStorage()),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: PreviewInfoBar(image: image),
            ),
          ),
        ),
      ),
    ),
  );
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

    expect(
      container.read(generationParamsNotifierProvider).seed,
      isNot(seed),
    );

    await tester.tap(find.text('$seed'));
    await tester.pump();

    expect(container.read(generationParamsNotifierProvider).seed, seed);
  });

  testWidgets('元数据没有种子时不显示种子胶囊', (tester) async {
    await _pumpBar(tester, _image());

    expect(find.byIcon(Icons.eco_outlined), findsNothing);
    // 分辨率与设置入口仍然在
    expect(find.text('832'), findsOneWidget);
    expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
  });

  testWidgets('容器窄到放不下时收起分辨率胶囊', (tester) async {
    await _pumpBar(tester, _image(seed: 4201934405), width: 200);

    expect(find.text('832'), findsNothing);
    expect(find.text('1216'), findsNothing);
    // 设置入口与种子仍然可用
    expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
    expect(find.byIcon(Icons.eco_outlined), findsOneWidget);
  });

  testWidgets('齿轮弹出的浮层可切换透明底色档位', (tester) async {
    final container = await _pumpBar(tester, _image(seed: 1));

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('zh'));
    expect(find.text(l10n.generation_transparencyBackgroundTitle), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.generation_transparencyCheckerDark));
    await tester.pump();

    expect(
      container.read(previewTransparencyNotifierProvider),
      TransparencyBackgrounds.checkerDark,
    );
  });
}

/// 测试环境没有 Hive box，透明底色偏好走内存实现
class _FakeStorage extends LocalStorageService {
  String? style;

  @override
  String? getPreviewTransparencyBackground() => style;

  @override
  Future<void> setPreviewTransparencyBackground(String value) async {
    style = value;
  }
}
