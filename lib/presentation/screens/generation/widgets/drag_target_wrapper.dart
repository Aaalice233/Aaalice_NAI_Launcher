import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../core/utils/vibe_performance_diagnostics.dart';
import '../../../../data/models/image/image_params.dart';
import '../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../../data/models/vibe/vibe_reference.dart';
import '../../../../data/services/vibe_library_storage_service.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../widgets/common/app_toast.dart';
import '../../vibe_library/widgets/vibe_selector_dialog.dart';
import '../handlers/vibe_import_handler.dart';
import 'empty_state_card.dart';
import 'library_actions_row.dart';
import 'vibe_card.dart';

/// DragTarget 包装器，支持从库拖拽 Vibe
class DragTargetWrapper extends ConsumerWidget {
  final ImageParams params;
  final List<VibeReference> vibes;
  final bool showBackground;

  const DragTargetWrapper({
    super.key,
    required this.params,
    required this.vibes,
    required this.showBackground,
  });

  bool get hasVibes => vibes.isNotEmpty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final panelState = ref.watch(referencePanelNotifierProvider);
    final panelNotifier = ref.read(referencePanelNotifierProvider.notifier);

    return DragTarget<VibeLibraryEntry>(
      onWillAcceptWithDetails: (details) {
        // 检查是否超过 16 个限制
        final currentCount = ref
            .read(generationParamsNotifierProvider)
            .vibeReferencesV4
            .length;
        if (currentCount >= 16) {
          AppToast.warning(context, context.l10n.vibe_maxReached);
          return false;
        }
        panelNotifier.setDraggingOver(true);
        return true;
      },
      onAcceptWithDetails: (details) async {
        HapticFeedback.heavyImpact();
        panelNotifier.setDraggingOver(false);
        await _addLibraryVibe(context, ref, details.data);
      },
      onLeave: (_) {
        panelNotifier.setDraggingOver(false);
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: panelState.isDraggingOver
                ? Border.all(color: theme.colorScheme.primary, width: 2)
                : null,
            color: panelState.isDraggingOver
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasVibes) ...[
                ...List.generate(vibes.length, (index) {
                  final vibe = vibes[index];
                  return VibeCard(
                    index: index,
                    vibe: vibe,
                    onRemove: () => _removeVibe(context, ref, index),
                    onStrengthChanged: (value) =>
                        _updateVibeStrength(ref, index, value),
                    onInfoExtractedChanged: (value) =>
                        _updateVibeInfoExtracted(ref, index, value),
                    onEnabledChanged: (value) =>
                        _updateVibeEnabled(ref, index, value),
                  );
                }),
                const SizedBox(height: 12),

                // 库操作按钮行
                LibraryActionsRow(
                  vibes: vibes,
                  onSaveToLibrary: () => _saveToLibrary(context, ref),
                  onImportFromLibrary: () => _importFromLibrary(context, ref),
                ),
                const SizedBox(height: 8),
              ] else ...[
                // 空状态优化
                _buildEmptyState(context, ref, theme),
              ],
            ],
          ),
        );
      },
    );
  }

  /// 构建空状态 - 双卡片并排布局：从文件添加 + 从库导入
  Widget _buildEmptyState(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
  ) {
    return Row(
      children: [
        // 从文件添加
        Expanded(
          child: EmptyStateCard(
            icon: Icons.add_photo_alternate_outlined,
            title: context.l10n.vibe_addFromFileTitle,
            subtitle: context.l10n.vibe_addFromFileSubtitle,
            onTap: () async => await _addVibeStatic(context, ref),
          ),
        ),
        const SizedBox(width: 12),
        // 从库导入
        Expanded(
          child: EmptyStateCard(
            icon: Icons.folder_open_outlined,
            title: context.l10n.vibe_addFromLibraryTitle,
            subtitle: context.l10n.vibe_addFromLibrarySubtitle,
            onTap: () async => await _importFromLibrary(context, ref),
          ),
        ),
      ],
    );
  }

  void _removeVibe(BuildContext context, WidgetRef ref, int index) {
    final notifier = ref.read(generationParamsNotifierProvider.notifier);
    final panelNotifier = ref.read(referencePanelNotifierProvider.notifier);
    final currentVibes = ref
        .read(generationParamsNotifierProvider)
        .vibeReferencesV4;

    // 清理 bundle 来源记录
    if (index < currentVibes.length) {
      final vibeName = currentVibes[index].displayName;
      panelNotifier.removeBundleSource(vibeName);
    }

    notifier.removeVibeReference(index);
    notifier.saveGenerationState();
  }

  void _updateVibeStrength(WidgetRef ref, int index, double value) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updateVibeReference(index, strength: value);
  }

  void _updateVibeInfoExtracted(WidgetRef ref, int index, double value) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updateVibeReference(index, infoExtracted: value);
  }

  void _updateVibeEnabled(WidgetRef ref, int index, bool value) {
    ref
        .read(generationParamsNotifierProvider.notifier)
        .updateVibeReference(index, enabled: value);
  }

  /// 从文件添加 Vibe（供外部调用）
  static Future<void> addVibeFromFile(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await _addVibeStatic(context, ref);
  }

  static Future<void> _addVibeStatic(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final handler = VibeImportHandler(ref: ref, context: context);
    await handler.importFromFiles();
  }

  Future<void> _saveToLibrary(BuildContext context, WidgetRef ref) async {
    final params = ref.read(generationParamsNotifierProvider);
    final currentVibes = params.vibeReferencesV4;

    if (currentVibes.isEmpty) return;

    final handler = VibeImportHandler(ref: ref, context: context);
    await handler.saveToLibrary(currentVibes);
  }

  Future<void> _importFromLibrary(BuildContext context, WidgetRef ref) async {
    final span = VibePerformanceDiagnostics.start(
      'dragTarget.importFromLibrary',
    );
    final storageService = ref.read(vibeLibraryStorageServiceProvider);
    final panelNotifier = ref.read(referencePanelNotifierProvider.notifier);
    var selectedEntries = 0;
    var bundleEntries = 0;
    var totalAdded = 0;
    var replacedExisting = false;

    try {
      final result = await VibeSelectorDialog.show(
        context: context,
        initialSelectedIds: const {},
        showReplaceOption: true,
        title: context.l10n.vibe_import_title,
      );

      if (result == null || result.selectedEntries.isEmpty) return;
      selectedEntries = result.selectedEntries.length;

      final notifier = ref.read(generationParamsNotifierProvider.notifier);

      if (result.shouldReplace) {
        notifier.clearVibeReferences();
        replacedExisting = true;
      }

      for (final entry in result.selectedEntries) {
        final currentCount = ref
            .read(generationParamsNotifierProvider)
            .vibeReferencesV4
            .length;
        if (currentCount >= 16) break;

        if (entry.isBundle) {
          bundleEntries++;
          final added = await panelNotifier.extractAndAddBundleVibes(
            entry,
            maxCount: 16,
          );
          totalAdded += added;
        } else {
          final existingNames = ref
              .read(generationParamsNotifierProvider)
              .vibeReferencesV4
              .map((v) => v.displayName)
              .toSet();
          if (!existingNames.contains(entry.displayName)) {
            final vibe = entry.toVibeReference();
            notifier.addVibeReferences([vibe], recordUsage: false);
            totalAdded++;
          }
        }

        await storageService.incrementUsedCount(entry.id);
      }

      await panelNotifier.loadRecentEntries();

      if (context.mounted) {
        AppToast.success(context, context.l10n.vibe_import_result(totalAdded));
      }
    } catch (e, stackTrace) {
      AppLogger.e('Failed to import from library', e, stackTrace);
      if (context.mounted) {
        AppToast.error(
          context,
          context.l10n.vibe_import_failedWithError(e.toString()),
        );
      }
    } finally {
      span.finish(
        details: {
          'selectedEntries': selectedEntries,
          'bundleEntries': bundleEntries,
          'totalAdded': totalAdded,
          'replacedExisting': replacedExisting,
        },
      );
    }
  }

  Future<void> _addLibraryVibe(
    BuildContext context,
    WidgetRef ref,
    VibeLibraryEntry entry,
  ) async {
    final span = VibePerformanceDiagnostics.start(
      'dragTarget.addLibraryVibe',
      details: {'entryId': entry.id, 'isBundle': entry.isBundle},
    );
    var success = false;
    final panelNotifier = ref.read(referencePanelNotifierProvider.notifier);

    try {
      success = await panelNotifier.addLibraryVibe(entry);

      if (context.mounted) {
        if (success) {
          AppToast.success(
            context,
            context.l10n.vibe_addedNamed(entry.displayName),
          );
        } else {
          AppToast.warning(context, context.l10n.vibe_maxReachedRemoveSome);
        }
      }
    } finally {
      span.finish(details: {'success': success});
    }
  }
}
