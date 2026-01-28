import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/image_save_settings_provider.dart';
import '../../../widgets/common/app_toast.dart';
import '../../../widgets/common/selectable_image_card.dart';
import '../../../widgets/common/themed_confirm_dialog.dart';
import '../../../widgets/common/themed_divider.dart';

/// 历史面板组件
class HistoryPanel extends ConsumerStatefulWidget {
  const HistoryPanel({super.key});

  @override
  ConsumerState<HistoryPanel> createState() => _HistoryPanelState();
}

class _HistoryPanelState extends ConsumerState<HistoryPanel> {
  final Set<int> _selectedIndices = {};

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(imageGenerationNotifierProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题栏
        Padding(
          padding:
              const EdgeInsets.only(left: 36, right: 12, top: 12, bottom: 12),
          child: Row(
            children: [
              Text(
                context.l10n.generation_historyRecord,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (state.history.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${state.history.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              // 全选按钮
              if (state.history.isNotEmpty)
                IconButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedIndices.length == state.history.length) {
                        _selectedIndices.clear();
                      } else {
                        _selectedIndices.clear();
                        _selectedIndices.addAll(
                          List.generate(state.history.length, (i) => i),
                        );
                      }
                    });
                  },
                  icon: Icon(
                    _selectedIndices.length == state.history.length
                        ? Icons.deselect
                        : Icons.select_all,
                    size: 20,
                  ),
                  tooltip: _selectedIndices.length == state.history.length
                      ? context.l10n.common_deselectAll
                      : context.l10n.common_selectAll,
                  style: IconButton.styleFrom(
                    foregroundColor: theme.colorScheme.primary,
                  ),
                ),
              if (state.history.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    _showClearDialog(context, ref);
                  },
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: Text(context.l10n.common_clear),
                  style: TextButton.styleFrom(
                    foregroundColor: theme.colorScheme.error,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
            ],
          ),
        ),
        const ThemedDivider(height: 1),

        // 历史列表
        Expanded(
          child: state.history.isEmpty
              ? _buildEmptyState(theme, context)
              : _buildHistoryGrid(state.history, theme),
        ),

        // 底部操作栏（有选中时显示）
        if (_selectedIndices.isNotEmpty)
          _buildBottomActions(context, state.history, theme),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme, BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 48,
            color: theme.colorScheme.onSurface.withOpacity(0.2),
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.generation_noHistory,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryGrid(List<Uint8List> history, ThemeData theme) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.75,
      ),
      itemCount: history.length,
      itemBuilder: (context, index) {
        return SelectableImageCard(
          imageBytes: history[index],
          index: index,
          showIndex: false,
          isSelected: _selectedIndices.contains(index),
          onSelectionChanged: (selected) {
            setState(() {
              if (selected) {
                _selectedIndices.add(index);
              } else {
                _selectedIndices.remove(index);
              }
            });
          },
          onFullscreen: () => _showFullscreen(context, history[index]),
          enableContextMenu: true,
          enableHoverScale: true,
          onOpenInExplorer: () =>
              _saveAndOpenInExplorer(context, history[index]),
        );
      },
    );
  }

  Widget _buildBottomActions(
    BuildContext context,
    List<Uint8List> history,
    ThemeData theme,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border:
            Border(top: BorderSide(color: theme.dividerColor.withOpacity(0.3))),
      ),
      child: FilledButton.icon(
        onPressed: () => _saveSelectedImages(context, history),
        icon: const Icon(Icons.save_alt, size: 20),
        label: Text('${context.l10n.image_save} (${_selectedIndices.length})'),
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 44),
        ),
      ),
    );
  }

  Future<void> _saveSelectedImages(
    BuildContext context,
    List<Uint8List> history,
  ) async {
    if (_selectedIndices.isEmpty) return;

    try {
      // 优先使用设置中的自定义路径
      final saveSettings = ref.read(imageSaveSettingsNotifierProvider);
      Directory saveDir;

      if (saveSettings.hasCustomPath) {
        saveDir = Directory(saveSettings.customPath!);
        if (!await saveDir.exists()) {
          await saveDir.create(recursive: true);
        }
      } else {
        final docDir = await getApplicationDocumentsDirectory();
        saveDir = Directory('${docDir.path}/NAI_Launcher');
        if (!await saveDir.exists()) {
          await saveDir.create(recursive: true);
        }
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final sortedIndices = _selectedIndices.toList()..sort();

      for (int i = 0; i < sortedIndices.length; i++) {
        final index = sortedIndices[i];
        final fileName = 'NAI_${timestamp}_${i + 1}.png';
        final file = File('${saveDir.path}/$fileName');
        await file.writeAsBytes(history[index]);
      }

      if (context.mounted) {
        AppToast.success(context, context.l10n.image_imageSaved(saveDir.path));
        setState(() {
          _selectedIndices.clear();
        });
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, context.l10n.image_saveFailed(e.toString()));
      }
    }
  }

  /// 保存图片并在文件夹中打开
  Future<void> _saveAndOpenInExplorer(
    BuildContext context,
    Uint8List imageBytes,
  ) async {
    try {
      // 获取保存目录
      final saveSettings = ref.read(imageSaveSettingsNotifierProvider);
      Directory saveDir;

      if (saveSettings.hasCustomPath) {
        saveDir = Directory(saveSettings.customPath!);
        if (!await saveDir.exists()) {
          await saveDir.create(recursive: true);
        }
      } else {
        final docDir = await getApplicationDocumentsDirectory();
        saveDir = Directory('${docDir.path}/NAI_Launcher');
        if (!await saveDir.exists()) {
          await saveDir.create(recursive: true);
        }
      }

      // 保存图片
      final fileName = 'NAI_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${saveDir.path}/$fileName');
      await file.writeAsBytes(imageBytes);

      // 在文件夹中打开并选中文件
      await Process.start('explorer', ['/select,${file.path}']);

      if (context.mounted) {
        AppToast.success(context, context.l10n.image_imageSaved(saveDir.path));
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, context.l10n.image_saveFailed(e.toString()));
      }
    }
  }

  void _showFullscreen(BuildContext context, Uint8List imageBytes) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black87,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _FullscreenImageView(imageBytes: imageBytes);
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  void _showClearDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: context.l10n.generation_clearHistory,
      content: context.l10n.generation_clearHistoryConfirm,
      confirmText: context.l10n.common_clear,
      cancelText: context.l10n.common_cancel,
      type: ThemedConfirmDialogType.danger,
      icon: Icons.delete_sweep_outlined,
    );

    if (confirmed) {
      ref.read(imageGenerationNotifierProvider.notifier).clearHistory();
      setState(() {
        _selectedIndices.clear();
      });
    }
  }
}

