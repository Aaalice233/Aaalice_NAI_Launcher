import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../widgets/common/themed_divider.dart';
import '../../../../data/models/image/image_params.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../widgets/image_editor/image_editor_screen.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/image_picker_card/image_picker_card.dart';
import '../../../widgets/common/collapsible_image_panel.dart';

/// Img2Img 面板组件
class Img2ImgPanel extends ConsumerStatefulWidget {

  const Img2ImgPanel({super.key});

  @override
  ConsumerState<Img2ImgPanel> createState() => _Img2ImgPanelState();
}

class _Img2ImgPanelState extends ConsumerState<Img2ImgPanel> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final params = ref.watch(generationParamsNotifierProvider);
    final hasSourceImage = params.sourceImage != null;
    final showBackground = hasSourceImage && !_isExpanded;


    return CollapsibleImagePanel(
      title: context.l10n.img2img_title,
      icon: Icons.image,
      isExpanded: _isExpanded,
      onToggle: () => setState(() => _isExpanded = !_isExpanded),
      hasData: hasSourceImage,
      backgroundImage: hasSourceImage
          ? Image.memory(
              params.sourceImage!,
              fit: BoxFit.cover,
            )
          : null,
      badge: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: showBackground
              ? Colors.white.withOpacity(0.2)
              : theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          context.l10n.img2img_enabled,
          style: theme.textTheme.labelSmall?.copyWith(
            color: showBackground
                ? Colors.white
                : theme.colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ThemedDivider(),

            // 源图像选择
            _buildSourceImageSection(theme, params),

            if (hasSourceImage) ...[
              const SizedBox(height: 16),
              // 强度滑块
              _buildStrengthSlider(theme, params),
              const SizedBox(height: 12),
              // 噪声滑块
              _buildNoiseSlider(theme, params),
              const SizedBox(height: 12),
              // 清除按钮
              OutlinedButton.icon(
                onPressed: _clearImg2Img,
                icon: const Icon(Icons.clear, size: 18),
                label: Text(context.l10n.img2img_clearSettings),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }


  Widget _buildSourceImageSection(ThemeData theme, ImageParams params) {
    final hasSourceImage = params.sourceImage != null;
    final hasMask = params.maskImage != null;

    if (hasSourceImage) {
      // 有图片时：显示图片预览和操作按钮
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                context.l10n.img2img_sourceImage,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              // 编辑按钮
              _IconButton(
                icon: Icons.edit,
                onPressed: () => _openEditor(params.sourceImage!),
                tooltip: context.l10n.img2img_edit,
              ),
              const SizedBox(width: 8),
              _IconButton(
                icon: Icons.refresh,
                onPressed: _pickImage,
                tooltip: context.l10n.img2img_changeImage,
              ),
              const SizedBox(width: 8),
              // 上传遮罩按钮
              _IconButton(
                icon: hasMask ? Icons.check_circle : Icons.layers,
                onPressed: _pickMaskImage,
                tooltip: context.l10n.img2img_maskTooltip,
              ),
              const SizedBox(width: 8),
              _IconButton(
                icon: Icons.close,
                onPressed: _removeSourceImage,
                tooltip: context.l10n.img2img_removeImage,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // 图片预览
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AspectRatio(
              aspectRatio: 1,
              child: Image.memory(
                params.sourceImage!,
                fit: BoxFit.contain,
              ),
            ),
          ),
          // 状态指示器
          if (hasMask) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.orange.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check, size: 12, color: Colors.orange),
                  const SizedBox(width: 4),
                  Text(
                    context.l10n.img2img_maskEnabled,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.img2img_maskHelpText,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white70,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      );
    }

    // 无图片时：显示两个并列选项（上传图片 / 绘制草图）
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.img2img_sourceImage,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // 上传图片选项
            Expanded(
              child: ImagePickerCard(
                icon: Icons.upload_file,
                label: context.l10n.img2img_uploadImage,
                height: 80,
                onImageSelected: (bytes, fileName, path) {
                  ref
                      .read(generationParamsNotifierProvider.notifier)
                      .setSourceImage(bytes);
                  ref
                      .read(generationParamsNotifierProvider.notifier)
                      .updateAction(ImageGenerationAction.img2img);
                },
                onError: (error) {
                  AppToast.error(
                    context,
                    context.l10n.img2img_selectFailed(error),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            // 绘制草图选项
            Expanded(
              child: ImagePickerCard(
                icon: Icons.brush,
                label: context.l10n.img2img_drawSketch,
                height: 80,
                enableDragDrop: false,
                onTap: _openBlankCanvas,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStrengthSlider(ThemeData theme, ImageParams params) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              context.l10n.img2img_strength,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white,
              ),
            ),
            const Spacer(),
            Text(
              params.strength.toStringAsFixed(2),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
            overlayColor: Colors.white24,
          ),
          child: Slider(
            value: params.strength,
            min: 0.0,
            max: 1.0,
            divisions: 100,
            onChanged: (value) {
              ref
                  .read(generationParamsNotifierProvider.notifier)
                  .updateStrength(value);
            },
          ),
        ),
        Text(
          context.l10n.img2img_strengthHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildNoiseSlider(ThemeData theme, ImageParams params) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              context.l10n.img2img_noise,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.white,
              ),
            ),
            const Spacer(),
            Text(
              params.noise.toStringAsFixed(2),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.white,
            inactiveTrackColor: Colors.white24,
            thumbColor: Colors.white,
            overlayColor: Colors.white24,
          ),
          child: Slider(
            value: params.noise,
            min: 0.0,
            max: 1.0,
            divisions: 100,
            onChanged: (value) {
              ref
                  .read(generationParamsNotifierProvider.notifier)
                  .updateNoise(value);
            },
          ),
        ),
        Text(
          context.l10n.img2img_noiseHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        Uint8List? bytes;

        if (file.bytes != null) {
          bytes = file.bytes;
        } else if (file.path != null) {
          bytes = await File(file.path!).readAsBytes();
        }

        if (bytes != null) {
          ref
              .read(generationParamsNotifierProvider.notifier)
              .setSourceImage(bytes);
          ref
              .read(generationParamsNotifierProvider.notifier)
              .updateAction(ImageGenerationAction.img2img);
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context,
          context.l10n.img2img_selectFailed(e.toString()),
        );
      }
    }
  }

  Future<void> _pickMaskImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        Uint8List? bytes;

        if (file.bytes != null) {
          bytes = file.bytes;
        } else if (file.path != null) {
          bytes = await File(file.path!).readAsBytes();
        }

        if (bytes != null) {
          ref
              .read(generationParamsNotifierProvider.notifier)
              .setMaskImage(bytes);
          ref
              .read(generationParamsNotifierProvider.notifier)
              .updateAction(ImageGenerationAction.infill);
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context,
          context.l10n.img2img_selectFailed(e.toString()),
        );
      }
    }
  }

  void _removeSourceImage() {
    ref.read(generationParamsNotifierProvider.notifier).setSourceImage(null);
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updateAction(ImageGenerationAction.generate);
  }

  void _clearImg2Img() {
    ref.read(generationParamsNotifierProvider.notifier).clearImg2Img();
  }

  Future<void> _openEditor(Uint8List imageBytes) async {
    final params = ref.read(generationParamsNotifierProvider);

    final result = await ImageEditorScreen.show(
      context,
      initialImage: imageBytes,
      existingMask: params.maskImage,
      title: context.l10n.editor_title,
    );

    if (result != null && mounted) {
      final notifier = ref.read(generationParamsNotifierProvider.notifier);

      // 更新涂鸦后的图像
      if (result.hasImageChanges && result.modifiedImage != null) {
        notifier.setSourceImage(result.modifiedImage!);
      }

      // 更新遮罩
      if (result.hasMaskChanges) {
        if (result.maskImage != null) {
          notifier.setMaskImage(result.maskImage!);
          notifier.updateAction(ImageGenerationAction.infill);
        } else {
          notifier.setMaskImage(null);
          // 如果没有遮罩了，切回 img2img 模式
          notifier.updateAction(ImageGenerationAction.img2img);
        }
      }
    }
  }

  /// 打开空白画布进行绘制
  Future<void> _openBlankCanvas() async {
    final params = ref.read(generationParamsNotifierProvider);

    // 获取画布尺寸（与生成参数一致）
    final canvasSize = Size(
      params.width.toDouble(),
      params.height.toDouble(),
    );

    final result = await ImageEditorScreen.show(
      context,
      initialSize: canvasSize,
      title: context.l10n.img2img_drawSketch,
    );

    if (result != null && result.modifiedImage != null && mounted) {
      final notifier = ref.read(generationParamsNotifierProvider.notifier);
      notifier.setSourceImage(result.modifiedImage!);
      notifier.updateAction(ImageGenerationAction.img2img);

      // 如果有蒙版也设置
      if (result.maskImage != null) {
        notifier.setMaskImage(result.maskImage!);
        notifier.updateAction(ImageGenerationAction.infill);
      }
    }
  }
}

/// 小型图标按钮
class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  const _IconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              icon,
              size: 16,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
