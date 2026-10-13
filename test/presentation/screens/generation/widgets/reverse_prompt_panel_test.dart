import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/services/local_onnx_model_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_panel_expansion_provider.dart';
import 'package:nai_launcher/presentation/providers/reverse_prompt_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/reverse_prompt_panel.dart';

import '../../../../helpers/labeled_rows_expectations.dart';
import '../../../../helpers/light_theme_contrast.dart';

void main() {
  testWidgets('删除最后一张反推图后隐藏图像数量徽标', (tester) async {
    final container = createStorageFreeContainer(
      overrides: [
        reversePromptProvider.overrideWith(_SeededReversePromptNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await pumpPanelInLightTheme(
      tester,
      container: container,
      panel: const ReversePromptPanel(),
    );

    expect(find.text('1 张'), findsOneWidget);

    await tester.tap(find.text('反推'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.text('待添加'), findsNothing);
    expect(find.text('1 张'), findsNothing);
    expect(find.text('保留的反推结果'), findsOneWidget);
  });

  testWidgets('本地模型列表跨重建复用，只在刷新时重新扫描目录', (tester) async {
    late _CountingTaggerModels models;
    final container = createStorageFreeContainer(
      overrides: [
        localOnnxModelServiceProvider.overrideWith(
          (ref) => models = _CountingTaggerModels(
            ref.read(localStorageServiceProvider),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(generationPanelExpansionProvider.notifier)
        .setExpanded(GenerationWorkbenchPanel.reversePrompt, true);
    await tester.binding.setSurfaceSize(const Size(600, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('zh'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: Scaffold(
            body: SingleChildScrollView(child: ReversePromptPanel()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.takeException();

    expect(models.scans, 1);

    final notifier = container.read(reversePromptProvider.notifier);
    for (final threshold in const [0.4, 0.45, 0.5]) {
      await notifier.setTaggerGeneralThreshold(threshold);
      await tester.pumpAndSettle();
    }
    expect(models.scans, 1);

    final refresh = find.byTooltip('刷新');
    expect(refresh, findsOneWidget);
    await tester.tap(refresh);
    await tester.pumpAndSettle();
    tester.takeException();

    expect(models.scans, 2);
  });

  for (final locale in const ['zh', 'ja', 'en']) {
    for (final width in labeledRowWidths) {
      for (final scale in labeledRowTextScales) {
        final scenario = '$locale ${width.toInt()} ${scale}x';
        testWidgets('$scenario 下阈值滑块标签完整且可达', (tester) async {
          final container = createStorageFreeContainer(
            overrides: [
              localOnnxModelServiceProvider.overrideWith(
                (ref) => _NoTaggerModels(ref.read(localStorageServiceProvider)),
              ),
            ],
          );
          addTearDown(container.dispose);
          await container
              .read(generationPanelExpansionProvider.notifier)
              .setExpanded(GenerationWorkbenchPanel.reversePrompt, true);
          await tester.binding.setSurfaceSize(Size(width, 1200));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                locale: Locale(locale),
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: const Scaffold(
                  body: SingleChildScrollView(child: ReversePromptPanel()),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          // 底部操作按钮行在窄屏大字号下的既有溢出不属于滑块行，行内越界由逐项边界断言覆盖
          tester.takeException();

          final l10n = lookupAppLocalizations(Locale(locale));
          await expectLabeledSliderRows(
            tester,
            labels: [
              l10n.reversePrompt_generalThreshold,
              l10n.reversePrompt_characterThreshold,
            ],
            labelsSingleLine: locale != 'en',
            readouts: const ['0.35'],
            reason: scenario,
          );
          tester.takeException();
        });
      }
    }
  }
}

class _NoTaggerModels extends LocalOnnxModelService {
  const _NoTaggerModels(super.storage);

  @override
  Future<List<LocalOnnxModelDescriptor>> scanTaggerModels() async => const [];
}

class _CountingTaggerModels extends LocalOnnxModelService {
  _CountingTaggerModels(super.storage);

  var scans = 0;

  @override
  Future<List<LocalOnnxModelDescriptor>> scanTaggerModels() async {
    scans++;
    return const [
      LocalOnnxModelDescriptor(
        name: 'wd-v1-4-convnext.onnx',
        path: 'models/wd-v1-4-convnext.onnx',
        kind: LocalOnnxModelKind.wd14Tagger,
      ),
    ];
  }
}

final Uint8List _testImageBytes = Uint8List.fromList(
  img.encodePng(img.Image(width: 8, height: 8)),
);

class _SeededReversePromptNotifier extends ReversePromptNotifier {
  _SeededReversePromptNotifier(super.ref) {
    state = ReversePromptState(
      images: [
        ReversePromptImage(
          id: 'test-image',
          bytes: _testImageBytes,
          name: 'test.png',
        ),
      ],
      finalPrompt: '保留的反推结果',
    );
  }
}
