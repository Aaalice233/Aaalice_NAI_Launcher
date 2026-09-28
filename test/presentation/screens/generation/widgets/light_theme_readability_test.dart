import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/presentation/providers/comfyui/comfyui_provider.dart';
import 'package:nai_launcher/presentation/providers/generation/image_workflow_controller.dart';
import 'package:nai_launcher/presentation/providers/reverse_prompt_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/img2img_panel.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/precise_reference_panel.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/reverse_prompt_panel.dart';

import '../../../../helpers/light_theme_contrast.dart';

/// 生成页折叠面板的浅色主题可读性守卫。
///
/// 这些面板都基于 CollapsibleImagePanel：折叠且有图时内容盖在深色渐变上，
/// 白色文字合法；一旦展开，内容直接贴在 Card 表面，写死的白色就会在浅色
/// 主题下变成白底白字。每个用例都把面板展开、并尽量打开会额外渲染文案的
/// 分支，再断言没有近白色文字。
void main() {
  group('生成页面板浅色主题可读性', () {
    testWidgets('Img2ImgPanel（重绘）', (tester) async {
      final container = createStorageFreeContainer();
      addTearDown(container.dispose);

      final controller = container.read(
        imageWorkflowControllerProvider.notifier,
      );
      controller.replaceSourceImage(_testImageBytes);
      controller.enterInpaintMode();
      controller.setPanelExpanded(true);

      await pumpPanelInLightTheme(
        tester,
        container: container,
        panel: const Img2ImgPanel(),
      );

      expectNoUnreadableLightText(tester, panelName: 'Img2ImgPanel（重绘）');
    });

    testWidgets('Img2ImgPanel（增强）', (tester) async {
      final container = createStorageFreeContainer();
      addTearDown(container.dispose);

      final controller = container.read(
        imageWorkflowControllerProvider.notifier,
      );
      controller.replaceSourceImage(_testImageBytes);
      controller.enterEnhanceMode();
      controller.toggleEnhanceIndividualSettings(true);
      controller.setPanelExpanded(true);

      await pumpPanelInLightTheme(
        tester,
        container: container,
        panel: const Img2ImgPanel(),
      );

      expectNoUnreadableLightText(tester, panelName: 'Img2ImgPanel（增强）');
    });

    testWidgets('Img2ImgPanel（放大）', (tester) async {
      // 打开 ComfyUI 才会渲染放大模块选择、模型下拉与各项提示文案，
      // 那里集中了原先写死的白色标签。
      final container = createStorageFreeContainer(
        overrides: [
          comfyUISettingsProvider.overrideWith(_EnabledComfyUISettings.new),
          comfyUISeedvr2ModelsProvider.overrideWith(
            _FixedComfyUIUpscaleModels.new,
          ),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(
        imageWorkflowControllerProvider.notifier,
      );
      controller.replaceSourceImage(_testImageBytes);
      controller.enterUpscaleMode();
      controller.updateSeedvr2Tiled(true);
      controller.setPanelExpanded(true);

      await pumpPanelInLightTheme(
        tester,
        container: container,
        panel: const Img2ImgPanel(),
      );

      expectNoUnreadableLightText(tester, panelName: 'Img2ImgPanel（放大）');
    });

    testWidgets('Img2ImgPanel（空状态）', (tester) async {
      final container = createStorageFreeContainer();
      addTearDown(container.dispose);

      container
          .read(imageWorkflowControllerProvider.notifier)
          .setPanelExpanded(true);

      await pumpPanelInLightTheme(
        tester,
        container: container,
        panel: const Img2ImgPanel(),
      );

      expectNoUnreadableLightText(tester, panelName: 'Img2ImgPanel（空状态）');
    });

    testWidgets('ReversePromptPanel（展开并打开各处理链）', (tester) async {
      final container = createStorageFreeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(reversePromptProvider.notifier);
      // 打开这两个开关才会渲染 taggerFilterHint / replacementEmptyHint，
      // 它们正是此前写死 Colors.white70 的位置。
      await notifier.setUseOnnxTagger(true);
      await notifier.setUseCharacterReplace(true);

      await pumpPanelInLightTheme(
        tester,
        container: container,
        panel: const ReversePromptPanel(),
      );

      // 面板默认折叠，点开标题展开内容区。
      await tester.tap(find.text('反推'));
      await tester.pumpAndSettle();

      expectNoUnreadableLightText(tester, panelName: 'ReversePromptPanel');
    });

    testWidgets('PreciseReferencePanel（展开）', (tester) async {
      final container = createStorageFreeContainer();
      addTearDown(container.dispose);

      await pumpPanelInLightTheme(
        tester,
        container: container,
        panel: const PreciseReferencePanel(),
      );

      expectNoUnreadableLightText(tester, panelName: 'PreciseReferencePanel');
    });

    // UnifiedReferencePanel（Vibe Transfer）未纳入：它在构建时会拉起 Vibe
    // 库的存储与预编码链，widget test 中 pumpAndSettle 无法收敛（实测 >2
    // 分钟仍未完成）。其内容组件 vibe_transfer_content.dart 里的白色已人工
    // 核验，全部由 showBackground 条件门控，只在深色遮罩上生效，不受此类
    // 问题影响。
  });
}

final Uint8List _testImageBytes = Uint8List.fromList(
  img.encodePng(img.Image(width: 8, height: 8)),
);

class _EnabledComfyUISettings extends ComfyUISettings {
  @override
  ComfyUISettingsState build() {
    return const ComfyUISettingsState(enabled: true);
  }
}

class _FixedComfyUIUpscaleModels extends ComfyUISeedvr2Models {
  @override
  List<String> build() {
    return const ['seedvr2_ema_7b_fp16.safetensors', '4x-UltraSharpV2.pth'];
  }

  @override
  Future<void> fetch({bool force = false}) async {}
}
