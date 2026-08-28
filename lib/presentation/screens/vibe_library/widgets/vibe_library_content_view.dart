import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../../../core/utils/app_logger.dart';
import '../../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../../core/utils/vibe_file_parser.dart';
import '../../../../core/utils/vibe_performance_diagnostics.dart';
import '../../../../data/models/vibe/vibe_empty_state_info.dart';
import '../../../../data/models/vibe/vibe_library_entry.dart';
import '../../../../data/models/vibe/vibe_reference.dart';
import '../../../../data/services/vibe_library_storage_service.dart';
import '../../../providers/generation/generation_params_notifier.dart';
import '../../../providers/selection_mode_provider.dart';
import '../../../providers/vibe_library_category_provider.dart';
import '../../../providers/vibe_library_provider.dart';
import '../../../providers/vibe_library_selection_provider.dart';
import '../../../router/app_routes.dart';
import '../../../agent_chat/providers/agent_chat_notifier.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/pro_context_menu.dart';
import '../../../widgets/common/themed_confirm_dialog.dart';
import '../../../agent_chat/widgets/agent_resource_drop_region.dart';
import 'vibe_card.dart';
import 'vibe_detail_viewer.dart';
import 'vibe_export_dialog.dart';
import 'vibe_library_empty_view.dart';

const vibeLibraryGridSpacing = 16.0;

/// Vibe 库内容视图
///
/// 显示 Vibe 条目的网格视图，支持选择模式、右键菜单和操作
class VibeLibraryContentView extends ConsumerStatefulWidget {
  final int columns;
  final double itemWidth;

  const VibeLibraryContentView({
    super.key,
    required this.columns,
    required this.itemWidth,
  });

  @override
  ConsumerState<VibeLibraryContentView> createState() =>
      _VibeLibraryContentViewState();
}

