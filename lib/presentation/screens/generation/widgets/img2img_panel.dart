import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../data/models/image/image_params.dart';
import '../../../providers/image_generation_provider.dart';

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题栏
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.image,
                    size: 20,
                    color: isImg2ImgMode
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '图生图 (Img2Img)',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: isImg2ImgMode
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
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '已启用',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
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
                  const Divider(),

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
                      label: const Text('清除图生图设置'),
                    ),
                  ],
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceImageSection(ThemeData theme, ImageParams params) {
    final hasSourceImage = params.sourceImage != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '源图像',
              style: theme.textTheme.bodyMedium,
            ),
            const Spacer(),
            if (!hasSourceImage)
              TextButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.add_photo_alternate, size: 18),
                label: const Text('选择图片'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (hasSourceImage)
          Stack(
            children: [
              // 预览图像
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(
                  params.sourceImage!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
              // 替换/删除按钮
              Positioned(
                top: 4,
                right: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _IconButton(
                      icon: Icons.refresh,
                      onPressed: _pickImage,
                      tooltip: '更换图片',
                    ),
                    const SizedBox(width: 4),
                    _IconButton(
                      icon: Icons.close,
                      onPressed: _removeSourceImage,
                      tooltip: '移除图片',
                    ),
                  ],
                ),
              ),
            ],
          )
        else
          // 空状态
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
                      '点击选择图片',
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
              '变化强度',
              style: theme.textTheme.bodyMedium,
            ),
            const Spacer(),
            Text(
              params.strength.toStringAsFixed(2),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Slider(
          value: params.strength,
          min: 0.0,
          max: 1.0,
          divisions: 100,
          onChanged: (value) {
            ref.read(generationParamsNotifierProvider.notifier)
                .updateStrength(value);
          },
        ),
        Text(
          '值越高，生成的图像与原图差异越大',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.5),
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
              '噪声量',
              style: theme.textTheme.bodyMedium,
            ),
            const Spacer(),
            Text(
              params.noise.toStringAsFixed(2),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Slider(
          value: params.noise,
          min: 0.0,
          max: 1.0,
          divisions: 100,
          onChanged: (value) {
            ref.read(generationParamsNotifierProvider.notifier)
                .updateNoise(value);
          },
        ),
        Text(
          '添加额外噪声以增加变化',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.5),
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
          SnackBar(content: Text('选择图片失败: $e')),
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
