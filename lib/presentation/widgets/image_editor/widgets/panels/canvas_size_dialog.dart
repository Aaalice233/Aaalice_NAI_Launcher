import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 画布尺寸预设
class CanvasSizePreset {
  final int width;
  final int height;
  final String name;

  const CanvasSizePreset(this.width, this.height, this.name);

  @override
  String toString() => '$name ($width x $height)';
}

/// 预设尺寸列表
const canvasPresets = [
  CanvasSizePreset(512, 512, '方形 512'),
  CanvasSizePreset(768, 768, '方形 768'),
  CanvasSizePreset(1024, 1024, '方形 1024'),
  CanvasSizePreset(768, 512, '横向 3:2'),
  CanvasSizePreset(512, 768, '纵向 2:3'),
  CanvasSizePreset(832, 1216, 'NAI 纵向'),
  CanvasSizePreset(1216, 832, 'NAI 横向'),
  CanvasSizePreset(1024, 768, '横向 4:3'),
  CanvasSizePreset(768, 1024, '纵向 3:4'),
  CanvasSizePreset(1920, 1080, '全高清 16:9'),
];

/// 画布尺寸对话框
class CanvasSizeDialog extends StatefulWidget {
  final Size? initialSize;
  final String title;
  final String confirmText;

  const CanvasSizeDialog({
    super.key,
    this.initialSize,
    this.title = '画布尺寸',
    this.confirmText = '确定',
  });

  /// 显示对话框
  static Future<Size?> show(
    BuildContext context, {
    Size? initialSize,
    String title = '画布尺寸',
    String confirmText = '确定',
  }) {
    return showDialog<Size>(
      context: context,
      builder: (context) => CanvasSizeDialog(
        initialSize: initialSize,
        title: title,
        confirmText: confirmText,
      ),
    );
  }

  @override
  State<CanvasSizeDialog> createState() => _CanvasSizeDialogState();
}

class _CanvasSizeDialogState extends State<CanvasSizeDialog> {
  late TextEditingController _widthController;
  late TextEditingController _heightController;
  CanvasSizePreset? _selectedPreset;
  bool _linkDimensions = false;
  double _aspectRatio = 1.0;

  @override
  void initState() {
    super.initState();
    final initialWidth = widget.initialSize?.width.toInt() ?? 1024;
    final initialHeight = widget.initialSize?.height.toInt() ?? 1024;
    _widthController = TextEditingController(text: initialWidth.toString());
    _heightController = TextEditingController(text: initialHeight.toString());
    _aspectRatio = initialWidth / initialHeight;

    // 检查是否匹配预设
    for (final preset in canvasPresets) {
      if (preset.width == initialWidth && preset.height == initialHeight) {
        _selectedPreset = preset;
        break;
      }
    }
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 预设选择
            DropdownButtonFormField<CanvasSizePreset>(
              value: _selectedPreset,
              decoration: const InputDecoration(
                labelText: '预设尺寸',
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('自定义'),
                ),
                ...canvasPresets.map((preset) => DropdownMenuItem(
                      value: preset,
                      child: Text(preset.toString()),
                    )),
              ],
              onChanged: (preset) {
                setState(() {
                  _selectedPreset = preset;
                  if (preset != null) {
                    _widthController.text = preset.width.toString();
                    _heightController.text = preset.height.toString();
                    _aspectRatio = preset.width / preset.height;
                  }
                });
              },
            ),

            const SizedBox(height: 16),

            // 宽高输入
            Row(
              children: [
                // 宽度
                Expanded(
                  child: TextField(
                    controller: _widthController,
                    decoration: const InputDecoration(
                      labelText: '宽度',
                      suffixText: 'px',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (value) {
                      _selectedPreset = null;
                      if (_linkDimensions) {
                        final width = int.tryParse(value) ?? 0;
                        if (width > 0) {
                          final height = (width / _aspectRatio).round();
                          _heightController.text = height.toString();
                        }
                      }
                      setState(() {});
                    },
                  ),
                ),

                // 链接按钮
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: IconButton(
                    icon: Icon(
                      _linkDimensions ? Icons.link : Icons.link_off,
                      color: _linkDimensions
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    tooltip: _linkDimensions ? '取消锁定比例' : '锁定比例',
                    onPressed: () {
                      setState(() {
                        _linkDimensions = !_linkDimensions;
                        if (_linkDimensions) {
                          final width = int.tryParse(_widthController.text) ?? 1;
                          final height = int.tryParse(_heightController.text) ?? 1;
                          _aspectRatio = width / height;
                        }
                      });
                    },
                  ),
                ),

                // 高度
                Expanded(
                  child: TextField(
                    controller: _heightController,
                    decoration: const InputDecoration(
                      labelText: '高度',
                      suffixText: 'px',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (value) {
                      _selectedPreset = null;
                      if (_linkDimensions) {
                        final height = int.tryParse(value) ?? 0;
                        if (height > 0) {
                          final width = (height * _aspectRatio).round();
                          _widthController.text = width.toString();
                        }
                      }
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // 快捷比例按钮
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _RatioChip(label: '1:1', onTap: () => _setRatio(1, 1)),
                _RatioChip(label: '4:3', onTap: () => _setRatio(4, 3)),
                _RatioChip(label: '3:4', onTap: () => _setRatio(3, 4)),
                _RatioChip(label: '16:9', onTap: () => _setRatio(16, 9)),
                _RatioChip(label: '9:16', onTap: () => _setRatio(9, 16)),
              ],
            ),

            const SizedBox(height: 16),

            // 尺寸预览
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.aspect_ratio,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_widthController.text} x ${_heightController.text} 像素',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _isValid() ? _confirm : null,
          child: Text(widget.confirmText),
        ),
      ],
    );
  }

  void _setRatio(int widthRatio, int heightRatio) {
    final currentWidth = int.tryParse(_widthController.text) ?? 1024;
    final newHeight = (currentWidth * heightRatio / widthRatio).round();

    setState(() {
      _heightController.text = newHeight.toString();
      _aspectRatio = widthRatio / heightRatio;
      _selectedPreset = null;
    });
  }

  bool _isValid() {
    final width = int.tryParse(_widthController.text);
    final height = int.tryParse(_heightController.text);
    return width != null &&
        height != null &&
        width >= 64 &&
        width <= 4096 &&
        height >= 64 &&
        height <= 4096;
  }

  void _confirm() {
    final width = int.tryParse(_widthController.text);
    final height = int.tryParse(_heightController.text);
    if (width != null && height != null) {
      Navigator.pop(context, Size(width.toDouble(), height.toDouble()));
    }
  }
}

/// 比例快捷按钮
class _RatioChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _RatioChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
    );
  }
}