class _VibeLibraryContentViewState
    extends ConsumerState<VibeLibraryContentView> {
  /// GridView 的 PageStorageKey，用于保持滚动位置
  static const String _vibeLibraryGridKey = 'vibe_library_3d_grid';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vibeLibraryNotifierProvider);
    final selectionState = ref.watch(vibeLibrarySelectionNotifierProvider);

    // 使用 3D 卡片视图模式
    return _build3DCardView(state, selectionState);
  }

  /// 构建 3D 卡片视图
  Widget _build3DCardView(
    VibeLibraryState state,
    SelectionModeState selectionState,
  ) {
    final entries = state.currentEntries;

    // 加载中状态
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 空状态处理
    if (entries.isEmpty) {
      final emptyInfo = _getEmptyStateInfo(state);
      final l10n = context.l10n;
      return VibeLibraryEmptyView(
        title: switch (emptyInfo.reason) {
          EmptyStateReason.searchNoResults => l10n.vibeLibrary_emptySearchTitle,
          EmptyStateReason.noFavorites => l10n.vibeLibrary_emptyFavoritesTitle,
          EmptyStateReason.noItemsInCategory =>
            l10n.vibeLibrary_emptyCategoryTitle,
          EmptyStateReason.defaultEmpty => l10n.vibeLibrary_emptyNoMatchesTitle,
        },
        subtitle: switch (emptyInfo.reason) {
          EmptyStateReason.searchNoResults =>
            l10n.vibeLibrary_emptySearchSubtitle,
          EmptyStateReason.noFavorites =>
            l10n.vibeLibrary_emptyFavoritesSubtitle,
          EmptyStateReason.noItemsInCategory =>
            l10n.vibeLibrary_emptyCategorySubtitle,
          EmptyStateReason.defaultEmpty => '',
        },
        iconName: emptyInfo.iconName,
      );
    }

    return GridView.builder(
      key: const PageStorageKey<String>(_vibeLibraryGridKey),
      padding: const EdgeInsets.all(16),
      scrollCacheExtent: ScrollCacheExtent.pixels(
        computeVibeGridCacheExtent(widget.itemWidth),
      ),
      addAutomaticKeepAlives: false,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: widget.columns,
        mainAxisSpacing: vibeLibraryGridSpacing,
        crossAxisSpacing: vibeLibraryGridSpacing,
        childAspectRatio: 1.0,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isSelected = selectionState.selectedIds.contains(entry.id);

        return AgentResourceDragSource(
          reference: AgentChatResourceReference(
            kind: AgentChatResourceKind.vibeLibraryEntry,
            source: 'vibe_library',
            resourceId: entry.id,
            display: {'name': entry.displayName},
          ),
          child: VibeCard(
            entry: entry,
            width: widget.itemWidth,
            height: widget.itemWidth,
            isSelected: isSelected,
            showFavoriteIndicator: true,
            onTap: () {
              if (selectionState.isActive) {
                ref
                    .read(vibeLibrarySelectionNotifierProvider.notifier)
                    .toggle(entry.id);
              } else {
                _showVibeDetail(context, entry);
              }
            },
            onLongPress: () {
              if (!selectionState.isActive) {
                ref
                    .read(vibeLibrarySelectionNotifierProvider.notifier)
                    .enterAndSelect(entry.id);
              }
            },
            onSecondaryTapDown: (details) {
              _showContextMenu(context, entry, details.globalPosition);
            },
            onFavoriteToggle: () {
              ref
                  .read(vibeLibraryNotifierProvider.notifier)
                  .toggleFavorite(entry.id);
            },
            onSendToGeneration: () async {
              final physicalKeys =
                  HardwareKeyboard.instance.physicalKeysPressed;
              final isShiftPressed =
                  physicalKeys.contains(PhysicalKeyboardKey.shiftLeft) ||
                  physicalKeys.contains(PhysicalKeyboardKey.shiftRight);
              await _sendEntryToGeneration(context, entry, isShiftPressed);
            },
            onExport: () => unawaited(_exportSingleEntry(context, entry)),
            onEdit: () => _showVibeDetail(context, entry),
            onDelete: () => _deleteSingleEntry(context, entry),
          ),
        );
      },
    );
  }

  /// 显示 Vibe 详情
  Future<void> _showVibeDetail(
    BuildContext context,
    VibeLibraryEntry entry,
  ) async {
    final span = VibePerformanceDiagnostics.start(
      'content.detailOpen',
      details: {'entryId': entry.id, 'isBundle': entry.isBundle},
    );
    var resolved = false;
    final storage = ref.read(vibeLibraryStorageServiceProvider);
    try {
      final detailDataFuture = resolveVibeDetailDataForOpen(storage, entry);

      VibeDetailViewer.show(
        context,
        entry: entry,
        detailDataFuture: detailDataFuture,
        heroTag: 'vibe_${entry.id}',
        callbacks: VibeDetailCallbacks(
          onSendToGeneration:
              (
                entry,
                strength,
                infoExtracted,
                isShiftPressed, {
                required bool applyParamOverrides,
                int? bundleChildParamOverrideIndex,
              }) async {
                await _sendEntryToGenerationWithParams(
                  context,
                  entry,
                  strength,
                  infoExtracted,
                  isShiftPressed,
                  applyParamOverrides: applyParamOverrides,
                  bundleChildParamOverrideIndex: bundleChildParamOverrideIndex,
                );
              },
          onExport: (entry) {
            unawaited(_exportSingleEntry(context, entry));
          },
          onDelete: (entry) {
            _deleteSingleEntry(context, entry);
          },
          onRename: (entry, newName) {
            return _renameSingleEntry(context, entry, newName);
          },
          onSaveParams:
              (entry, strength, infoExtracted, bundleChildIndex) async {
                return _updateEntryParams(
                  context,
                  entry,
                  strength,
                  infoExtracted,
                  bundleChildIndex: bundleChildIndex,
                );
              },
        ),
      );
      await detailDataFuture;
      resolved = true;
    } finally {
      span.finish(details: {'resolved': resolved});
    }
  }

  /// 显示上下文菜单
  void _showContextMenu(
    BuildContext context,
    VibeLibraryEntry entry,
    Offset position,
  ) {
    final l10n = context.l10n;
    final items = <ProMenuItem>[
      ProMenuItem(
        id: 'add_to_agent',
        label: l10n.agentChat_addResource,
        icon: Icons.auto_awesome_outlined,
        onTap: () => unawaited(_addEntryToAgent(context, entry)),
      ),
      ProMenuItem(
        id: 'send_to_generation',
        label: l10n.vibeLibrary_sendToGeneration,
        icon: Icons.send,
        onTap: () async => _sendEntryToGeneration(context, entry),
      ),
      ProMenuItem(
        id: 'export',
        label: l10n.vibeLibrary_export,
        icon: Icons.download,
        onTap: () => unawaited(_exportSingleEntry(context, entry)),
      ),
      ProMenuItem(
        id: 'edit',
        label: l10n.vibeLibrary_edit,
        icon: Icons.edit,
        onTap: () => _showVibeDetail(context, entry),
      ),
      const ProMenuItem.divider(),
      ProMenuItem(
        id: 'toggle_favorite',
        label: entry.isFavorite
            ? l10n.vibeLibrary_removeFromFavorites
            : l10n.vibeLibrary_addToFavorites,
        icon: entry.isFavorite ? Icons.favorite : Icons.favorite_border,
        onTap: () {
          ref
              .read(vibeLibraryNotifierProvider.notifier)
              .toggleFavorite(entry.id);
        },
      ),
      ProMenuItem(
        id: 'delete',
        label: l10n.vibeLibrary_delete,
        icon: Icons.delete_outline,
        isDanger: true,
        onTap: () => _deleteSingleEntry(context, entry),
      ),
    ];

    Navigator.of(context).push(
      _ContextMenuRoute(
        position: position,
        items: items,
        onSelect: (item) {
          // Item onTap is already called
        },
      ),
    );
  }

  Future<void> _addEntryToAgent(
    BuildContext context,
    VibeLibraryEntry entry,
  ) async {
    try {
      await ref
          .read(agentChatNotifierProvider.notifier)
          .addPendingResource(
            AgentChatResourceReference(
              kind: AgentChatResourceKind.vibeLibraryEntry,
              source: 'vibe_library',
              resourceId: entry.id,
              display: {'name': entry.displayName},
            ),
          );
      if (context.mounted) {
        AppToast.success(context, context.l10n.agentChat_resourceAdded);
      }
    } on Object catch (error) {
      if (context.mounted) {
        AppToast.error(
          context,
          context.l10n.agentChat_addResourceFailed('$error'),
        );
      }
    }
  }

  /// 发送单个条目到生成页面
  Future<void> _sendEntryToGeneration(
    BuildContext context,
    VibeLibraryEntry entry, [
    bool isShiftPressed = false,
  ]) async {
    final span = VibePerformanceDiagnostics.start(
      'content.sendEntryToGeneration',
      details: {
        'entryId': entry.id,
        'isBundle': entry.isBundle,
        'isShiftPressed': isShiftPressed,
      },
    );
    var hydrated = false;
    var bundleParsed = false;
    var sentVibeCount = 0;
    var abortedReason = '';
    try {
      final storage = ref.read(vibeLibraryStorageServiceProvider);
      final actualEntry = await storage.getEntry(entry.id) ?? entry;
      hydrated = true;
      final paramsNotifier = ref.read(
        generationParamsNotifierProvider.notifier,
      );
      final currentParams = ref.read(generationParamsNotifierProvider);

      // 处理 Bundle 条目：从文件读取所有 vibes
      if (actualEntry.isBundle &&
          actualEntry.filePath != null &&
          actualEntry.filePath!.isNotEmpty) {
        final file = File(actualEntry.filePath!);
        if (await file.exists()) {
          try {
            final bytes = await file.readAsBytes();
            final fileName = p.basename(actualEntry.filePath!);
            final vibes = await VibeFileParser.fromBundle(fileName, bytes);
            bundleParsed = true;

            final adjustedVibes = buildBundleVibesForGeneration(
              vibes,
              bundleSource: actualEntry.displayName,
            );

            // 检查是否超过16个限制（仅在追加模式下检查）
            if (!isShiftPressed &&
                currentParams.vibeReferencesV4.length + adjustedVibes.length >
                    16) {
              abortedReason = 'maxVibesReached';
              if (context.mounted) {
                AppToast.warning(
                  context,
                  context.l10n.vibeLibrary_maxVibesReached,
                );
              }
              return;
            }

            if (isShiftPressed) {
              // Shift+点击：替换现有 vibes
              paramsNotifier.setVibeReferences(adjustedVibes);
            } else {
              // 普通点击：追加 vibes
              paramsNotifier.addVibeReferences(
                adjustedVibes,
                recordUsage: false,
              );
            }
            sentVibeCount = adjustedVibes.length;

            ref
                .read(vibeLibraryNotifierProvider.notifier)
                .recordUsage(actualEntry.id);
            if (context.mounted) {
              final message = isShiftPressed
                  ? context.l10n.toast_replacedVibesCount(
                      adjustedVibes.length,
                      actualEntry.displayName,
                    )
                  : context.l10n.toast_sentVibesCount(
                      adjustedVibes.length,
                      actualEntry.displayName,
                    );
              AppToast.success(context, message);
              context.go(AppRoutes.home);
            }
            return;
          } catch (e, stackTrace) {
            AppLogger.e(
              '读取 Bundle 文件失败: ${actualEntry.filePath}',
              e,
              stackTrace,
              'VibeLibrary',
            );
            if (context.mounted) {
              AppToast.warning(
                context,
                context.l10n.vibeLibrary_bundleReadFailed,
              );
            }
            // 回退到单个 vibe 处理
          }
        }
      }

      // 检查是否超过16个限制（仅在追加模式下检查）
      if (!isShiftPressed && currentParams.vibeReferencesV4.length >= 16) {
        abortedReason = 'maxVibesReached';
        if (context.mounted) {
          AppToast.warning(context, context.l10n.vibeLibrary_maxVibesReached);
        }
        return;
      }

      // 普通条目或 Bundle 文件不存在时，使用单个 vibe
      final vibeReference = actualEntry.toVibeReference();
      if (isShiftPressed) {
        // Shift+点击：替换现有 vibes
        paramsNotifier.setVibeReferences([vibeReference]);
      } else {
        // 普通点击：追加 vibes
        paramsNotifier.addVibeReferences([vibeReference], recordUsage: false);
      }
      sentVibeCount = 1;

      ref
          .read(vibeLibraryNotifierProvider.notifier)
          .recordUsage(actualEntry.id);
      if (context.mounted) {
        final message = isShiftPressed
            ? context.l10n.toast_replacedVibe(actualEntry.displayName)
            : context.l10n.toast_sentVibeToGeneration(actualEntry.displayName);
        AppToast.success(context, message);
        context.go(AppRoutes.home);
      }
    } finally {
      span.finish(
        details: {
          'hydrated': hydrated,
          'bundleParsed': bundleParsed,
          'sentVibes': sentVibeCount,
          'abortedReason': abortedReason,
        },
      );
    }
  }

  /// 发送单个条目到生成页面（带参数）
  Future<void> _sendEntryToGenerationWithParams(
    BuildContext context,
    VibeLibraryEntry entry,
    double strength,
    double infoExtracted,
    bool isShiftPressed, {
    required bool applyParamOverrides,
    int? bundleChildParamOverrideIndex,
  }) async {
    final span = VibePerformanceDiagnostics.start(
      'content.sendEntryToGenerationWithParams',
      details: {
        'entryId': entry.id,
        'isBundle': entry.isBundle,
        'isShiftPressed': isShiftPressed,
      },
    );
    var bundleParsed = false;
    var sentVibeCount = 0;
    var abortedReason = '';
    try {
      final paramsNotifier = ref.read(
        generationParamsNotifierProvider.notifier,
      );
      final currentParams = ref.read(generationParamsNotifierProvider);

      // 检查是否超过16个限制（仅在追加模式下检查）
      if (!isShiftPressed && currentParams.vibeReferencesV4.length >= 16) {
        abortedReason = 'maxVibesReached';
        AppToast.warning(context, context.l10n.vibeLibrary_maxVibesReached);
        return;
      }

      // 处理 Bundle 条目：从文件读取所有 vibes
      if (entry.isBundle &&
          entry.filePath != null &&
          entry.filePath!.isNotEmpty) {
        final file = File(entry.filePath!);
        if (await file.exists()) {
          try {
            final bytes = await file.readAsBytes();
            final fileName = p.basename(entry.filePath!);
            final vibes = await VibeFileParser.fromBundle(fileName, bytes);
            bundleParsed = true;

            final adjustedVibes = buildBundleVibesForGeneration(
              vibes,
              bundleSource: entry.displayName,
              strengthOverride: applyParamOverrides ? strength : null,
              infoExtractedOverride: applyParamOverrides ? infoExtracted : null,
              overrideIndex: bundleChildParamOverrideIndex,
            );

            // 检查是否超过16个限制（仅在追加模式下检查）
            if (!isShiftPressed &&
                currentParams.vibeReferencesV4.length + adjustedVibes.length >
                    16) {
              abortedReason = 'maxVibesReached';
              if (context.mounted) {
                AppToast.warning(
                  context,
                  context.l10n.vibeLibrary_maxVibesReached,
                );
              }
              return;
            }

            if (isShiftPressed) {
              paramsNotifier.setVibeReferences(adjustedVibes);
            } else {
              paramsNotifier.addVibeReferences(
                adjustedVibes,
                recordUsage: false,
              );
            }
            sentVibeCount = adjustedVibes.length;
            ref
                .read(vibeLibraryNotifierProvider.notifier)
                .recordUsage(entry.id);
            if (context.mounted) {
              final message = isShiftPressed
                  ? context.l10n.toast_replacedVibesCount(
                      adjustedVibes.length,
                      entry.displayName,
                    )
                  : context.l10n.toast_sentVibesCount(
                      adjustedVibes.length,
                      entry.displayName,
                    );
              AppToast.success(context, message);
              context.go(AppRoutes.home);
            }
            return;
          } catch (e, stackTrace) {
            AppLogger.e(
              '读取 Bundle 文件失败: ${entry.filePath}',
              e,
              stackTrace,
              'VibeLibrary',
            );
            if (context.mounted) {
              AppToast.warning(
                context,
                context.l10n.vibeLibrary_bundleReadFailed,
              );
            }
            // 回退到单个 vibe 处理
          }
        }
      }

      // 普通条目或 Bundle 文件不存在时，使用单个 vibe
      final vibeRef = applyParamOverrides
          ? entry.toVibeReference().copyWith(
              strength: strength,
              infoExtracted: infoExtracted,
            )
          : entry.toVibeReference();

      if (isShiftPressed) {
        paramsNotifier.setVibeReferences([vibeRef]);
      } else {
        paramsNotifier.addVibeReferences([vibeRef], recordUsage: false);
      }
      sentVibeCount = 1;
      ref.read(vibeLibraryNotifierProvider.notifier).recordUsage(entry.id);
      if (context.mounted) {
        final message = isShiftPressed
            ? context.l10n.toast_replacedVibe(entry.displayName)
            : context.l10n.toast_sentVibeToGeneration(entry.displayName);
        AppToast.success(context, message);
        context.go(AppRoutes.home);
      }
    } finally {
      span.finish(
        details: {
          'bundleParsed': bundleParsed,
          'sentVibes': sentVibeCount,
          'abortedReason': abortedReason,
        },
      );
    }
  }

  /// 导出单个条目
  Future<void> _exportSingleEntry(
    BuildContext context,
    VibeLibraryEntry entry,
  ) async {
    final span = VibePerformanceDiagnostics.start(
      'content.exportSingleEntry',
      details: {'entryId': entry.id, 'isBundle': entry.isBundle},
    );
    var hydrated = false;
    var categoryCount = 0;
    try {
      final storage = ref.read(vibeLibraryStorageServiceProvider);
      final actualEntry = await storage.getEntry(entry.id) ?? entry;
      hydrated = true;
      if (!mounted || !context.mounted) {
        return;
      }
      final categories = ref
          .read(vibeLibraryCategoryNotifierProvider)
          .categories;
      categoryCount = categories.length;

      showDialog<void>(
        context: context,
        builder: (context) =>
            VibeExportDialog(entries: [actualEntry], categories: categories),
      );
    } finally {
      span.finish(details: {'hydrated': hydrated, 'categories': categoryCount});
    }
  }

  /// 删除单个条目
  Future<void> _deleteSingleEntry(
    BuildContext context,
    VibeLibraryEntry entry,
  ) async {
    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: context.l10n.common_confirmDelete,
      content: context.l10n.common_deleteItemConfirm(entry.displayName),
      confirmText: context.l10n.common_delete,
      cancelText: context.l10n.common_cancel,
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_forever_outlined,
    );

    if (confirmed) {
      final deleted = await ref
          .read(vibeLibraryNotifierProvider.notifier)
          .deleteEntry(entry.id);
      if (deleted && context.mounted) {
        AppToast.success(
          context,
          context.l10n.toast_deletedNamed(entry.displayName),
        );
      }
    }
  }

  /// 重命名单个条目
  Future<String?> _renameSingleEntry(
    BuildContext context,
    VibeLibraryEntry entry,
    String newName,
  ) async {
    final l10n = context.l10n;
    final trimmedName = newName.trim();
    if (trimmedName.isEmpty) {
      return l10n.toast_renameNameRequired;
    }

    final result = await ref
        .read(vibeLibraryNotifierProvider.notifier)
        .renameEntry(entry.id, trimmedName);
    if (result.isSuccess) {
      return null;
    }

    switch (result.error) {
      case VibeEntryRenameError.invalidName:
        return l10n.toast_renameNameRequired;
      case VibeEntryRenameError.nameConflict:
        return l10n.toast_renameNameConflict;
      case VibeEntryRenameError.entryNotFound:
        return l10n.toast_renameEntryNotFound;
      case VibeEntryRenameError.filePathMissing:
        return l10n.toast_renameFilePathMissing;
      case VibeEntryRenameError.fileRenameFailed:
        return l10n.toast_renameFileFailed;
      case null:
        return l10n.toast_renameFailed;
    }
  }

  /// 更新条目参数
  Future<VibeLibraryEntry?> _updateEntryParams(
    BuildContext context,
    VibeLibraryEntry entry,
    double strength,
    double infoExtracted, {
    int? bundleChildIndex,
  }) async {
    if (entry.isBundle) {
      if (bundleChildIndex == null || bundleChildIndex < 0) {
        return null;
      }
      final filePath = entry.filePath;
      if (filePath == null || filePath.isEmpty) {
        return null;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        return null;
      }

      final bytes = await file.readAsBytes();
      final childVibes = await VibeFileParser.fromBundle(
        p.basename(filePath),
        bytes,
      );
      if (bundleChildIndex >= childVibes.length) {
        return null;
      }

      final generationParams = ref.read(generationParamsNotifierProvider);
      final preparedVibeData = await ref
          .read(generationParamsNotifierProvider.notifier)
          .prepareVibeForLibraryParamSave(
            childVibes[bundleChildIndex],
            strength: strength,
            infoExtracted: infoExtracted,
            model: generationParams.model,
          );
      if (preparedVibeData == null) {
        if (context.mounted) {
          AppToast.error(
            context,
            context.l10n.toast_vibeParamSaveReencodeFailed,
          );
        }
        return null;
      }

      return ref
          .read(vibeLibraryNotifierProvider.notifier)
          .saveBundleChildParams(
            entry.id,
            childIndex: bundleChildIndex,
            strength: strength,
            infoExtracted: infoExtracted,
            persistedVibeData: preparedVibeData,
          );
    }

    final generationParams = ref.read(generationParamsNotifierProvider);
    final preparedVibeData = await ref
        .read(generationParamsNotifierProvider.notifier)
        .prepareVibeForLibraryParamSave(
          entry.toVibeReference(),
          strength: strength,
          infoExtracted: infoExtracted,
          model: generationParams.model,
        );
    if (preparedVibeData == null) {
      if (context.mounted) {
        AppToast.error(context, context.l10n.toast_vibeParamSaveReencodeFailed);
      }
      return null;
    }

    return ref
        .read(vibeLibraryNotifierProvider.notifier)
        .saveEntryParams(
          entry.id,
          strength: strength,
          infoExtracted: infoExtracted,
          persistedVibeData: preparedVibeData,
        );
  }

  /// 获取空状态提示信息
  EmptyStateInfo _getEmptyStateInfo(VibeLibraryState state) {
    // 搜索无结果
    if (state.searchQuery.isNotEmpty) {
      return EmptyStateInfo.searchNoResults();
    }

    // 收藏无结果
    if (state.favoritesOnly) {
      return EmptyStateInfo.noFavorites();
    }

    // 分类无结果
    if (state.selectedCategoryId != null) {
      return EmptyStateInfo.noItemsInCategory();
    }

    // 默认无结果
    return EmptyStateInfo.defaultEmpty();
  }
}