/// 沉浸式全屏图像查看器
class _FullscreenImageView extends ConsumerStatefulWidget {
  final Uint8List imageBytes;

  const _FullscreenImageView({required this.imageBytes});

  @override
  ConsumerState<_FullscreenImageView> createState() =>
      _FullscreenImageViewState();
}

class _FullscreenImageViewState extends ConsumerState<_FullscreenImageView> {
  final TransformationController _transformController =
      TransformationController();

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  void _close() {
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 背景 + 图像（点击关闭）
          GestureDetector(
            onTap: _close,
            child: Container(
              color: Colors.black.withOpacity(0.95),
              child: InteractiveViewer(
                transformationController: _transformController,
                minScale: 0.5,
                maxScale: 5.0,
                child: Center(
                  child: Image.memory(
                    widget.imageBytes,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),

          // 左上角返回按钮
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: _buildControlButton(
              icon: Icons.arrow_back_rounded,
              onTap: _close,
              tooltip: context.l10n.common_back,
            ),
          ),

          // 右上角保存按钮
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: _buildControlButton(
              icon: Icons.save_alt_rounded,
              onTap: () => _saveImage(context),
              tooltip: context.l10n.image_save,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _saveImage(BuildContext context) async {
    try {
      // 优先使用设置中的自定义路径
      final saveSettings = ref.read(imageSaveSettingsNotifierProvider);
      Directory saveDir;

      if (saveSettings.hasCustomPath) {
        saveDir = Directory(saveSettings.customPath!);
        if (!await saveDir.exists()) {
          await saveDir.create(recursive: true);
        }
      } else {
        final docDir = await getApplicationDocumentsDirectory();
        saveDir = Directory('${docDir.path}/NAI_Launcher');
        if (!await saveDir.exists()) {
          await saveDir.create(recursive: true);
        }
      }

      final fileName = 'NAI_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${saveDir.path}/$fileName');
      await file.writeAsBytes(widget.imageBytes);

      if (context.mounted) {
        AppToast.success(context, context.l10n.image_imageSaved(saveDir.path));
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, context.l10n.image_saveFailed(e.toString()));
      }
    }
  }
}
