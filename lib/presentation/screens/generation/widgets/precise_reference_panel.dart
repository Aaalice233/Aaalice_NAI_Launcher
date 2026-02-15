import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../../core/enums/precise_ref_type.dart';
import '../../../../../core/extensions/precise_ref_type_extensions.dart';
import '../../../../core/utils/nai_api_utils.dart';
import '../../../../data/models/image/image_params.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/hover_image_preview.dart';
import '../../../widgets/common/themed_divider.dart';
import '../../../widgets/common/collapsible_image_panel.dart';

/// Precise Reference 面板 - 支持多参考、类型选择、独立参数控制
///

/// 功能特性：
/// - 支持添加多个参考图（类似 Vibe Transfer）
/// - 每个参考可独立设置：类型、强度、保真度
/// - 类型可选：Character / Style / Character & Style
/// - 不与 Vibe Transfer 互斥，可同时使用
class PreciseReferencePanel extends ConsumerStatefulWidget {
  const PreciseReferencePanel({super.key});

  @override
  ConsumerState<PreciseReferencePanel> createState() =>
      _PreciseReferencePanelState();
}

class _PreciseReferencePanelState extends ConsumerState<PreciseReferencePanel> {
  bool _isExpanded = false;
  PreciseRefType _selectedType = PreciseRefType.character;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final params = ref.watch(generationParamsNotifierProvider);
    final references = params.preciseReferences;
    final hasReferences = references.isNotEmpty;
    final isV4Model = params.isV4Model;

    // 判断是否显示背景（折叠且有数据时显示）
    final showBackground = hasReferences && !_isExpanded;

