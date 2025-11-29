import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'app_toast.dart';

/// 可选择的图像卡片组件
class SelectableImageCard extends StatefulWidget {
  final Uint8List imageBytes;
  final int? index;
  final bool isSelected;
  final bool showIndex;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onSelectionChanged;
  final VoidCallback? onFullscreen;

  const SelectableImageCard({
    super.key,
    required this.imageBytes,
    this.index,
    this.isSelected = false,
    this.showIndex = true,
    this.onTap,
    this.onSelectionChanged,
    this.onFullscreen,
  });

  @override
  State<SelectableImageCard> createState() => _SelectableImageCardState();
}

class _SelectableImageCardState extends State<SelectableImageCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap ?? widget.onFullscreen,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.isSelected
                  ? theme.colorScheme.primary
                  : (_isHovering
                      ? theme.colorScheme.primary.withOpacity(0.5)
                      : Colors.transparent),
              width: widget.isSelected ? 2 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.isSelected
                    ? theme.colorScheme.primary.withOpacity(0.3)
                    : Colors.black.withOpacity(0.2),
                blurRadius: widget.isSelected ? 12 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 图片
                Image.memory(
                  widget.imageBytes,
                  fit: BoxFit.cover,
                ),

                // 悬浮/选中时的遮罩
                if (_isHovering || widget.isSelected)
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.center,
                        colors: [
                          Colors.black.withOpacity(0.4),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),

                // 左上角：选择框（悬浮或选中时显示）
                if (_isHovering || widget.isSelected)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: _buildCheckbox(theme),
                  ),

                // 右上角：操作按钮（选中时显示）
                if (widget.isSelected || _isHovering)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: _buildActionButtons(context, theme),
                  ),
                
                // 左下角：序号
                if (widget.showIndex && widget.index != null)
                  Positioned(
                    bottom: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${widget.index! + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckbox(ThemeData theme) {
    return GestureDetector(
      onTap: () {
        widget.onSelectionChanged?.call(!widget.isSelected);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: widget.isSelected
              ? theme.colorScheme.primary
              : Colors.black45,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: widget.isSelected
                ? theme.colorScheme.primary
                : Colors.white70,
            width: 1.5,
          ),
        ),
        child: widget.isSelected
            ? const Icon(
                Icons.check,
                color: Colors.white,
                size: 16,
              )
            : null,
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ActionButton(
          icon: Icons.save_alt,
          tooltip: '保存',
          onTap: () => _saveImage(context),
        ),
        const SizedBox(width: 4),
        _ActionButton(
          icon: Icons.copy,
          tooltip: '复制',
          onTap: () => _copyImage(context),
        ),
      ],
    );
  }

  Future<void> _saveImage(BuildContext context) async {
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final saveDir = Directory('${docDir.path}/NAI_Launcher');
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      final fileName = 'NAI_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${saveDir.path}/$fileName');
      await file.writeAsBytes(widget.imageBytes);

      if (context.mounted) {
        AppToast.success(context, '已保存到 ${saveDir.path}');
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, '保存失败: $e');
      }
    }
  }

  Future<void> _copyImage(BuildContext context) async {
    try {
      await Clipboard.setData(const ClipboardData(text: ''));
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/NAI_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(widget.imageBytes);

      await Process.run('powershell', [
        '-command',
        'Set-Clipboard -Path "${file.path}"',
      ]);

      if (context.mounted) {
        AppToast.success(context, '已复制到剪贴板');
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.error(context, '复制失败: $e');
      }
    }
  }
}

/// 小型操作按钮
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.all(4),
            child: Icon(
              icon,
              color: Colors.white,
              size: 16,
            ),
          ),
        ),
      ),
    );
  }
}

