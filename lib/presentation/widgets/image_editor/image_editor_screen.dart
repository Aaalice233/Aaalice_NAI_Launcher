import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'core/editor_state.dart';
import 'canvas/editor_canvas.dart';
import 'widgets/toolbar/desktop_toolbar.dart';
import 'widgets/toolbar/mobile_toolbar.dart';
import 'widgets/panels/layer_panel.dart';
import 'widgets/panels/color_panel.dart';
import 'widgets/panels/canvas_size_dialog.dart';
import 'export/image_exporter_new.dart';

/// 图像编辑器返回结果
class ImageEditorResult {
  /// 修改后的图像（涂鸦合并）
  final Uint8List? modifiedImage;

  /// Inpainting蒙版图像
  final Uint8List? maskImage;

  /// 是否有图像修改
  final bool hasImageChanges;

  /// 是否有蒙版修改
  final bool hasMaskChanges;

  const ImageEditorResult({
    this.modifiedImage,
    this.maskImage,
    this.hasImageChanges = false,
    this.hasMaskChanges = false,
  });
}

/// 图像编辑器主界面
class ImageEditorScreen extends StatefulWidget {
  /// 初始图像（可选，用于编辑已有图像）
  final Uint8List? initialImage;

  /// 初始画布尺寸（当没有初始图像时使用）
  final Size? initialSize;

  /// 已有的蒙版图像
  final Uint8List? existingMask;

  /// 是否显示蒙版导出选项
  final bool showMaskExport;

  /// 标题
  final String title;

  const ImageEditorScreen({
    super.key,
    this.initialImage,
    this.initialSize,
    this.existingMask,
    this.showMaskExport = true,
    this.title = '画板',
  });