    return CollapsibleImagePanel(
      title: context.l10n.preciseRef_title,
      icon: Icons.person_pin,
      isExpanded: _isExpanded,
      onToggle: () => setState(() => _isExpanded = !_isExpanded),
      hasData: hasReferences,
      backgroundImage: hasReferences
          ? (references.length == 1
              ? Image.memory(
                  references.first.image,
                  fit: BoxFit.cover,
                )
              : Row(
                  children: references.map((ref) {
                    return Expanded(
                      child: Image.memory(ref.image, fit: BoxFit.cover),
                    );
                  }).toList(),
                ))
          : null,
      badge: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 2,
        ),
        decoration: BoxDecoration(
          color: showBackground
              ? Colors.white.withOpacity(0.2)
              : theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${references.length}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: showBackground
                ? Colors.white
                : theme.colorScheme.onSecondaryContainer,
            fontSize: 10,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ThemedDivider(),

            // 非 V4 模型提示
            if (!isV4Model) ...[
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.preciseRef_v4Only,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 说明文字
            Text(
              context.l10n.preciseRef_description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 12),

            // 参考类型选择（SegmentedButton）
            _buildTypeSelector(context, theme),
            const SizedBox(height: 12),

            // 参考列表
            if (hasReferences) ...[
              ...List.generate(references.length, (index) {
                return _PreciseReferenceCard(
                  index: index,
                  reference: references[index],
                  onRemove: () => _removeReference(index),
                  onTypeChanged: (type) => _updateReferenceType(index, type),
                  onStrengthChanged: (value) =>
                      _updateReferenceStrength(index, value),
                  onFidelityChanged: (value) =>
                      _updateReferenceFidelity(index, value),
                );
              }),
              const SizedBox(height: 8),
            ],

            // 添加按钮
            OutlinedButton.icon(
              onPressed: isV4Model ? _addReference : null,
              icon: const Icon(Icons.add, size: 18),
              label: Text(context.l10n.preciseRef_addReference),
            ),

            // 清除全部按钮
            if (hasReferences) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _clearAllReferences,
                icon: const Icon(Icons.clear_all, size: 18),
                label: Text(context.l10n.preciseRef_clearAll),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建类型选择器（DropdownButton）
  Widget _buildTypeSelector(BuildContext context, ThemeData theme) {
    final params = ref.watch(generationParamsNotifierProvider);
    final isV4Model = params.isV4Model;

    return DropdownButtonFormField<PreciseRefType>(
      value: _selectedType,
      isDense: true,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: context.l10n.preciseRef_referenceType,
        prefixIcon: const Icon(Icons.category, size: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
      items: PreciseRefType.values.map((type) {
        return DropdownMenuItem<PreciseRefType>(
          value: type,
          child: Row(
            children: [
              Icon(
                type.icon,
                size: 18,
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              const SizedBox(width: 8),
              Text(
                type.getDisplayName(
                  character: context.l10n.preciseRef_typeCharacter,
                  style: context.l10n.preciseRef_typeStyle,
                  characterAndStyle:
                      context.l10n.preciseRef_typeCharacterAndStyle,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: isV4Model
          ? (value) {
              if (value != null) {
                setState(() {
                  _selectedType = value;
                });
              }
            }
          : null,
    );
  }

  Future<void> _addReference() async {
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
          // 转换为 PNG 格式
          final pngBytes = NAIApiUtils.ensurePngFormat(bytes);

          // 添加 Precise Reference，使用当前选中的类型
          ref
              .read(generationParamsNotifierProvider.notifier)
              .addPreciseReference(
                pngBytes,
                type: _selectedType,
                strength: 0.8,
                fidelity: 1.0,
              );
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

  void _removeReference(int index) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .removePreciseReference(index);
  }

  void _updateReferenceType(int index, PreciseRefType type) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updatePreciseReferenceType(index, type);
  }

  void _updateReferenceStrength(int index, double value) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updatePreciseReference(index, strength: value);
  }

  void _updateReferenceFidelity(int index, double value) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updatePreciseReference(index, fidelity: value);
  }

  void _clearAllReferences() {
    final params = ref.read(generationParamsNotifierProvider);
    final count = params.preciseReferences.length;

    ref
        .read(generationParamsNotifierProvider.notifier)
        .clearPreciseReferences();

    if (mounted && count > 0) {
      AppToast.success(context, '已删除 $count 个精准参考');
    }
  }
}

/// Precise Reference 卡片组件
class _PreciseReferenceCard extends StatelessWidget {
  final int index;
  final PreciseReference reference;
  final VoidCallback onRemove;
  final ValueChanged<PreciseRefType> onTypeChanged;
  final ValueChanged<double> onStrengthChanged;
  final ValueChanged<double> onFidelityChanged;

  const _PreciseReferenceCard({
    required this.index,
    required this.reference,
    required this.onRemove,
    required this.onTypeChanged,
    required this.onStrengthChanged,
    required this.onFidelityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部行：缩略图、类型选择、删除按钮
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧：缩略图
              _buildThumbnail(theme),
              const SizedBox(width: 12),

              // 中间：类型选择
              Expanded(
                child: _buildTypeDropdown(context, theme),
              ),

              // 右侧：删除按钮
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
                  tooltip: context.l10n.preciseRef_remove,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 强度滑条
          _buildSliderRow(
            context,
            theme,
            label: context.l10n.preciseRef_strength,
            value: reference.strength,
            onChanged: onStrengthChanged,
          ),

          // 保真度滑条
          _buildSliderRow(
            context,
            theme,
            label: context.l10n.preciseRef_fidelity,
            value: reference.fidelity,
            onChanged: onFidelityChanged,
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
        child: Image.memory(
          reference.image,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder(theme);
          },
        ),
      ),
    );

    return HoverImagePreview(
      imageBytes: reference.image,
      child: thumbnail,
    );
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Center(
      child: Icon(
        Icons.person,
        size: 24,
        color: theme.colorScheme.outline,
      ),
    );
  }

  Widget _buildTypeDropdown(BuildContext context, ThemeData theme) {
    return DropdownButtonFormField<PreciseRefType>(
      value: reference.type,
      isDense: true,
      decoration: InputDecoration(
        labelText: context.l10n.preciseRef_referenceType,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
      ),
      items: PreciseRefType.values.map((type) {
        return DropdownMenuItem<PreciseRefType>(
          value: type,
          child: Text(
            type.getDisplayName(
              character: context.l10n.preciseRef_typeCharacter,
              style: context.l10n.preciseRef_typeStyle,
              characterAndStyle: context.l10n.preciseRef_typeCharacterAndStyle,
            ),
            style: theme.textTheme.bodySmall,
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          onTypeChanged(value);
        }
      },
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
              value.toStringAsFixed(2),
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
