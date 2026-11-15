import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../common/themed_divider.dart';
import '../controllers/editor_compression_controller.dart';
import '../core/editor_state.dart';
import '../frame/editor_frame_controller.dart';
import '../tools/tool_base.dart';
import '../widgets/editor_status_bar.dart';
import '../widgets/panels/color_panel.dart';
import '../widgets/panels/editor_compression_controls.dart';
import '../widgets/panels/layer_panel.dart';
import '../widgets/toolbar/desktop_toolbar.dart';

/// 桌面端工作区整体布局：顶栏、左侧工具栏、中央画布与状态栏、右侧三段面板。
class WorkspaceDesktopLayout extends StatelessWidget {
  const WorkspaceDesktopLayout({
    super.key,
    required this.availableWidth,
    required this.title,
    required this.completionLabel,
    required this.state,
    required this.isInpaintMode,
    required this.showLayerPanel,
    required this.frameController,
    required this.compressionController,
    required this.canExportAndClose,
    required this.buildCanvasArea,
    required this.onConfirmExit,
    required this.onSelectCompressionTarget,
    required this.onShowCompressionSheet,
    required this.onShowEffectsDialog,
    required this.onChangeCanvasSize,
    required this.onLoadMask,
    required this.onShowShiftEdgesDialog,
    required this.onCropToFrame,
    required this.onToggleLayerPanel,
    required this.onShowShortcutHelp,
    required this.onExportAndClose,
    required this.onResetInpaintMask,
  });

  final double availableWidth;
  final String title;
  final String? completionLabel;
  final EditorState state;
  final bool isInpaintMode;
  final bool showLayerPanel;
  final EditorFrameController frameController;
  final EditorCompressionController compressionController;
  final bool Function() canExportAndClose;
  final Widget Function() buildCanvasArea;
  final VoidCallback onConfirmExit;
  final ValueChanged<int> onSelectCompressionTarget;
  final VoidCallback onShowCompressionSheet;
  final VoidCallback onShowEffectsDialog;
  final VoidCallback onChangeCanvasSize;
  final VoidCallback onLoadMask;
  final VoidCallback onShowShiftEdgesDialog;
  final VoidCallback onCropToFrame;
  final VoidCallback onToggleLayerPanel;
  final VoidCallback onShowShortcutHelp;
  final VoidCallback onExportAndClose;
  final VoidCallback onResetInpaintMask;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 顶部菜单栏
            WorkspaceDesktopMenuBar(
              availableWidth: availableWidth,
              title: title,
              completionLabel: completionLabel,
              state: state,
              isInpaintMode: isInpaintMode,
              showLayerPanel: showLayerPanel,
              frameController: frameController,
              compressionController: compressionController,
              canExportAndClose: canExportAndClose,
              onConfirmExit: onConfirmExit,
              onSelectCompressionTarget: onSelectCompressionTarget,
              onShowCompressionSheet: onShowCompressionSheet,
              onShowEffectsDialog: onShowEffectsDialog,
              onChangeCanvasSize: onChangeCanvasSize,
              onLoadMask: onLoadMask,
              onShowShiftEdgesDialog: onShowShiftEdgesDialog,
              onCropToFrame: onCropToFrame,
              onToggleLayerPanel: onToggleLayerPanel,
              onShowShortcutHelp: onShowShortcutHelp,
              onExportAndClose: onExportAndClose,
            ),

            // 主体区域
            Expanded(
              child: Row(
                children: [
                  // 左侧工具栏
                  DesktopToolbar(
                    state: state,
                    onClear: isInpaintMode ? onResetInpaintMask : null,
                  ),

                  // 中间画布区域
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(child: buildCanvasArea()),
                        // 底部状态栏
                        EditorStatusBar(state: state),
                      ],
                    ),
                  ),

