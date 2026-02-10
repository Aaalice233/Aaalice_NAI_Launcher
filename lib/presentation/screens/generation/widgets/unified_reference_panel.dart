import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../widgets/common/themed_divider.dart';
import '../../../../core/utils/vibe_file_parser.dart';
import '../../../../data/models/image/image_params.dart';
import '../../../../data/models/vibe/vibe_reference_v4.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../widgets/common/hover_image_preview.dart';
import '../../../widgets/common/app_toast.dart';

/// Vibe Transfer 参考面板 - V4 Vibe Transfer（最多16张、预编码、编码成本显示）
///
/// 支持功能：
/// - V4 Vibe Transfer（16张、预编码、编码成本显示）
/// - Normalize 强度标准化开关
class UnifiedReferencePanel extends ConsumerStatefulWidget {
  const UnifiedReferencePanel({super.key});

  @override
  ConsumerState<UnifiedReferencePanel> createState() =>
      _UnifiedReferencePanelState();
}

class _UnifiedReferencePanelState extends ConsumerState<UnifiedReferencePanel> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final params = ref.watch(generationParamsNotifierProvider);
    final vibes = params.vibeReferencesV4;
    final hasVibes = vibes.isNotEmpty;

    // 判断是否显示背景（折叠且有数据时显示）
    final showBackground = hasVibes && !_isExpanded;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          // 背景图片层
          if (showBackground)
            Positioned.fill(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 背景图
                  _buildBackgroundImage(vibes),
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
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_fix_high,
                        size: 20,
                        color: showBackground
                            ? Colors.white
                            : hasVibes
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.l10n.vibe_title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: showBackground
                                ? Colors.white
                                : hasVibes
                                    ? theme.colorScheme.primary
                                    : null,
                          ),
                        ),
                      ),
                      // 数量标志（有数据时显示）
                      if (hasVibes) ...[
                        Container(
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
                            '${params.vibeReferencesV4.length}/16',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: showBackground
                                  ? Colors.white
                                  : theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        size: 20,
                        color: showBackground ? Colors.white : null,
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
                      const ThemedDivider(),

                      // Vibe Transfer 内容
                      _buildVibeContent(
                        context,
                        theme,
                        params,
                        showBackground,
                      ),
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

  /// 构建背景图片
  Widget _buildBackgroundImage(List<VibeReferenceV4> vibes) {
    if (vibes.isEmpty) {
      return const SizedBox.shrink();
    }

    if (vibes.length == 1) {
      // 单张风格迁移：全屏背景
      final imageData = vibes.first.rawImageData ?? vibes.first.thumbnail;
      if (imageData != null) {
        return Image.memory(imageData, fit: BoxFit.cover);
      }
    } else {
      // 多张风格迁移：横向并列
      return Row(
        children: vibes.map((vibe) {
          final imageData = vibe.rawImageData ?? vibe.thumbnail;
          return Expanded(
            child: imageData != null
                ? Image.memory(imageData, fit: BoxFit.cover)
                : const SizedBox.shrink(),
          );
        }).toList(),
      );
    }
    return const SizedBox.shrink();
  }

  /// 构建 Vibe Transfer 内容
  Widget _buildVibeContent(
    BuildContext context,
    ThemeData theme,
    ImageParams params,
    bool showBackground,
  ) {
    final vibes = params.vibeReferencesV4;
    final hasVibes = vibes.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 说明文字
        Text(
          context.l10n.vibe_description,
          style: theme.textTheme.bodySmall?.copyWith(
            color: showBackground
                ? Colors.white70
                : theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        const SizedBox(height: 12),

        // Normalize 复选框
        _buildNormalizeOption(context, theme, params, showBackground),
        const SizedBox(height: 12),

        // Vibe 列表
        if (hasVibes) ...[
          ...List.generate(vibes.length, (index) {
            return _VibeCard(
              index: index,
              vibe: vibes[index],
              onRemove: () => _removeVibe(index),
              onStrengthChanged: (value) => _updateVibeStrength(index, value),
              onInfoExtractedChanged: (value) =>
                  _updateVibeInfoExtracted(index, value),
              showBackground: showBackground,
            );
          }),
          const SizedBox(height: 8),
        ],

        // 添加按钮
        if (vibes.length < 16)
          OutlinedButton.icon(
            onPressed: _addVibe,
            icon: const Icon(Icons.add, size: 18),
            label: Text(context.l10n.vibe_addReference),
            style: showBackground
                ? OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                  )
                : null,
          ),

        // 清除全部按钮
        if (hasVibes) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _clearAllVibes,
            icon: const Icon(Icons.clear_all, size: 18),
            label: Text(context.l10n.vibe_clearAll),
            style: TextButton.styleFrom(
              foregroundColor:
                  showBackground ? Colors.red[300] : theme.colorScheme.error,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildNormalizeOption(
    BuildContext context,
    ThemeData theme,
    ImageParams params,
    bool showBackground,
  ) {
    return Row(
      children: [
        Checkbox(
          value: params.normalizeVibeStrength,
          onChanged: (value) {
            ref
                .read(generationParamsNotifierProvider.notifier)
                .setNormalizeVibeStrength(value ?? true);
          },
          visualDensity: VisualDensity.compact,
          fillColor: showBackground
              ? WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return Colors.transparent;
                })
              : null,
          checkColor: showBackground ? Colors.black : null,
          side: showBackground ? const BorderSide(color: Colors.white) : null,
        ),
        Expanded(
          child: GestureDetector(
            onTap: () {
              ref
                  .read(generationParamsNotifierProvider.notifier)
                  .setNormalizeVibeStrength(!params.normalizeVibeStrength);
            },
            child: Text(
              context.l10n.vibe_normalize,
              style: theme.textTheme.bodySmall?.copyWith(
                color: showBackground ? Colors.white : null,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _addVibe() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'png',
          'jpg',
          'jpeg',
          'webp',
          'naiv4vibe',
          'naiv4vibebundle',
        ],
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final notifier = ref.read(generationParamsNotifierProvider.notifier);

        for (final file in result.files) {
          Uint8List? bytes;
          final String fileName = file.name;

          if (file.bytes != null) {
            bytes = file.bytes;
          } else if (file.path != null) {
            bytes = await File(file.path!).readAsBytes();
          }

          if (bytes != null) {
            try {
              final vibes = await VibeFileParser.parseFile(fileName, bytes);

              // 检查是否需要编码
              final needsEncoding = vibes.any(
                (v) => v.sourceType == VibeSourceType.rawImage,
              );

              // 如果需要编码，显示确认对话框
              if (needsEncoding && mounted) {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text(context.l10n.vibeNoEncodingWarning),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fileName),
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.vibeWillCostAnlas(2),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.l10n.vibeEncodeConfirm,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(context.l10n.vibeCancel),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(context.l10n.vibeConfirmEncode),
                      ),
                    ],
                  ),
                );

                if (confirm != true) {
                  continue; // 用户取消，跳过此文件
                }
              }

              notifier.addVibeReferencesV4(vibes);
            } catch (e) {
              if (mounted) {
                AppToast.error(context, 'Failed to parse $fileName: \$e');
              }
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
            context, context.l10n.img2img_selectFailed(e.toString()),);
      }
    }
  }

  void _removeVibe(int index) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .removeVibeReferenceV4(index);
  }

  void _updateVibeStrength(int index, double value) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updateVibeReferenceV4(index, strength: value);
  }

  void _updateVibeInfoExtracted(int index, double value) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updateVibeReferenceV4(index, infoExtracted: value);
  }

  void _clearAllVibes() {
    ref.read(generationParamsNotifierProvider.notifier).clearVibeReferencesV4();
  }
}