double computeVibeGridCacheExtent(double itemWidth) => itemWidth * 1.5;

Future<VibeLibraryDetailData> resolveVibeDetailDataForOpen(
  VibeLibraryStorageService storage,
  VibeLibraryEntry entry,
) async {
  try {
    return await VibePerformanceDiagnostics.measure(
      'content.resolveVibeDetailDataForOpen',
      () async =>
          await storage.getDetailData(entry.id) ??
          VibeLibraryDetailData(entry: entry),
      details: {'entryId': entry.id, 'isBundle': entry.isBundle},
      resultDetails: (data) => {
        'resolvedId': data.entry.id,
        'bundleVibes': data.bundleVibes.length,
      },
    );
  } catch (error, stackTrace) {
    AppLogger.e(
      'Failed to resolve Vibe detail data',
      error,
      stackTrace,
      'VibeLibraryContent',
    );
    return VibeLibraryDetailData(entry: entry);
  }
}

List<VibeReference> buildBundleVibesForGeneration(
  List<VibeReference> vibes, {
  required String bundleSource,
  double? strengthOverride,
  double? infoExtractedOverride,
  int? overrideIndex,
}) {
  return vibes.indexed
      .map((item) {
        final (index, vibe) = item;
        var next = vibe.copyWith(bundleSource: bundleSource);
        final shouldOverride =
            (strengthOverride != null || infoExtractedOverride != null) &&
            (overrideIndex == null || overrideIndex == index);
        if (shouldOverride) {
          next = next.copyWith(
            strength: strengthOverride ?? next.strength,
            infoExtracted: infoExtractedOverride ?? next.infoExtracted,
          );
        }
        return next;
      })
      .toList(growable: false);
}

