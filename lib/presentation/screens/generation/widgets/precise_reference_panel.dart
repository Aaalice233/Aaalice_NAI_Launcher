import '../../../widgets/common/image_card_inline_actions.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../widgets/common/image_viewport_surface.dart';
import '../../../../../core/enums/precise_ref_type.dart';
import '../../../../../core/extensions/precise_ref_type_extensions.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/image/image_params.dart';
import '../../../../data/services/precise_ref_library_storage_service.dart';
import '../../../providers/generation/generation_panel_expansion_provider.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/precise_ref_library_provider.dart';
import '../../../utils/card_drop_reader.dart';
import '../../../widgets/common/image_card_action.dart';
import '../../../utils/precise_ref_library_import_helper.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/editable_double_field.dart';
import '../../../widgets/common/hover_image_preview.dart';
import '../../../widgets/common/precise_reference_type_dialog.dart';
import '../../../widgets/common/themed_divider.dart';
import '../../../widgets/common/themed_slider.dart';
import '../../../widgets/common/collapsible_image_panel.dart';
import '../../../widgets/common/decoded_memory_image.dart';
import '../../precise_ref_library/widgets/precise_ref_selector_dialog.dart';

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
  static const _panel = GenerationWorkbenchPanel.preciseReference;

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
    final isExpanded = ref.watch(
      generationPanelExpansionProvider.select(
        (value) => value.isExpanded(_panel, hasData: hasReferences),
      ),
    );
    final activeReferenceCount = references
        .where((reference) => reference.enabled)
        .length;
    final hasActiveReferences = activeReferenceCount > 0;
    final supportsPreciseReference = ref.watch(
      generationParamsNotifierProvider.select(
        (params) => params.capabilities.supportsPreciseReference,
      ),
    );

    // 判断是否显示背景（折叠且有数据时显示）
    final showBackground = hasReferences && !isExpanded;

    return CollapsibleImagePanel(
      title: context.l10n.preciseRef_title,
      icon: Icons.person_pin,
      isExpanded: isExpanded,
      onToggle: () => unawaited(
        ref.read(generationPanelExpansionProvider.notifier).toggle(_panel),
      ),
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
      childBuilder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ThemedDivider(),

            // 非 V4 模型提示
            if (!supportsPreciseReference) ...[
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
                  onSaveToLibrary: () =>
                      _saveSingleReferenceToLibrary(references[index]),
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
              supportsPreciseReference: supportsPreciseReference,
              child: FilledButton.tonalIcon(
                onPressed: supportsPreciseReference ? _addReference : null,
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

            // 库操作：从库导入 / 保存到库
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    key: const Key('precise-ref-panel-from-library'),
                    onPressed: supportsPreciseReference
                        ? _importFromLibrary
                        : null,
                    icon: const Icon(Icons.photo_library_outlined, size: 16),
                    label: Text(
                      context.l10n.preciseRefLib_fromLibrary,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton.icon(
                    key: const Key('precise-ref-panel-save-to-library'),
                    onPressed: hasReferences ? _saveReferencesToLibrary : null,
                    icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                    label: Text(
                      context.l10n.preciseRefLib_saveCurrentToLibrary,
                      style: const TextStyle(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
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
    required bool supportsPreciseReference,
    required Widget child,
  }) {
    if (!supportsPreciseReference) {
      return child;
    }

    return DropRegion(
      formats: cardDropFormats,
      hitTestBehavior: HitTestBehavior.opaque,
      onDropOver: (event) {
        if (_isProcessingDroppedFiles) {
          return DropOperation.none;
        }
        if (event.session.allowedOperations.contains(DropOperation.copy) &&
            const CardDropPolicy().accepts(event.session.items)) {
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
        await _handleDroppedReferences(event);
      },
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 150),
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

  /// 从精准参考库导入条目（套用条目记住的类型与参数）
  Future<void> _importFromLibrary() async {
    final selected = await PreciseRefSelectorDialog.show(context);
    if (selected == null || selected.isEmpty || !mounted) return;

    final storage = ref.read(preciseRefLibraryStorageServiceProvider);
    final notifier = ref.read(generationParamsNotifierProvider.notifier);
    final libraryNotifier = ref.read(
      preciseRefLibraryNotifierProvider.notifier,
    );

    final futures = <Future<void>>[];
    var added = 0;
    for (final entry in selected) {
      final bytes = await storage.readImageBytes(entry.id);
      if (bytes == null) continue;
      futures.add(
        notifier.addPreciseReferenceFromImage(
          bytes,
          type: entry.type,
          strength: entry.strength,
          fidelity: entry.fidelity,
        ),
      );
      unawaited(libraryNotifier.recordUsage(entry.id));
      added++;
    }
    await Future.wait(futures);

    if (!mounted) return;
    if (added > 0) {
      AppToast.success(context, context.l10n.preciseRef_addedCount(added));
    }
    if (added < selected.length) {
      AppToast.warning(context, context.l10n.preciseRefLib_imageMissing);
    }
  }

  /// 把单张参考图（含类型与参数）保存到精准参考库
  Future<void> _saveSingleReferenceToLibrary(PreciseReference reference) async {
    try {
      final entry = await ref
          .read(preciseRefLibraryNotifierProvider.notifier)
          .importFromBytes(
            reference.image,
            name: defaultPreciseRefName(),
            type: reference.type,
            strength: reference.strength,
            fidelity: reference.fidelity,
          );
      if (!mounted) return;
      AppToast.success(context, context.l10n.preciseRefLib_saved(entry.name));
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, preciseRefImportErrorMessage(context, e));
    }
  }

  /// 把当前参考图（含各自类型与参数）保存到精准参考库
  Future<void> _saveReferencesToLibrary() async {
    final references = ref
        .read(generationParamsNotifierProvider)
        .preciseReferences;
    if (references.isEmpty) return;

    final PreciseRefLibraryBatchImportResult batch;
    try {
      batch = await ref
          .read(preciseRefLibraryNotifierProvider.notifier)
          .importMany([
            for (final reference in references)
              PreciseRefLibraryImportSource(
                loadBytes: () async => reference.image,
                name: defaultPreciseRefName(),
                type: reference.type,
                strength: reference.strength,
                fidelity: reference.fidelity,
              ),
          ]);
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, preciseRefImportErrorMessage(context, e));
      return;
    }

    if (!mounted) return;
    if (batch.importedCount > 0) {
      AppToast.success(
        context,
        context.l10n.preciseRefLib_saveCurrentCount(batch.importedCount),
      );
    }
    if (batch.failedCount > 0) {
      AppToast.error(
        context,
        context.l10n.preciseRefLib_importFailedCount(batch.failedCount),
      );
    }
  }

  Future<void> _addReference() async {
    const selectedType = PreciseRefType.characterAndStyle;

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
    if (_isProcessingDroppedFiles) return;
    setState(() => _isProcessingDroppedFiles = true);
    try {
      final resources = await readCardDrop(context, event.session.items);
      // The type chooser opens only after the native read session returns.
      unawaited(Future<void>(() => _applyDroppedReferences(resources)));
    } catch (error) {
      if (!mounted) return;
      setState(() => _isProcessingDroppedFiles = false);
      AppToast.error(context, context.l10n.img2img_selectFailed('$error'));
    }
  }

  Future<void> _applyDroppedReferences(
    List<CardDroppedResource> resources,
  ) async {
    if (!mounted) return;
    final notifier = ref.read(generationParamsNotifierProvider.notifier);
    final library = ref.read(preciseRefLibraryNotifierProvider.notifier);
    try {
      const type = PreciseRefType.characterAndStyle;
      if (!mounted) return;
      final result = await ImageCardBatchResult.execute(resources, (
        resource,
      ) async {
        final entry = resource.preciseReference;
        await notifier.addPreciseReferenceFromImage(
          resource.image.bytes,
          type: entry?.type ?? type,
          strength: entry?.strength ?? 1,
          fidelity: entry?.fidelity ?? 1,
        );
        if (entry != null) await library.recordUsage(entry.id);
      });
      if (!mounted) return;
      if (result.failures.isNotEmpty) {
        throw StateError(
          '${result.failures.length}/${resources.length}: ${result.failures.values.map((failure) => failure.error).join('; ')}',
        );
      }
      AppToast.success(
        context,
        context.l10n.preciseRef_addedCount(result.succeeded.length),
      );
    } catch (error) {
      if (mounted) {
        AppToast.error(context, context.l10n.img2img_selectFailed('$error'));
      }
    } finally {
      if (mounted) setState(() => _isProcessingDroppedFiles = false);
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

/// Precise Reference 卡片组件（极致扁平化，青草绿高亮，首行功能全集成）
class _PreciseReferenceCard extends StatelessWidget {
  final int index;
  final PreciseReference reference;
  final VoidCallback onRemove;
  final ImageCardCallback onSaveToLibrary;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<PreciseRefType> onTypeChanged;
  final ValueChanged<double> onStrengthChanged;
  final ValueChanged<double> onFidelityChanged;

  const _PreciseReferenceCard({
    required this.index,
    required this.reference,
    required this.onRemove,
    required this.onSaveToLibrary,
    required this.onEnabledChanged,
    required this.onTypeChanged,
    required this.onStrengthChanged,
    required this.onFidelityChanged,
  });

  void _toggleType(bool toggleCharacter) {
    final isCurrentlyActive = reference.enabled;
    final hasChar = isCurrentlyActive &&
        (reference.type == PreciseRefType.character ||
            reference.type == PreciseRefType.characterAndStyle);
    final hasStyle = isCurrentlyActive &&
        (reference.type == PreciseRefType.style ||
            reference.type == PreciseRefType.characterAndStyle);

    var newChar = hasChar;
    var newStyle = hasStyle;

    if (toggleCharacter) {
      newChar = !hasChar;
    } else {
      newStyle = !hasStyle;
    }

    if (!newChar && !newStyle) {
      if (reference.enabled) {
        onEnabledChanged(false);
      }
    } else {
      if (!reference.enabled) {
        onEnabledChanged(true);
      }
      if (newChar && newStyle) {
        onTypeChanged(PreciseRefType.characterAndStyle);
      } else if (newChar) {
        onTypeChanged(PreciseRefType.character);
      } else {
        onTypeChanged(PreciseRefType.style);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasChar = reference.enabled &&
        (reference.type == PreciseRefType.character ||
            reference.type == PreciseRefType.characterAndStyle);
    final hasStyle = reference.enabled &&
        (reference.type == PreciseRefType.style ||
            reference.type == PreciseRefType.characterAndStyle);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: AnimatedOpacity(
        key: ValueKey('precise-reference-enabled-opacity-$index'),
        opacity: reference.enabled ? 1.0 : _disabledPreciseReferenceCardOpacity,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 首行：缩略图 + 【角色】【风格】双卡片 + 启用 + 收藏 + 删除 (全在一排！)
            Row(
              children: [
                _buildThumbnail(theme),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      // 【角色】小卡片
                      _buildChip(
                        label: context.l10n.preciseRef_typeCharacter,
                        selected: hasChar,
                        onTap: () => _toggleType(true),
                        theme: theme,
                      ),
                      const SizedBox(width: 4),
                      // 【风格】小卡片
                      _buildChip(
                        label: context.l10n.preciseRef_typeStyle,
                        selected: hasStyle,
                        onTap: () => _toggleType(false),
                        theme: theme,
                      ),
                      const Spacer(),
                      // 启用小 Switch
                      Tooltip(
                        message: reference.enabled
                            ? context.l10n.reference_disable
                            : context.l10n.reference_enable,
                        child: Transform.scale(
                          scale: 0.72,
                          child: Switch(
                            key: ValueKey('precise-reference-enabled-switch-$index'),
                            value: reference.enabled,
                            onChanged: onEnabledChanged,
                            activeColor: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      // 收藏按钮
                      IconButton(
                        icon: const Icon(Icons.bookmark_add_outlined, size: 16),
                        tooltip: context.l10n.preciseRefLib_saveCurrentToLibrary,
                        color: theme.colorScheme.primary,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        visualDensity: VisualDensity.compact,
                        onPressed: onSaveToLibrary,
                      ),
                      // 删除按钮
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 16),
                        tooltip: context.l10n.preciseRef_remove,
                        color: theme.colorScheme.error,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                        visualDensity: VisualDensity.compact,
                        onPressed: onRemove,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            // 单行参考强度滑块
            _buildSingleLineSliderRow(
              context,
              theme,
              label: context.l10n.preciseRef_strength,
              value: reference.strength,
              onChanged: onStrengthChanged,
            ),

            const SizedBox(height: 2),

            // 单行保真度滑块
            _buildSingleLineSliderRow(
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

  Widget _buildChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary.withValues(alpha: 0.8)
                : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.35),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(ThemeData theme) {
    final thumbnail = ClipRRect(
      borderRadius: BorderRadius.circular(5),
      child: Container(
        width: 48,
        height: 48,
        color: ImageViewportSurface.background,
        child: DecodedMemoryImage(
          bytes: reference.image,
          fit: BoxFit.cover,
          maxLogicalWidth: 48,
          maxLogicalHeight: 48,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholder(theme);
          },
        ),
      ),
    );

    return HoverImagePreview(imageBytes: reference.image, child: thumbnail);
  }

  Widget _buildPlaceholder(ThemeData theme) {
    return const Center(
      child: Icon(
        Icons.person,
        size: 20,
        color: ImageViewportSurface.mutedForeground,
      ),
    );
  }

  Widget _buildSingleLineSliderRow(
    BuildContext context,
    ThemeData theme, {
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2.0,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4.5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              activeTrackColor: theme.colorScheme.primary,
              thumbColor: theme.colorScheme.primary,
              inactiveTrackColor:
                  theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
            ),
            child: Slider(
              value: value,
              min: 0.0,
              max: 1.0,
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(width: 4),
        EditableDoubleField(
          value: value,
          semanticLabel: label,
          decimals: 2,
          width: 48,
          onChanged: onChanged,
          textStyle: theme.textTheme.bodySmall?.copyWith(
            fontSize: 10.5,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
