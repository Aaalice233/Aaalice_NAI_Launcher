import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../core/utils/vibe_file_parser.dart';
import '../../../../data/models/image/image_params.dart';
import '../../../../data/models/vibe/vibe_reference_v4.dart';
import '../../../providers/image_generation_provider.dart';

/// Vibe Transfer V2 面板组件
///
/// 功能:
/// - 支持预编码 Vibe (.naiv4vibe, .naiv4vibebundle, PNG 带元数据)
/// - 支持原始图片 (需服务端编码)
/// - Normalize Reference Strength 选项
/// - 编码成本显示
class VibeTransferPanelV2 extends ConsumerStatefulWidget {
  const VibeTransferPanelV2({super.key});

  @override
  ConsumerState<VibeTransferPanelV2> createState() =>
      _VibeTransferPanelV2State();
}

class _VibeTransferPanelV2State extends ConsumerState<VibeTransferPanelV2> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final params = ref.watch(generationParamsNotifierProvider);
    final vibes = params.vibeReferencesV4;
    final hasCharacterRefs = params.characterReferences.isNotEmpty;

    // 当存在角色参考时，Vibe Transfer 不可用
    if (hasCharacterRefs) {
      return const SizedBox.shrink();
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题栏
          _buildHeader(context, theme, vibes.length),

          // 展开内容
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: _buildBody(context, theme, params, vibes),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme, int count) {
    final hasVibes = count > 0;

    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.auto_awesome,
              size: 20,
              color: hasVibes
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.vibe_title,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: hasVibes ? theme.colorScheme.primary : null,
                ),
              ),
            ),
            // 计数标签
            if (hasVibes)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '($count)',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
            // 添加按钮
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.add, size: 20),
              onPressed: _addVibe,
              tooltip: context.l10n.vibe_addReference,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
            ),
            // 展开/收起箭头
            Icon(
              _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ThemeData theme,
    ImageParams params,
    List<VibeReferenceV4> vibes,
  ) {
    final encodingCost = params.vibeEncodingCost;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(height: 1),
          const SizedBox(height: 12),

          // 描述文字
          Text(
            context.l10n.vibe_description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 12),

          // Normalize 复选框
          _buildNormalizeOption(context, theme, params),
          const SizedBox(height: 12),

          // Vibe 列表
          if (vibes.isNotEmpty) ...[
            ...List.generate(vibes.length, (index) {
              return _VibeCardV2(
                index: index,
                vibe: vibes[index],
                onRemove: () => _removeVibe(index),
                onStrengthChanged: (value) => _updateVibeStrength(index, value),
                onInfoExtractedChanged: (value) =>
                    _updateVibeInfoExtracted(index, value),
              );
            }),
            const SizedBox(height: 8),
          ],

          // 编码成本提示
          if (encodingCost > 0) ...[
            _buildEncodingCostBanner(context, theme, encodingCost),
            const SizedBox(height: 8),
          ],

          // 清除全部按钮
          if (vibes.isNotEmpty)
            TextButton.icon(
              onPressed: _clearAllVibes,
              icon: const Icon(Icons.clear_all, size: 18),
              label: Text(context.l10n.vibe_clearAll),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNormalizeOption(
    BuildContext context,
    ThemeData theme,
    ImageParams params,
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
              style: theme.textTheme.bodySmall,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEncodingCostBanner(
    BuildContext context,
    ThemeData theme,
    int cost,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: theme.colorScheme.secondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.vibe_encodingCost(cost),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
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
              notifier.addVibeReferencesV4(vibes);
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to parse $fileName: $e'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.img2img_selectFailed(e.toString())),
          ),
        );
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

/// V2 Vibe 卡片组件
class _VibeCardV2 extends StatefulWidget {
  final int index;
  final VibeReferenceV4 vibe;
  final VoidCallback onRemove;
  final ValueChanged<double> onStrengthChanged;
  final ValueChanged<double> onInfoExtractedChanged;

  const _VibeCardV2({
    required this.index,
    required this.vibe,
    required this.onRemove,
    required this.onStrengthChanged,
    required this.onInfoExtractedChanged,
  });

  @override
  State<_VibeCardV2> createState() => _VibeCardV2State();
}

class _VibeCardV2State extends State<_VibeCardV2> {
  bool _showSliders = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vibe = widget.vibe;
    final isRawImage = vibe.sourceType == VibeSourceType.rawImage;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // 主要信息行
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                // 缩略图
                _buildThumbnail(theme),
                const SizedBox(width: 12),

                // 信息
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 名称 + 来源标签
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              vibe.displayName,
                              style: theme.textTheme.bodyMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          _buildSourceBadge(theme),
                        ],
                      ),
                      const SizedBox(height: 4),
                      // 参数显示
                      Text(
                        _buildParamText(context),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),

                // 操作按钮
                IconButton(
                  icon: Icon(
                    _showSliders ? Icons.tune : Icons.tune_outlined,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _showSliders = !_showSliders),
                  tooltip: context.l10n.vibe_adjustParams,
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: widget.onRemove,
                  tooltip: context.l10n.vibe_remove,
                ),
              ],
            ),
          ),

          // 滑块区域
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 150),
            crossFadeState: _showSliders
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: _buildSliders(context, theme, isRawImage),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(ThemeData theme) {
    final vibe = widget.vibe;

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 56,
        height: 56,
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

  Widget _buildSourceBadge(ThemeData theme) {
    final vibe = widget.vibe;
    final isPreEncoded = vibe.sourceType.isPreEncoded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isPreEncoded
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        vibe.sourceType.displayLabel,
        style: theme.textTheme.labelSmall?.copyWith(
          color: isPreEncoded
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onTertiaryContainer,
          fontSize: 10,
        ),
      ),
    );
  }

  String _buildParamText(BuildContext context) {
    final vibe = widget.vibe;
    final isRawImage = vibe.sourceType == VibeSourceType.rawImage;

    if (isRawImage) {
      return 'Strength: ${vibe.strength.toStringAsFixed(2)}, Info: ${vibe.infoExtracted.toStringAsFixed(2)}';
    } else {
      return 'Strength: ${vibe.strength.toStringAsFixed(2)}';
    }
  }

  Widget _buildSliders(BuildContext context, ThemeData theme, bool isRawImage) {
    final vibe = widget.vibe;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        children: [
          // Reference Strength 滑块
          _buildSliderRow(
            context,
            theme,
            label: context.l10n.vibe_referenceStrength,
            value: vibe.strength,
            onChanged: widget.onStrengthChanged,
          ),

          // Information Extracted 滑块 (仅原始图片)
          if (isRawImage)
            _buildSliderRow(
              context,
              theme,
              label: context.l10n.vibe_infoExtraction,
              value: vibe.infoExtracted,
              onChanged: widget.onInfoExtractedChanged,
            ),
        ],
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
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: theme.textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            min: 0.0,
            max: 1.0,
            divisions: 100,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            value.toStringAsFixed(2),
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
