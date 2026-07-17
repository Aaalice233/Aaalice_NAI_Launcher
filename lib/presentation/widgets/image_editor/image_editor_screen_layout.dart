part of 'image_editor_screen.dart';

extension _ImageEditorScreenLayout on _ImageEditorScreenState {
  /// 桌面端布局
  Widget _buildDesktopLayout() {
    return Scaffold(
      body: Column(
        children: [
          // 顶部菜单栏
          _buildDesktopMenuBar(),

          // 主体区域
          Expanded(
            child: Row(
              children: [
                // 左侧工具栏
                DesktopToolbar(
                  state: _state,
                  onClear: _isInpaintMode ? _resetInpaintMask : null,
                  onFillMask: _isInpaintMode
                      ? _handleFillClosedMaskRegions
                      : null,
                  canFillMask: _isInpaintMode ? _hasMaskContent : null,
                  allowedToolIds: _isInpaintMode
                      ? _ImageEditorScreenState._inpaintToolIds
                      : null,
                ),

                // 中间画布区域
                Expanded(
                  child: Column(
                    children: [
                      Expanded(child: _buildCanvasArea()),
                      // 底部状态栏
                      _buildStatusBar(),
                    ],
                  ),
                ),

                // 右侧面板
                if (_showLayerPanel)
                  SizedBox(
                    width: 280,
                    child: Column(
                      children: [
                        // 图层面板
                        Expanded(flex: 2, child: LayerPanel(state: _state)),
                        const ThemedDivider(height: 1),
                        // 工具设置面板
                        Expanded(flex: 2, child: _buildToolSettingsPanel()),
                        const ThemedDivider(height: 1),
                        // 颜色面板
                        if (!_isInpaintMode) ColorPanel(state: _state),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 移动端布局
  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editorTitle()),
        actions: [
          _buildMobileCompressionAction(),
          // 图层按钮
          IconButton(
            icon: const Icon(Icons.layers),
            onPressed: _showMobileLayerSheet,
            tooltip: context.l10n.editor_layers,
          ),
          // 加载蒙版按钮
          if (_isInpaintMode)
            IconButton(
              icon: const Icon(Icons.upload_file),
              onPressed: _loadMask,
              tooltip: context.l10n.editor_loadMask,
            ),
          if (_isInpaintMode)
            IconButton(
              icon: const Icon(Icons.open_in_full),
              onPressed: _showShiftEdgesDialog,
              tooltip: 'Shift Edges',
            ),
          if (!_isInpaintMode)
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              onPressed: _showEffectsDialog,
              tooltip: 'Effects',
            ),
          // 导出按钮
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _canExportAndClose ? _exportAndClose : null,
            tooltip: context.l10n.editor_done,
          ),
        ],
      ),
      body: Column(
        children: [
          // 画布区域
          Expanded(child: _buildCanvasArea()),

          // 工具设置（可折叠）
          _buildMobileToolSettings(),

          // 底部工具栏
          MobileToolbar(
            state: _state,
            onClear: _isInpaintMode ? _resetInpaintMask : null,
            onFillMask: _isInpaintMode ? _handleFillClosedMaskRegions : null,
            canFillMask: _isInpaintMode ? _hasMaskContent : null,
            onLayersPressed: _showMobileLayerSheet,
            allowedToolIds: _isInpaintMode
                ? _ImageEditorScreenState._inpaintToolIds
                : null,
          ),
        ],
      ),
    );
  }

  /// 桌面端菜单栏
  Widget _buildDesktopMenuBar() {
    final theme = Theme.of(context);

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          // 返回按钮
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: () => _confirmExit(),
            tooltip: context.l10n.editor_back,
          ),

          Text(_editorTitle(), style: theme.textTheme.titleSmall),

          const Spacer(),

          _buildDesktopCompressionControl(
            expanded: MediaQuery.sizeOf(context).width >= 1700,
          ),
          const SizedBox(width: 4),

          if (!_isInpaintMode)
            if (MediaQuery.sizeOf(context).width >= 1280)
              TextButton.icon(
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: const Text('Effects'),
                onPressed: _showEffectsDialog,
              )
            else
              IconButton(
                icon: const Icon(Icons.tune_rounded, size: 20),
                onPressed: _showEffectsDialog,
                tooltip: 'Effects',
              ),

          // 画布尺寸按钮（使用细粒度监听）
          TextButton.icon(
            icon: const Icon(Icons.aspect_ratio, size: 18),
            label: ValueListenableBuilder<Size>(
              valueListenable: _state.canvasSizeNotifier,
              builder: (context, size, _) =>
                  Text('${size.width.toInt()} x ${size.height.toInt()}'),
            ),
            onPressed: _changeCanvasSize,
          ),

          // 加载蒙版按钮
          if (_isInpaintMode)
            IconButton(
              icon: const Icon(Icons.upload_file, size: 20),
              onPressed: _loadMask,
              tooltip: context.l10n.editor_loadMask,
            ),

          if (_isInpaintMode)
            if (MediaQuery.sizeOf(context).width >= 1280)
              TextButton.icon(
                icon: const Icon(Icons.open_in_full, size: 18),
                label: const Text('Shift Edges'),
                onPressed: _showShiftEdgesDialog,
              )
            else
              IconButton(
                icon: const Icon(Icons.open_in_full, size: 20),
                onPressed: _showShiftEdgesDialog,
                tooltip: 'Shift Edges',
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
              _showLayerPanel
                  ? Icons.view_sidebar
                  : Icons.view_sidebar_outlined,
              size: 20,
            ),
            onPressed: () {
              _updateLayoutState(() {
                _showLayerPanel = !_showLayerPanel;
              });
            },
            tooltip: context.l10n.editor_togglePanels,
          ),

          // 快捷键帮助
          IconButton(
            icon: const Icon(Icons.keyboard, size: 20),
            onPressed: _showShortcutHelp,
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
            child: FilledButton.icon(
              icon: const Icon(Icons.check, size: 18),
              label: Text(context.l10n.editor_done),
              onPressed: _canExportAndClose ? _exportAndClose : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 状态栏
  /// 使用 Listenable.merge 实现细粒度监听
  Widget _buildStatusBar() {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([
        _state.canvasController, // 缩放、旋转、镜像
        _state.canvasSizeNotifier, // 画布尺寸
        _state.layerManager, // 图层数量
        _state.selectionManager, // 选区状态
      ]),
      builder: (context, _) {
        return Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            border: Border(
              top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.3)),
            ),
          ),
          child: Row(
            children: [
              Text(
                context.l10n.editor_statusZoom(
                  (_state.canvasController.scale * 100).round(),
                ),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(width: 16),
              Text(
                context.l10n.editor_statusCanvas(
                  _state.canvasSize.width.toInt(),
                  _state.canvasSize.height.toInt(),
                ),
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(width: 16),
              Text(
                context.l10n.editor_statusLayers(
                  _state.layerManager.layerCount,
                ),
                style: theme.textTheme.bodySmall,
              ),
              if (_state.selectionPath != null) ...[
                const SizedBox(width: 16),
                Text(
                  context.l10n.editor_statusHasSelection,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
              // 旋转角度显示
              if (_state.canvasController.rotation != 0) ...[
                const SizedBox(width: 16),
                Text(
                  context.l10n.editor_statusRotation(
                    (_state.canvasController.rotation * 180 / 3.14159265359)
                        .round(),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.secondary,
                  ),
                ),
              ],
              // 镜像状态显示
              if (_state.canvasController.isMirroredHorizontally) ...[
                const SizedBox(width: 16),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.flip,
                      size: 14,
                      color: theme.colorScheme.secondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      context.l10n.editor_statusMirrored,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// 工具设置面板
  /// 使用 toolChangeNotifier 实现细粒度监听，仅在工具切换时重建
  Widget _buildToolSettingsPanel() {
    return ValueListenableBuilder<EditorTool?>(
      valueListenable: _state.toolChangeNotifier,
      builder: (context, tool, _) {
        if (tool == null) {
          return Center(child: Text(context.l10n.image_editor_select_tool));
        }
        return SingleChildScrollView(
          child: tool.buildSettingsPanel(context, _state),
        );
      },
    );
  }

  /// 移动端工具设置
  /// 使用 toolChangeNotifier 实现细粒度监听
  Widget _buildMobileToolSettings() {
    return ValueListenableBuilder<EditorTool?>(
      valueListenable: _state.toolChangeNotifier,
      builder: (context, tool, _) {
        if (tool == null) return const SizedBox.shrink();

        return Container(
          constraints: const BoxConstraints(maxHeight: 150),
          child: SingleChildScrollView(
            child: tool.buildSettingsPanel(context, _state),
          ),
        );
      },
    );
  }

  /// 显示移动端图层面板
  void _showMobileLayerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return LayerPanel(state: _state);
        },
      ),
    );
  }

  /// 显示快捷键帮助
  void _showShortcutHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.keyboard),
            const SizedBox(width: 8),
            Text(context.l10n.editor_shortcutHelpTitle),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 500, maxWidth: 350),
          child: SingleChildScrollView(
            primary: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildShortcutSection(context.l10n.editor_shortcutPaintTools, [
                  ('B', context.l10n.editor_toolBrush),
                  ('E', context.l10n.editor_toolEraser),
                  ('P', context.l10n.editor_toolColorPicker),
                  ('Alt', context.l10n.editor_shortcutTemporaryColorPicker),
                ]),
                _buildShortcutSection(
                  context.l10n.editor_shortcutSelectionTools,
                  [
                    ('M', context.l10n.editor_shortcutRectSelection),
                    ('U', context.l10n.editor_shortcutEllipseSelection),
                    ('L', context.l10n.editor_shortcutLassoSelection),
                  ],
                ),
                _buildShortcutSection(context.l10n.editor_shortcutCanvasView, [
                  ('1', context.l10n.editor_shortcut100Zoom),
                  ('2', context.l10n.editor_shortcutFitHeight),
                  ('3', context.l10n.editor_shortcutFitWidth),
                  ('4', context.l10n.editor_shortcutRotateLeft15),
                  ('5', context.l10n.editor_shortcutResetRotation),
                  ('6', context.l10n.editor_shortcutRotateRight15),
                  ('F', context.l10n.editor_shortcutFlipHorizontal),
                  ('R', context.l10n.editor_resetView),
                  (context.l10n.editor_shortcutWheel, context.l10n.editor_zoom),
                  ('Ctrl+0', context.l10n.editor_shortcut100Zoom),
                  ('Ctrl++', context.l10n.editor_zoomIn),
                  ('Ctrl+-', context.l10n.editor_zoomOut),
                ]),
                _buildShortcutSection(context.l10n.editor_shortcutBrushAdjust, [
                  ('[', context.l10n.editor_shortcutBrushSmaller),
                  (']', context.l10n.editor_shortcutBrushLarger),
                  ('I', context.l10n.editor_shortcutOpacityLower),
                  ('O', context.l10n.editor_shortcutOpacityHigher),
                  ('Shift + Drag', context.l10n.editor_shortcutDragBrushSize),
                ]),
                _buildShortcutSection(context.l10n.editor_shortcutColors, [
                  ('X', context.l10n.editor_shortcutSwapColors),
                ]),
                _buildShortcutSection(
                  context.l10n.editor_shortcutCanvasActions,
                  [
                    ('Space + Drag', context.l10n.editor_shortcutPanCanvas),
                    ('Middle Drag', context.l10n.editor_shortcutPanCanvas),
                  ],
                ),
                _buildShortcutSection(
                  context.l10n.editor_shortcutHistoryActions,
                  [
                    ('Ctrl+Z', context.l10n.editor_undo),
                    ('Ctrl+Shift+Z', context.l10n.editor_redo),
                    ('Ctrl+Y', context.l10n.editor_redo),
                  ],
                ),
                _buildShortcutSection(
                  context.l10n.editor_shortcutSelectionActions,
                  [
                    (
                      'Delete',
                      context.l10n.editor_shortcutClearSelectionContent,
                    ),
                    (
                      'Backspace',
                      context.l10n.editor_shortcutClearSelectionContent,
                    ),
                    ('Esc', context.l10n.editor_shortcutCancelCurrentAction),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.common_close),
          ),
        ],
      ),
    );
  }

  Widget _buildShortcutSection(String title, List<(String, String)> shortcuts) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          ...shortcuts.map(
            (s) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      s.$1,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(s.$2, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
