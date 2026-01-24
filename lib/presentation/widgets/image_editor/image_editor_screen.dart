import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/utils/app_logger.dart';
import 'core/editor_state.dart';
import 'layers/layer.dart';
import 'tools/tool_base.dart';
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

      // 加载已有蒙版（如果有）
      await _loadExistingMask();
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

      _state.initNewCanvas(
        Size(
          image.width.toDouble(),
          image.height.toDouble(),
        ),
      );

      // 将图像添加为底图图层
      await _state.layerManager.addLayerFromImage(
        widget.initialImage!,
        name: '底图',
      );

      // 选中"图层 1"作为默认绘制图层（而非底图）
      final layer1 = _state.layerManager.layers.firstWhere(
        (l) => l.name == '图层 1',
        orElse: () => _state.layerManager.layers.last,
      );
      _state.layerManager.setActiveLayer(layer1.id);

      // 加载已有蒙版
      await _loadExistingMask();

      image.dispose();
    } catch (e) {
      AppLogger.w('Failed to load initial image: $e', 'ImageEditor');
      _state.initNewCanvas(widget.initialSize ?? const Size(1024, 1024));
    } finally {
      codec?.dispose();
    }
  }

  Future<void> _loadExistingMask() async {
    if (widget.existingMask == null) return;

    try {
      // 将已有蒙版添加为图层
      final layer = await _state.layerManager.addLayerFromImage(
        widget.existingMask!,
        name: '已有蒙版',
      );

      if (layer != null) {
        AppLogger.i(
            'Existing mask loaded as layer: ${layer.id}', 'ImageEditor',);
      } else {
        AppLogger.w('Failed to load existing mask as layer', 'ImageEditor');
      }
    } catch (e) {
      AppLogger.e('Error loading existing mask: $e', 'ImageEditor');
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
            tooltip: '图层',
          ),
          // 加载蒙版按钮
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _loadMask,
            tooltip: '加载蒙版',
          ),
          // 导出按钮
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _exportAndClose,
            tooltip: '完成',
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

          // 画布尺寸按钮（使用细粒度监听）
          TextButton.icon(
            icon: const Icon(Icons.aspect_ratio, size: 18),
            label: ValueListenableBuilder<Size>(
              valueListenable: _state.canvasSizeNotifier,
              builder: (context, size, _) => Text(
                '${size.width.toInt()} x ${size.height.toInt()}',
              ),
            ),
            onPressed: _changeCanvasSize,
          ),

          // 加载蒙版按钮
          IconButton(
            icon: const Icon(Icons.upload_file, size: 20),
            onPressed: _loadMask,
            tooltip: '加载蒙版',
          ),

          const VerticalDivider(width: 1, indent: 8, endIndent: 8),

          // 切换面板
          IconButton(
            icon: Icon(
              _showLayerPanel
                  ? Icons.view_sidebar
                  : Icons.view_sidebar_outlined,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _showLayerPanel = !_showLayerPanel;
              });
            },
            tooltip: '切换面板',
          ),

          // 快捷键帮助
          IconButton(
            icon: const Icon(Icons.keyboard, size: 20),
            onPressed: _showShortcutHelp,
            tooltip: '快捷键帮助',
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
              // 旋转角度显示
              if (_state.canvasController.rotation != 0) ...[
                const SizedBox(width: 16),
                Text(
                  '旋转: ${(_state.canvasController.rotation * 180 / 3.14159265359).round()}°',
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
                      '镜像',
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
          return const Center(child: Text('选择工具'));
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
        title: const Row(
          children: [
            Icon(Icons.keyboard),
            SizedBox(width: 8),
            Text('快捷键帮助'),
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
                _buildShortcutSection('绘画工具', [
                  ('B', '画笔'),
                  ('E', '橡皮擦'),
                  ('P', '拾色器'),
                  ('Alt 按住', '临时拾色器'),
                ]),
                _buildShortcutSection('选区工具', [
                  ('M', '矩形选区'),
                  ('U', '椭圆选区'),
                  ('L', '套索选区'),
                ]),
                _buildShortcutSection('画布视图', [
                  ('1', '100% 缩放'),
                  ('2', '适应高度'),
                  ('3', '适应宽度'),
                  ('4', '向左旋转 15°'),
                  ('5', '重置旋转'),
                  ('6', '向右旋转 15°'),
                  ('F', '水平镜像'),
                  ('R', '重置视图'),
                  ('滚轮', '缩放'),
                  ('Ctrl+0', '100% 缩放'),
                  ('Ctrl++', '放大'),
                  ('Ctrl+-', '缩小'),
                ]),
                _buildShortcutSection('笔刷调整', [
                  ('[', '减小笔刷'),
                  (']', '增大笔刷'),
                  ('I', '降低透明度'),
                  ('O', '提高透明度'),
                  ('Shift + 拖动', '调整笔刷大小'),
                ]),
                _buildShortcutSection('颜色', [
                  ('X', '交换前景/背景色'),
                ]),
                _buildShortcutSection('画布操作', [
                  ('空格 + 拖动', '平移画布'),
                  ('中键拖动', '平移画布'),
                ]),
                _buildShortcutSection('历史操作', [
                  ('Ctrl+Z', '撤销'),
                  ('Ctrl+Shift+Z', '重做'),
                  ('Ctrl+Y', '重做'),
                ]),
                _buildShortcutSection('选区操作', [
                  ('Delete', '清除选区内容'),
                  ('Backspace', '清除选区内容'),
                  ('Esc', '取消当前操作'),
                ]),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('关闭'),
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

  /// 更改画布尺寸
  Future<void> _changeCanvasSize() async {
    final result = await CanvasSizeDialog.show(
      context,
      initialSize: _state.canvasSize,
      title: '更改画布尺寸',
    );

    if (result != null && result.size != _state.canvasSize) {
      try {
        // 验证尺寸范围
        final newWidth = result.size.width.toInt();
        final newHeight = result.size.height.toInt();
        const minSize = 64;
        const maxSize = 4096;

        if (newWidth < minSize || newHeight < minSize) {
          _showError('画布尺寸太小，最小尺寸为 $minSize x $minSize 像素');
          return;
        }

        if (newWidth > maxSize || newHeight > maxSize) {
          _showError('画布尺寸太大，最大尺寸为 $maxSize x $maxSize 像素');
          return;
        }

        // 将 ContentHandlingMode 转换为 CanvasResizeMode
        final mode = _convertContentModeToResizeMode(result.mode);

        // 使用新的 resizeCanvas 方法，支持图层内容变换
        _state.resizeCanvas(result.size, mode);

        // 显示成功消息
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('画布已调整为 $newWidth x $newHeight'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        // 显示错误信息
        _showError('调整画布尺寸失败: $e');
        AppLogger.e('Failed to resize canvas: $e', 'ImageEditor');
      }
    }
  }

  /// 显示错误消息
  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          action: SnackBarAction(
            label: '关闭',
            onPressed: () {},
          ),
        ),
      );
    }
  }

  /// 将内容处理模式转换为画布调整模式
  CanvasResizeMode _convertContentModeToResizeMode(ContentHandlingMode mode) {
    switch (mode) {
      case ContentHandlingMode.crop:
        return CanvasResizeMode.crop;
      case ContentHandlingMode.pad:
        return CanvasResizeMode.pad;
      case ContentHandlingMode.stretch:
        return CanvasResizeMode.stretch;
    }
  }

  /// 确认退出
  Future<void> _confirmExit() async {
    // 检查是否有修改：检查历史记录或图层内容
    final hasChanges = _state.historyManager.canUndo ||
        _state.layerManager.layers.any(
          (l) => l.strokes.isNotEmpty || l.baseImage != null,
        );

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

    // 用于跟踪加载对话框是否已显示
    bool loadingDialogShown = false;

    try {
      // 显示加载指示器
      loadingDialogShown = true;
      unawaited(
        showDialog(
          context: context,
          barrierDismissible: false,
          useRootNavigator: true,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
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
      if (mounted && loadingDialogShown) {
        Navigator.of(context, rootNavigator: true).pop();
        loadingDialogShown = false;
      }

      // 返回结果
      if (mounted) {
        Navigator.of(context).pop(
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
      if (mounted && loadingDialogShown) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // 显示错误
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导出失败: $e')),
        );
      }
    }
  }

  /// 加载蒙版文件
  Future<void> _loadMaskFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        // 用户取消了文件选择
        return;
      }

      final file = result.files.first;

      // 验证文件扩展名（额外的安全检查）
      if (file.path != null) {
        final extension = file.path!.split('.').last.toLowerCase();
        const validImageExtensions = [
          'png',
          'jpg',
          'jpeg',
          'webp',
          'bmp',
          'gif',
        ];

        if (!validImageExtensions.contains(extension)) {
          AppLogger.w('Invalid file extension: $extension', 'ImageEditor');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('不支持的文件格式: .$extension\n请选择图像文件（PNG、JPG、WEBP等）'),
              ),
            );
          }
          return;
        }
      }

      // 读取文件字节数据
      Uint8List? bytes;
      if (file.bytes != null) {
        bytes = file.bytes;
      } else if (file.path != null) {
        try {
          bytes = await File(file.path!).readAsBytes();
        } catch (e) {
          AppLogger.e('Failed to read file: $e', 'ImageEditor');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('无法读取文件: $e')),
            );
          }
          return;
        }
      }

      // 验证字节数据
      if (bytes == null) {
        AppLogger.w('File bytes is null', 'ImageEditor');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法获取文件数据')),
          );
        }
        return;
      }

      // 检查文件是否为空
      if (bytes.isEmpty) {
        AppLogger.w('File is empty (0 bytes)', 'ImageEditor');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('文件为空，请选择有效的图像文件')),
          );
        }
        return;
      }

      // 检查文件大小（限制为 50MB 以防止内存问题）
      const maxFileSize = 50 * 1024 * 1024; // 50MB
      if (bytes.length > maxFileSize) {
        final sizeMB = (bytes.length / (1024 * 1024)).toStringAsFixed(1);
        AppLogger.w('File too large: ${bytes.length} bytes', 'ImageEditor');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('文件过大（$sizeMB MB），请选择小于 50MB 的图像')),
          );
        }
        return;
      }

      // 将蒙版添加为新图层
      final layer = await _state.layerManager.addLayerFromImage(
        bytes,
        name: '蒙版',
      );

      if (layer != null) {
        AppLogger.i('Mask layer added: ${layer.id}', 'ImageEditor');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('蒙版图层已添加')),
          );
        }
      } else {
        // 图像解码失败或格式不支持
        AppLogger.w(
            'Failed to decode image or unsupported format', 'ImageEditor',);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('无法解析图像文件\n请确保文件未损坏且格式受支持'),
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.e('Unexpected error loading mask file: $e', 'ImageEditor');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载蒙版时发生错误: $e')),
        );
      }
    }
  }

  /// 加载蒙版
  Future<void> _loadMask() async {
    await _loadMaskFile();
  }
}
