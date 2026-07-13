import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../../../core/enums/precise_ref_type.dart';
import '../../../../../core/extensions/precise_ref_type_extensions.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/image/image_params.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../utils/dropped_file_reader.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/hover_image_preview.dart';
import '../../../widgets/common/precise_reference_type_dialog.dart';
import '../../../widgets/common/themed_divider.dart';
import '../../../widgets/common/collapsible_image_panel.dart';
import '../../../widgets/common/decoded_memory_image.dart';

const double _disabledPreciseReferenceCardOpacity = 0.48;

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
  bool _isFileDraggingOver = false;
  bool _isProcessingDroppedFiles = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final references = ref.watch(
      generationParamsNotifierProvider.select(
        (params) => params.preciseReferences,
      ),
    );
    final hasReferences = references.isNotEmpty;
    final activeReferenceCount = references
        .where((reference) => reference.enabled)
        .length;
    final hasActiveReferences = activeReferenceCount > 0;
    final isV4Model = ref.watch(
      generationParamsNotifierProvider.select((params) => params.isV4Model),
    );

    // 判断是否显示背景（折叠且有数据时显示）
    final showBackground = hasReferences && !_isExpanded;

    return CollapsibleImagePanel(
      title: context.l10n.preciseRef_title,
      icon: Icons.person_pin,
      isExpanded: _isExpanded,
      onToggle: () => setState(() => _isExpanded = !_isExpanded),
      hasData: hasReferences,
      backgroundImage: showBackground
          ? (references.length == 1
                ? DecodedMemoryImage(
                    bytes: references.first.image,
                    fit: BoxFit.cover,
                    decodeScale: 0.75,
                  )
                : Row(
                    children: references.map((ref) {
                      return Expanded(
                        child: DecodedMemoryImage(
                          bytes: ref.image,
                          fit: BoxFit.cover,
                          decodeScale: 0.75,
                        ),
                      );
                    }).toList(),
                  ))
          : null,
      badge: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: showBackground
              ? Colors.white.withValues(alpha: 0.2)
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
      // 当有参考图时显示点数消耗提示（显眼样式）
      trailing: hasActiveReferences
          ? Tooltip(
              message: context.l10n.preciseRef_costHint,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: showBackground
                      ? Colors.orange.withValues(alpha: 0.9)
                      : Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: showBackground
                        ? Colors.orange.shade300
                        : Colors.orange.shade400,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 12,
                      color: showBackground
                          ? Colors.white
                          : Colors.orange.shade700,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      context.l10n.preciseRef_costBadge,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: showBackground
                            ? Colors.white
                            : Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
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
                  color: theme.colorScheme.errorContainer.withValues(
                    alpha: 0.3,
                  ),
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
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),

            // 参考列表
            if (hasReferences) ...[
              ...List.generate(references.length, (index) {
                return _PreciseReferenceCard(
                  index: index,
                  reference: references[index],
                  onRemove: () => _removeReference(index),
                  onEnabledChanged: (value) =>
                      _updateReferenceEnabled(index, value),
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
            _buildAddReferenceDropTarget(
              isV4Model: isV4Model,
              child: OutlinedButton.icon(
                onPressed: isV4Model ? _addReference : null,
                icon: Icon(
                  _isFileDraggingOver ? Icons.file_download_rounded : Icons.add,
                  size: 18,
                ),
                label: Text(
                  _isFileDraggingOver
                      ? context.l10n.preciseRef_dropToAdd
                      : context.l10n.preciseRef_addReference,
                ),
              ),
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

  Widget _buildAddReferenceDropTarget({
    required bool isV4Model,
    required Widget child,
  }) {
    if (!isV4Model) {
      return child;
    }

    return DropRegion(
      formats: Formats.standardFormats,
      hitTestBehavior: HitTestBehavior.opaque,
      onDropOver: (event) {
        if (_isProcessingDroppedFiles) {
          return DropOperation.none;
        }
        if (event.session.allowedOperations.contains(DropOperation.copy)) {
          if (!_isFileDraggingOver) {
            setState(() => _isFileDraggingOver = true);
          }
          return DropOperation.copy;
        }
        return DropOperation.none;
      },
      onDropLeave: (_) {
        if (_isFileDraggingOver) {
          setState(() => _isFileDraggingOver = false);
        }
      },
      onPerformDrop: (event) async {
        setState(() => _isFileDraggingOver = false);
        unawaited(_handleDroppedReferences(event));
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: _isFileDraggingOver
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                )
              : null,
        ),
        child: child,
      ),
    );
  }

  Future<void> _addReference() async {
    // 先选择类型
    final selectedType = await PreciseReferenceTypeDialog.show(context);
    if (selectedType == null) return; // 用户取消了类型选择

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final notifier = ref.read(generationParamsNotifierProvider.notifier);
        final addOperations = <Future<void>>[];

        for (final file in result.files) {
          final bytes = await _readPickedImageBytes(file);
          if (bytes == null) {
            continue;
          }

          addOperations.add(
            notifier.addPreciseReferenceFromImage(
              bytes,
              type: selectedType,
              strength: 1.0,
              fidelity: 1.0,
            ),
          );
        }

        await Future.wait(addOperations);
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

  Future<void> _handleDroppedReferences(PerformDropEvent event) async {
    if (_isProcessingDroppedFiles) {
      return;
    }

    setState(() => _isProcessingDroppedFiles = true);
    try {
      final files = <DroppedFileData>[];
      for (final item in event.session.items) {
        final reader = item.dataReader;
        if (reader == null) {
          continue;
        }

        final file = await DroppedFileReader.read(
          reader,
          logTag: 'PreciseReferenceDrop',
        );
        if (file != null) {
          files.add(file);
        }
      }

      if (!mounted) {
        return;
      }

      if (files.isEmpty) {
        AppToast.warning(context, context.l10n.preciseRef_dropNoReadableImage);
        return;
      }

      final selectedType = await PreciseReferenceTypeDialog.show(context);
      if (selectedType == null || !mounted) {
        return;
      }

      final notifier = ref.read(generationParamsNotifierProvider.notifier);
      final addOperations = files.map(
        (file) => notifier.addPreciseReferenceFromImage(
          file.bytes,
          type: selectedType,
          strength: 1.0,
          fidelity: 1.0,
        ),
      );
      await Future.wait(addOperations);

      if (mounted) {
        AppToast.success(
          context,
          context.l10n.preciseRef_addedCount(files.length),
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context,
          context.l10n.img2img_selectFailed(e.toString()),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingDroppedFiles = false);
      }
    }
  }

  Future<Uint8List?> _readPickedImageBytes(PlatformFile file) async {
    if (file.bytes != null) {
      return file.bytes;
    }

    final path = file.path;
    if (path == null) {
      return null;
    }

    return File(path).readAsBytes();
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

  void _updateReferenceEnabled(int index, bool value) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updatePreciseReference(index, enabled: value);
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
      AppToast.success(context, context.l10n.preciseRef_removedCount(count));
    }
  }
}

/// Precise Reference 卡片组件
class _PreciseReferenceCard extends StatelessWidget {
  final int index;
  final PreciseReference reference;
  final VoidCallback onRemove;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<PreciseRefType> onTypeChanged;
  final ValueChanged<double> onStrengthChanged;
  final ValueChanged<double> onFidelityChanged;

  const _PreciseReferenceCard({
    required this.index,
    required this.reference,
    required this.onRemove,
    required this.onEnabledChanged,
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
      child: AnimatedOpacity(
        key: ValueKey('precise-reference-enabled-opacity-$index'),
        opacity: reference.enabled ? 1.0 : _disabledPreciseReferenceCardOpacity,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildEnabledToggle(context, theme),
                      const SizedBox(height: 8),
                      _buildTypeDropdown(context, theme),
                    ],
                  ),
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
        child: DecodedMemoryImage(
          bytes: reference.image,
          fit: BoxFit.cover,
          maxLogicalWidth: 64,
          maxLogicalHeight: 64,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder(theme);
          },
        ),
      ),
    );

    return HoverImagePreview(imageBytes: reference.image, child: thumbnail);
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return Center(
      child: Icon(Icons.person, size: 24, color: theme.colorScheme.outline),
    );
  }

  Widget _buildEnabledToggle(BuildContext context, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.reference_enabled,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(width: 8),
        Tooltip(
          message: reference.enabled
              ? context.l10n.reference_disable
              : context.l10n.reference_enable,
          child: Transform.scale(
            scale: 0.78,
            child: Switch(
              key: ValueKey('precise-reference-enabled-switch-$index'),
              value: reference.enabled,
              onChanged: onEnabledChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeDropdown(BuildContext context, ThemeData theme) {
    return DropdownButtonFormField<PreciseRefType>(
      initialValue: reference.type,
      isDense: true,
      decoration: InputDecoration(
        labelText: context.l10n.preciseRef_referenceType,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
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