                  // 右侧面板
                  if (showLayerPanel)
                    SizedBox(
                      width: 280,
                      child: Column(
                        children: [
                          // 图层面板
                          Expanded(flex: 2, child: LayerPanel(state: state)),
                          const ThemedDivider(height: 1),
                          // 工具设置面板
                          Expanded(
                            flex: 2,
                            child: _DesktopToolSettingsPanel(state: state),
                          ),
                          const ThemedDivider(height: 1),
                          // 颜色面板：蒙版层只用固定的蒙版色
                          if (!state.isMaskLayerActive)
                            ColorPanel(state: state),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 桌面端顶部操作栏。
class WorkspaceDesktopMenuBar extends StatelessWidget {
  const WorkspaceDesktopMenuBar({
    super.key,
    required this.availableWidth,
    required this.title,
    required this.completionLabel,
    required this.state,
    required this.isInpaintMode,
    required this.showLayerPanel,
    required this.frameController,
    required this.compressionController,
    required this.canExportAndClose,
    required this.onConfirmExit,
    required this.onSelectCompressionTarget,
    required this.onShowCompressionSheet,
    required this.onShowEffectsDialog,
    required this.onChangeCanvasSize,
    required this.onLoadMask,
    required this.onShowShiftEdgesDialog,
    required this.onCropToFrame,
    required this.onToggleLayerPanel,
    required this.onShowShortcutHelp,
    required this.onExportAndClose,
  });

  final double availableWidth;
  final String title;
  final String? completionLabel;
  final EditorState state;
  final bool isInpaintMode;
  final bool showLayerPanel;
  final EditorFrameController frameController;
  final EditorCompressionController compressionController;
  final bool Function() canExportAndClose;
  final VoidCallback onConfirmExit;
  final ValueChanged<int> onSelectCompressionTarget;
  final VoidCallback onShowCompressionSheet;
  final VoidCallback onShowEffectsDialog;
  final VoidCallback onChangeCanvasSize;
  final VoidCallback onLoadMask;
  final VoidCallback onShowShiftEdgesDialog;
  final VoidCallback onCropToFrame;
  final VoidCallback onToggleLayerPanel;
  final VoidCallback onShowShortcutHelp;
  final VoidCallback onExportAndClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.24),
          ),
        ),
      ),
      child: Row(
        children: [
          // 返回按钮
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: onConfirmExit,
            tooltip: context.l10n.editor_back,
          ),

          Text(title, style: theme.textTheme.titleSmall),

          const Spacer(),

          DesktopCompressionControl(
            plan: compressionController.plan,
            activeTarget: compressionController.activeTarget,
            clampedRequestSize: compressionController.clampedRequestSize,
            expanded: availableWidth >= 1700,
            onSelectTarget: onSelectCompressionTarget,
            onOpenSheet: onShowCompressionSheet,
          ),
          const SizedBox(width: 4),

          if (!isInpaintMode)
            if (availableWidth >= 1280)
              TextButton.icon(
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: Text(context.l10n.editor_effects),
                onPressed: onShowEffectsDialog,
              )
            else
              IconButton(
                icon: const Icon(Icons.tune_rounded, size: 20),
                onPressed: onShowEffectsDialog,
                tooltip: context.l10n.editor_effects,
              ),

          // 画布尺寸按钮（使用细粒度监听）
          TextButton.icon(
            icon: const Icon(Icons.aspect_ratio, size: 18),
            label: ValueListenableBuilder<Size>(
              valueListenable: state.canvasSizeNotifier,
              builder: (context, size, _) =>
                  Text('${size.width.toInt()} x ${size.height.toInt()}'),
            ),
            onPressed: onChangeCanvasSize,
          ),

          // 加载蒙版按钮
          if (isInpaintMode)
            IconButton(
              icon: const Icon(Icons.upload_file, size: 20),
              onPressed: onLoadMask,
              tooltip: context.l10n.editor_loadMask,
            ),

          if (isInpaintMode)
            if (availableWidth >= 1280)
              TextButton.icon(
                icon: const Icon(Icons.open_in_full, size: 18),
                label: Text(context.l10n.editor_shiftEdges),
                onPressed: onShowShiftEdgesDialog,
              )
            else
              IconButton(
                icon: const Icon(Icons.open_in_full, size: 20),
                onPressed: onShowShiftEdgesDialog,
                tooltip: context.l10n.editor_shiftEdges,
              ),

          if (isInpaintMode)
            ListenableBuilder(
              listenable: frameController,
              builder: (context, _) {
                final onPressed = frameController.canCropToFrame
                    ? onCropToFrame
                    : null;
                if (availableWidth >= 1280) {
                  return Tooltip(
                    message: context.l10n.editor_cropToFrameHint,
                    child: TextButton.icon(
                      icon: const Icon(Icons.crop, size: 18),
                      label: Text(context.l10n.editor_cropToFrame),
                      onPressed: onPressed,
                    ),
                  );
                }
                return IconButton(
                  icon: const Icon(Icons.crop, size: 20),
                  onPressed: onPressed,
                  tooltip: context.l10n.editor_cropToFrame,
                );
              },
            ),

          const ThemedDivider(
            height: 1,
            vertical: true,
            indent: 8,
            endIndent: 8,
          ),

          // 切换面板
          IconButton(
            icon: Icon(
              showLayerPanel ? Icons.view_sidebar : Icons.view_sidebar_outlined,
              size: 20,
            ),
            onPressed: onToggleLayerPanel,
            tooltip: context.l10n.editor_togglePanels,
          ),

          // 快捷键帮助
          IconButton(
            icon: const Icon(Icons.keyboard, size: 20),
            onPressed: onShowShortcutHelp,
            tooltip: context.l10n.editor_shortcutHelpTitle,
          ),

          const ThemedDivider(
            height: 1,
            vertical: true,
            indent: 8,
            endIndent: 8,
          ),

          // 导出按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ListenableBuilder(
              listenable: frameController,
              builder: (context, _) => FilledButton.icon(
                icon: const Icon(Icons.check, size: 18),
                label: Text(completionLabel ?? context.l10n.editor_done),
                onPressed: canExportAndClose() ? onExportAndClose : null,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 工具设置面板：使用 toolChangeNotifier 实现细粒度监听，仅在工具切换时重建。
class _DesktopToolSettingsPanel extends StatelessWidget {
  const _DesktopToolSettingsPanel({required this.state});

  final EditorState state;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EditorTool?>(
      valueListenable: state.toolChangeNotifier,
      builder: (context, tool, _) {
        if (tool == null) {
          return Center(child: Text(context.l10n.image_editor_select_tool));
        }
        return SingleChildScrollView(
          child: tool.buildSettingsPanel(context, state),
        );
      },
    );
  }
}