/// 自定义上下文菜单路由
class _ContextMenuRoute extends PopupRoute {
  final Offset position;
  final List<ProMenuItem> items;
  final void Function(ProMenuItem) onSelect;

  _ContextMenuRoute({
    required this.position,
    required this.items,
    required this.onSelect,
  });

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => null;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      removeLeft: true,
      removeRight: true,
      removeBottom: true,
      child: Builder(
        builder: (context) {
          // 计算调整后的位置以保持菜单在屏幕边界内
          final screenSize = MediaQuery.of(context).size;
          const menuWidth = 180.0;
          final menuHeight =
              items.where((i) => !i.isDivider).length * 36.0 +
              items.where((i) => i.isDivider).length * 1.0;

          double left = position.dx;
          double top = position.dy;

          // 调整水平位置，如果菜单超出屏幕
          if (left + menuWidth > screenSize.width) {
            left = screenSize.width - menuWidth - 16;
          }

          // 调整垂直位置，如果菜单超出屏幕
          if (top + menuHeight > screenSize.height) {
            top = screenSize.height - menuHeight - 16;
          }

          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => Navigator.of(context).pop(),
            child: Stack(
              children: [
                ProContextMenu(
                  position: Offset(left, top),
                  items: items,
                  onSelect: (item) {
                    onSelect(item);
                    Navigator.of(context).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      item.onTap?.call();
                    });
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Duration get transitionDuration => Duration.zero;
}
