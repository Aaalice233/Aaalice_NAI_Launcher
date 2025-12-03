import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/image/image_params.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../widgets/image_editor/image_editor_screen.dart';

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
    final isImg2ImgMode = params.action == ImageGenerationAction.img2img;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 背景图片层（折叠且有图片时显示）
          if (hasSourceImage && !_isExpanded)
            Positioned.fill(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(
                    params.sourceImage!,
                    fit: BoxFit.cover,
                  ),
                  // 暗化遮罩
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.5),
                          Colors.black.withOpacity(0.75),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // 内容层
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 标题栏
              InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.image,
                        size: 20,
                        color: hasSourceImage && _isExpanded
                            ? Colors.white
                            : isImg2ImgMode
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.l10n.img2img_title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: hasSourceImage && _isExpanded
                                ? Colors.white
                                : isImg2ImgMode
                                    ? theme.colorScheme.primary
                                    : null,
                          ),
                        ),
                      ),
                      if (hasSourceImage)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _isExpanded
                                ? Colors.white.withOpacity(0.2)
                                : theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            context.l10n.img2img_enabled,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: _isExpanded
                                  ? Colors.white
                                  : theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 20,
                        color: hasSourceImage && _isExpanded ? Colors.white : null,
                      ),
                    ],
                  ),
                ),
              ),

              // 展开内容
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: _isExpanded
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Divider(color: hasSourceImage ? Colors.white24 : null),

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
                secondChild: const SizedBox.shrink(),
              ),
            ],
          ),
        ],
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
              ],
            ),
          ],
        ],
      );
    }

    // 无图片时：显示选择区域
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.img2img_sourceImage,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: _pickImage,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.5),
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 32,
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.img2img_clickToSelectImage,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
              ref.read(generationParamsNotifierProvider.notifier)
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
              ref.read(generationParamsNotifierProvider.notifier)
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
          ref.read(generationParamsNotifierProvider.notifier)
              .setSourceImage(bytes);
          ref.read(generationParamsNotifierProvider.notifier)
              .updateAction(ImageGenerationAction.img2img);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.img2img_selectFailed(e.toString()))),
        );
      }
    }
  }

  void _removeSourceImage() {
    ref.read(generationParamsNotifierProvider.notifier).setSourceImage(null);
    ref.read(generationParamsNotifierProvider.notifier)
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