  /// 显示编辑器
  static Future<ImageEditorResult?> show(
    BuildContext context, {
    Uint8List? initialImage,
    Size? initialSize,
    Uint8List? existingMask,
    bool showMaskExport = true,
    String title = '画板',
  }) {
    return Navigator.push<ImageEditorResult>(
      context,
      MaterialPageRoute(
        builder: (context) => ImageEditorScreen(
          initialImage: initialImage,
          initialSize: initialSize,
          existingMask: existingMask,
          showMaskExport: showMaskExport,
          title: title,
        ),
      ),
    );
  }

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  late EditorState _state;
  bool _isInitialized = false;
  bool _showLayerPanel = true;
  bool _isMobileLayerSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _state = EditorState();
    _initializeCanvas();
  }

  Future<void> _initializeCanvas() async {
    if (widget.initialImage != null) {
      // 从已有图像初始化
      await _loadInitialImage();
    } else {
      // 显示尺寸选择对话框或使用默认尺寸
      final size = widget.initialSize ?? const Size(1024, 1024);
      _state.initNewCanvas(size);
    }

    setState(() {
      _isInitialized = true;
    });

    // 适应视口
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _state.canvasController.fitToViewport(_state.canvasSize);
    });
  }

  Future<void> _loadInitialImage() async {
    ui.Codec? codec;
    try {
      codec = await ui.instantiateImageCodec(widget.initialImage!);
      final frame = await codec.getNextFrame();
      final image = frame.image;

      _state.initNewCanvas(Size(
        image.width.toDouble(),
        image.height.toDouble(),
      ));

      // 将图像添加为底层图层
      await _state.layerManager.addLayerFromImage(
        widget.initialImage!,
        name: '底图',
      );

      // TODO: 加载已有蒙版 (widget.existingMask)
      // 需要将位图蒙版转换为 Path，这是一个复杂操作
      // 可考虑使用轮廓检测算法或简单地将蒙版显示为图层

      image.dispose();
    } catch (e) {
      debugPrint('Failed to load initial image: $e');
      _state.initNewCanvas(widget.initialSize ?? const Size(1024, 1024));
    } finally {
      codec?.dispose();
    }
  }

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;
        return isDesktop ? _buildDesktopLayout() : _buildMobileLayout();
      },
    );
  }

  /// 桌面端布局
  Widget _buildDesktopLayout() {
    final theme = Theme.of(context);

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
                DesktopToolbar(state: _state),

                // 中间画布区域
                Expanded(
                  child: Column(
                    children: [
                      Expanded(
                        child: EditorCanvas(state: _state),
                      ),
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
                        Expanded(
                          flex: 2,
                          child: LayerPanel(state: _state),
                        ),
                        const Divider(height: 1),
                        // 工具设置面板
                        Expanded(
                          flex: 2,
                          child: _buildToolSettingsPanel(),
                        ),
                        const Divider(height: 1),
                        // 颜色面板
                        ColorPanel(state: _state),
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
        title: Text(widget.title),
        actions: [
          // 图层按钮
          IconButton(
            icon: const Icon(Icons.layers),
            onPressed: _showMobileLayerSheet,
          ),
          // 导出按钮
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _exportAndClose,
          ),
        ],
      ),
      body: Column(
        children: [
          // 画布区域
          Expanded(
            child: EditorCanvas(state: _state),
          ),

          // 工具设置（可折叠）
          _buildMobileToolSettings(),

          // 底部工具栏
          MobileToolbar(
            state: _state,
            onLayersPressed: _showMobileLayerSheet,
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
          bottom: BorderSide(color: theme.dividerColor),
        ),
      ),
      child: Row(
        children: [
          // 返回按钮
          IconButton(
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: () => _confirmExit(),
            tooltip: '返回',
          ),

          Text(widget.title, style: theme.textTheme.titleSmall),

          const Spacer(),

          // 画布尺寸按钮
          TextButton.icon(
            icon: const Icon(Icons.aspect_ratio, size: 18),
            label: ListenableBuilder(
              listenable: _state,
              builder: (context, _) => Text(
                '${_state.canvasSize.width.toInt()} x ${_state.canvasSize.height.toInt()}',
              ),
            ),
            onPressed: _changeCanvasSize,
          ),

          const VerticalDivider(width: 1, indent: 8, endIndent: 8),

          // 切换面板
          IconButton(
            icon: Icon(
              _showLayerPanel ? Icons.view_sidebar : Icons.view_sidebar_outlined,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _showLayerPanel = !_showLayerPanel;
              });
            },
            tooltip: '切换面板',
          ),

          const VerticalDivider(width: 1, indent: 8, endIndent: 8),

          // 导出按钮
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FilledButton.icon(
              icon: const Icon(Icons.check, size: 18),
              label: const Text('完成'),
              onPressed: _exportAndClose,
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
  Widget _buildStatusBar() {
    final theme = Theme.of(context);

    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        return Container(
          height: 24,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            border: Border(
              top: BorderSide(color: theme.dividerColor),
            ),
          ),
          child: Row(
            children: [
              Text(
                '缩放: ${(_state.canvasController.scale * 100).round()}%',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(width: 16),
              Text(
                '画布: ${_state.canvasSize.width.toInt()} x ${_state.canvasSize.height.toInt()}',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(width: 16),
              Text(
                '图层: ${_state.layerManager.layerCount}',
                style: theme.textTheme.bodySmall,
              ),
              if (_state.selectionPath != null) ...[
                const SizedBox(width: 16),
                Text(
                  '有选区',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// 工具设置面板
  Widget _buildToolSettingsPanel() {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        final tool = _state.currentTool;
        if (tool == null) {
          return const Center(child: Text('选择工具'));
        }
        return SingleChildScrollView(
          child: tool.buildSettingsPanel(context, _state),
        );
      },
    );
  }

  /// 移动端工具设置
  Widget _buildMobileToolSettings() {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        final tool = _state.currentTool;
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

  /// 更改画布尺寸
  Future<void> _changeCanvasSize() async {
    final newSize = await CanvasSizeDialog.show(
      context,
      initialSize: _state.canvasSize,
      title: '更改画布尺寸',
    );

    if (newSize != null && newSize != _state.canvasSize) {
      // TODO: 实现画布尺寸更改（需要处理图层内容）
      _state.setCanvasSize(newSize);
    }
  }

  /// 确认退出
  Future<void> _confirmExit() async {
    // 检查是否有修改：检查历史记录或图层内容
    final hasChanges = _state.historyManager.canUndo ||
        _state.layerManager.layers.any((l) =>
            l.strokes.isNotEmpty || l.baseImage != null);

    if (hasChanges) {
      final shouldExit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认退出'),
          content: const Text('有未保存的修改，确定要退出吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('退出'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context, false);
                await _exportAndClose();
              },
              child: const Text('保存并退出'),
            ),
          ],
        ),
      );

      if (shouldExit != true) return;
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  /// 导出并关闭
  Future<void> _exportAndClose() async {
    if (!mounted) return;

    try {
      // 显示加载指示器
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // 检查是否有图像修改（检查是否有笔画或多个图层）
      final hasImageChanges = _state.historyManager.canUndo ||
          _state.layerManager.layers.any((l) => l.strokes.isNotEmpty) ||
          _state.layerManager.layerCount > 1;

      // 检查是否有蒙版修改
      final hasMaskChanges = _state.selectionPath != null;

      // 导出合并图像
      Uint8List? modifiedImage;
      if (hasImageChanges) {
        modifiedImage = await ImageExporterNew.exportMergedImage(
          _state.layerManager,
          _state.canvasSize,
        );
      }

      // 导出蒙版图像
      Uint8List? maskImage;
      if (widget.showMaskExport && _state.selectionPath != null) {
        maskImage = await ImageExporterNew.exportMask(
          _state.selectionPath!,
          _state.canvasSize,
        );
      }

      // 关闭加载指示器
      if (mounted) Navigator.pop(context);

      // 返回结果
      if (mounted) {
        Navigator.pop(
          context,
          ImageEditorResult(
            modifiedImage: modifiedImage,
            maskImage: maskImage,
            hasImageChanges: hasImageChanges,
            hasMaskChanges: hasMaskChanges,
          ),
        );
      }
    } catch (e) {
      // 关闭加载指示器
      if (mounted) Navigator.pop(context);

      // 显示错误
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }
}
