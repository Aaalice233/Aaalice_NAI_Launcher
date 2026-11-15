import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../adaptive/adaptive_presenter.dart';
import '../core/editor_state.dart';
import '../frame/editor_frame_controller.dart';
import '../tools/tool_base.dart';
import '../widgets/panels/editor_compression_controls.dart';
import '../widgets/panels/layer_panel.dart';
import '../widgets/toolbar/editor_overflow_menu.dart';
import '../widgets/toolbar/mobile_toolbar.dart';

/// 移动端与紧凑窗口工作区布局：自适应顶栏、画布、限高工具设置与底部工具栏。
class WorkspaceMobileLayout extends StatelessWidget {
  const WorkspaceMobileLayout({
    super.key,
    required this.availableWidth,
    required this.title,
    required this.completionLabel,
    required this.state,
    required this.isInpaintMode,
    required this.frameController,
    required this.canExportAndClose,
    required this.buildCanvasArea,
    required this.onShowLayerSheet,
    required this.onShowCompressionSheet,
    required this.onLoadMask,
    required this.onShowShiftEdgesDialog,
    required this.onCropToFrame,
    required this.onShowEffectsDialog,
    required this.onExportAndClose,
    required this.onResetInpaintMask,
  });

  final double availableWidth;
  final String title;
  final String? completionLabel;
  final EditorState state;
  final bool isInpaintMode;
  final EditorFrameController frameController;
  final bool Function() canExportAndClose;
  final Widget Function() buildCanvasArea;
  final VoidCallback onShowLayerSheet;
  final Future<void> Function() onShowCompressionSheet;
  final Future<void> Function() onLoadMask;
  final Future<void> Function() onShowShiftEdgesDialog;
  final Future<void> Function() onCropToFrame;
  final Future<void> Function() onShowEffectsDialog;
  final VoidCallback onExportAndClose;
  final VoidCallback onResetInpaintMask;

  List<EditorMenuAction> _mobileCanvasMenuActions(BuildContext context) {
    final l10n = context.l10n;
    return [
      EditorMenuAction(
        icon: Icons.compress,
        label: l10n.editor_compressionTooltip,
        onSelected: () => unawaited(onShowCompressionSheet()),
      ),
      if (isInpaintMode) ...[
        EditorMenuAction(
          icon: Icons.upload_file,
          label: l10n.editor_loadMask,
          onSelected: () => unawaited(onLoadMask()),
        ),
        EditorMenuAction(
          icon: Icons.open_in_full,
          label: l10n.editor_shiftEdges,
          onSelected: () => unawaited(onShowShiftEdgesDialog()),
        ),
        EditorMenuAction(
          icon: Icons.crop,
          label: l10n.editor_cropToFrame,
          enabled: frameController.canCropToFrame,
          onSelected: () => unawaited(onCropToFrame()),
        ),
      ] else
        EditorMenuAction(
          icon: Icons.tune_rounded,
          label: l10n.editor_effects,
          onSelected: () => unawaited(onShowEffectsDialog()),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final compactActions = availableWidth < 520;
    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (!compactActions)
            MobileCompressionAction(onPressed: onShowCompressionSheet),
          IconButton(
            icon: const Icon(Icons.layers),
            onPressed: onShowLayerSheet,
            tooltip: context.l10n.editor_layers,
          ),
          if (!compactActions && isInpaintMode)
            IconButton(
              icon: const Icon(Icons.upload_file),
              onPressed: onLoadMask,
              tooltip: context.l10n.editor_loadMask,
            ),
          if (!compactActions && isInpaintMode)
            IconButton(
              icon: const Icon(Icons.open_in_full),
              onPressed: onShowShiftEdgesDialog,
              tooltip: context.l10n.editor_shiftEdges,
            ),
          if (!compactActions && isInpaintMode)
            ListenableBuilder(
              listenable: frameController,
              builder: (context, _) => IconButton(
                icon: const Icon(Icons.crop),
                onPressed: frameController.canCropToFrame
                    ? onCropToFrame
                    : null,
                tooltip: context.l10n.editor_cropToFrame,
              ),
            ),
          if (!compactActions && !isInpaintMode)
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              onPressed: onShowEffectsDialog,
              tooltip: context.l10n.editor_effects,
            ),
          // 视图分组始终可达；画布操作只在顶栏放不下时收进菜单
          EditorOverflowMenu(
            state: state,
            canvasActions: compactActions
                ? () => _mobileCanvasMenuActions(context)
                : null,
          ),
          ListenableBuilder(
            listenable: frameController,
            builder: (context, _) => IconButton(
              icon: const Icon(Icons.check),
              onPressed: canExportAndClose() ? onExportAndClose : null,
              tooltip: completionLabel ?? context.l10n.editor_done,
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (layoutContext, constraints) => Column(
            children: [
              // 画布区域
              Expanded(child: buildCanvasArea()),

              // 横屏短窗口保留画布主区域，设置面板仍可独立滚动。
              _MobileToolSettingsPanel(
                state: state,
                maxHeight: constraints.maxHeight < 420 ? 96 : 150,
              ),

              // 底部工具栏
              MobileToolbar(
                state: state,
                onClear: isInpaintMode ? onResetInpaintMask : null,
                onLayersPressed: onShowLayerSheet,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 移动端工具设置：使用 toolChangeNotifier 实现细粒度监听。
class _MobileToolSettingsPanel extends StatelessWidget {
  const _MobileToolSettingsPanel({
    required this.state,
    required this.maxHeight,
  });

  final EditorState state;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<EditorTool?>(
      valueListenable: state.toolChangeNotifier,
      builder: (context, tool, _) {
        if (tool == null) return const SizedBox.shrink();

        return Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            child: tool.buildSettingsPanel(context, state),
          ),
        );
      },
    );
  }
}

/// 显示移动端图层面板。
Future<void> showWorkspaceMobileLayerSheet(
  BuildContext context,
  EditorState state,
) {
  return AdaptivePresenter.showPanel<void>(
    context: context,
    title: context.l10n.editor_layers,
    initialChildSize: 0.62,
    builder: (sheetContext, scrollController) => PrimaryScrollController(
      controller: scrollController,
      child: LayerPanel(
        state: state,
        // 收起弹层露出画布上的变换框
        onImageImported: () => Navigator.of(sheetContext).maybePop(),
      ),
    ),
  );
}