/// Vibe 卡片组件
class _VibeCard extends StatelessWidget {
  final int index;
  final VibeReferenceV4 vibe;
  final VoidCallback onRemove;
  final ValueChanged<double> onStrengthChanged;
  final ValueChanged<double> onInfoExtractedChanged;
  final bool showBackground;

  const _VibeCard({
    required this.index,
    required this.vibe,
    required this.onRemove,
    required this.onStrengthChanged,
    required this.onInfoExtractedChanged,
    this.showBackground = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRawImage = vibe.sourceType == VibeSourceType.rawImage;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧：缩略图 + 删除按钮
          Column(
            children: [
              // 缩略图
              _buildThumbnail(theme),
              const SizedBox(height: 8),
              // 删除按钮
              SizedBox(
                height: 28,
                width: 28,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: theme.colorScheme.error,
                  ),
                  onPressed: onRemove,
                  tooltip: context.l10n.vibe_remove,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // 右侧：滑条
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Reference Strength 滑条
                _buildSliderRow(
                  context,
                  theme,
                  label: context.l10n.vibe_referenceStrength,
                  value: vibe.strength,
                  onChanged: onStrengthChanged,
                ),

                // Information Extracted 滑条 (仅原始图片)
                if (isRawImage)
                  _buildSliderRow(
                    context,
                    theme,
                    label: context.l10n.vibe_infoExtraction,
                    value: vibe.infoExtracted,
                    onChanged: onInfoExtractedChanged,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(ThemeData theme) {
    final thumbnail = ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 64,
        height: 64,
        color: theme.colorScheme.surfaceContainerHighest,
        child: vibe.thumbnail != null
            ? Image.memory(
                vibe.thumbnail!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildPlaceholder(theme);
                },
              )
            : _buildPlaceholder(theme),
      ),
    );

    // 悬浮预览使用原始图片数据或缩略图
    final previewBytes = vibe.rawImageData ?? vibe.thumbnail;
    if (previewBytes != null) {
      return HoverImagePreview(
        imageBytes: previewBytes,
        child: thumbnail,
      );
    }
    return thumbnail;
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Center(
      child: Icon(
        Icons.auto_awesome,
        size: 24,
        color: theme.colorScheme.outline,
      ),
    );
  }

  Widget _buildSliderRow(
    BuildContext context,
    ThemeData theme, {
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标签 + 数值
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                ),
              ),
            ),
            Text(
              value.toStringAsFixed(1),
              style: theme.textTheme.bodySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        // 滑条
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: value,
            min: 0.0,
            max: 1.0,
            divisions: 100,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
