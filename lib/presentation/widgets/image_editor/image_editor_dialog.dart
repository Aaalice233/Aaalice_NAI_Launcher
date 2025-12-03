import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/utils/localization_extension.dart';
import 'canvas/editor_canvas.dart';
import 'image_editor_controller.dart';
import 'utils/image_exporter.dart';
import 'widgets/mobile_bottom_bar.dart';
import 'widgets/tool_bar.dart';
import 'widgets/tool_settings_panel.dart';

/// 图像编辑器结果
class ImageEditorResult {
  final Uint8List? modifiedImage; // 修改后的图像 (涂鸦合并)
  final Uint8List? maskImage; // 遮罩图像 (黑白)
  final bool hasImageChanges;
  final bool hasMaskChanges;

  const ImageEditorResult({
    this.modifiedImage,
    this.maskImage,
    this.hasImageChanges = false,
    this.hasMaskChanges = false,
  });
}

/// 图像编辑器对话框
class ImageEditorDialog extends StatefulWidget {
  final Uint8List imageBytes;
  final Uint8List? existingMask;

  const ImageEditorDialog({
    super.key,
    required this.imageBytes,
    this.existingMask,
  });

  /// 显示编辑器对话框
  static Future<ImageEditorResult?> show({
    required BuildContext context,
    required Uint8List imageBytes,
    Uint8List? existingMask,
  }) {
    return showDialog<ImageEditorResult>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ImageEditorDialog(
        imageBytes: imageBytes,
        existingMask: existingMask,
      ),
    );
  }

  @override
  State<ImageEditorDialog> createState() => _ImageEditorDialogState();
}

class _ImageEditorDialogState extends State<ImageEditorDialog> {
  late ImageEditorController _controller;
  bool _isLoading = true;
  bool _showMobileSettings = false;

  @override
  void initState() {
    super.initState();
    _controller = ImageEditorController();
    _loadImage();
  }

  Future<void> _loadImage() async {
    await _controller.setBaseImage(widget.imageBytes);

    // 加载已有遮罩
    if (widget.existingMask != null) {
      await _controller.loadExistingMask(widget.existingMask!);
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 600;

    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF1e1e1e),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : isDesktop
              ? _buildDesktopLayout()
              : _buildMobileLayout(),
    );
  }

  /// 桌面端布局
  Widget _buildDesktopLayout() {
    return Column(
      children: [
        // 顶部栏
        _buildTopBar(),

        // 主内容
        Expanded(
          child: Row(
            children: [
              // 左侧工具栏
              EditorToolBar(controller: _controller),

              // 画布
              Expanded(
                child: EditorCanvas(controller: _controller),
              ),

              // 右侧设置面板
              ToolSettingsPanel(controller: _controller),
            ],
          ),
        ),
      ],
    );
  }

  /// 移动端布局
  Widget _buildMobileLayout() {
    return Stack(
      children: [
        Column(
          children: [
            // 顶部栏
            _buildMobileTopBar(),

            // 画布
            Expanded(
              child: EditorCanvas(controller: _controller),
            ),

            // 底部工具栏
            MobileBottomBar(
              controller: _controller,
              onSettingsTap: () {
                setState(() {
                  _showMobileSettings = true;
                });
              },
            ),
          ],
        ),

        // 移动端设置面板 (底部弹出)
        if (_showMobileSettings)
          _buildMobileSettingsSheet(),
      ],
    );
  }

  /// 顶部栏（简化版：返回 + 标题 + 缩放 + 完成）
  Widget _buildTopBar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2d2d2d),
        border: Border(
          bottom: BorderSide(
            color: Colors.black.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // 返回按钮（询问保存）
          IconButton(
            onPressed: _confirmClose,
            icon: const Icon(Icons.arrow_back, size: 20),
            color: Colors.white70,
            tooltip: context.l10n.editor_close,
            visualDensity: VisualDensity.compact,
          ),

          const SizedBox(width: 8),

          // 标题
          Text(
            context.l10n.editor_title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),

          const Spacer(),

          // 缩放显示
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => Text(
              '${(_controller.scale * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ),

          // 重置视图按钮
          IconButton(
            onPressed: () {
              final renderBox = context.findRenderObject() as RenderBox?;
              if (renderBox != null) {
                _controller.fitToViewport(renderBox.size);
              }
            },
            icon: const Icon(Icons.fit_screen, size: 18),
            color: Colors.white70,
            tooltip: context.l10n.editor_resetView,
            visualDensity: VisualDensity.compact,
          ),

          const Spacer(),

          // 完成按钮（保存并关闭）
          TextButton.icon(
            onPressed: _saveAndClose,
            icon: const Icon(Icons.check, size: 18),
            label: Text(context.l10n.editor_done),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: const Color(0xFF4a90d9),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),

          const SizedBox(width: 8),
        ],
      ),
    );
  }

  /// 确认关闭对话框
  Future<void> _confirmClose() async {
    if (_controller.hasChanges) {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.l10n.editor_unsavedChanges),
          content: Text(context.l10n.editor_unsavedChangesMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.l10n.editor_cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(context.l10n.editor_discard),
            ),
          ],
        ),
      );
      if (result == true && mounted) {
        Navigator.of(context).pop();
      }
    } else {
      Navigator.of(context).pop();
    }
  }

  /// 移动端顶部栏（简化版）
  Widget _buildMobileTopBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 8,
        right: 8,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF2d2d2d),
        border: Border(
          bottom: BorderSide(
            color: Colors.black.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // 返回按钮
          IconButton(
            onPressed: _confirmClose,
            icon: const Icon(Icons.arrow_back, size: 20),
            color: Colors.white70,
            tooltip: context.l10n.editor_close,
            visualDensity: VisualDensity.compact,
          ),

          // 标题
          Text(
            context.l10n.editor_title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),

          const Spacer(),

          // 缩放显示
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => Text(
              '${(_controller.scale * 100).toInt()}%',
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 11,
              ),
            ),
          ),

          const Spacer(),

          // 完成按钮
          IconButton(
            onPressed: _saveAndClose,
            icon: const Icon(Icons.check),
            color: const Color(0xFF4a90d9),
            tooltip: context.l10n.editor_done,
          ),
        ],
      ),
    );
  }

  /// 移动端设置面板
  Widget _buildMobileSettingsSheet() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _showMobileSettings = false;
        });
      },
      child: Container(
        color: Colors.black54,
        child: Column(
          children: [
            const Spacer(),
            GestureDetector(
              onTap: () {}, // 阻止点击传递
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF2d2d2d),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 拖动指示器
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    // 设置内容
                    SizedBox(
                      height: 400,
                      child: ToolSettingsPanel(controller: _controller),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 保存并关闭
  Future<void> _saveAndClose() async {
    Uint8List? modifiedImage;
    Uint8List? maskImage;

    // 导出涂鸦合并后的图像
    if (_controller.hasImageChanges && _controller.baseImage != null) {
      modifiedImage = await ImageExporter.exportWithStrokes(
        _controller.baseImage!,
        _controller.imageStrokes,
      );
    }

    // 导出遮罩
    if (_controller.hasMaskChanges && _controller.baseImage != null) {
      maskImage = await ImageExporter.exportMask(
        _controller.baseImage!.width,
        _controller.baseImage!.height,
        _controller.maskPath!,
      );
    }

    if (mounted) {
      Navigator.of(context).pop(
        ImageEditorResult(
          modifiedImage: modifiedImage,
          maskImage: maskImage,
          hasImageChanges: _controller.hasImageChanges,
          hasMaskChanges: _controller.hasMaskChanges,
        ),
      );
    }
  }
}

