import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../data/models/image/image_params.dart';
import '../../../providers/image_generation_provider.dart';

/// Vibe Transfer 面板组件
class VibeTransferPanel extends ConsumerStatefulWidget {
  const VibeTransferPanel({super.key});

  @override
  ConsumerState<VibeTransferPanel> createState() => _VibeTransferPanelState();
}

class _VibeTransferPanelState extends ConsumerState<VibeTransferPanel> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final params = ref.watch(generationParamsNotifierProvider);
    final hasVibes = params.vibeReferences.isNotEmpty;

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题栏
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 20,
                    color: hasVibes
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vibe Transfer',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: hasVibes ? theme.colorScheme.primary : null,
                      ),
                    ),
                  ),
                  if (hasVibes)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${params.vibeReferences.length}/4',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // 展开内容
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(),

                  // 说明文字
                  Text(
                    '添加参考图片来迁移其视觉风格和氛围（最多4张）',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 参考图列表
                  if (hasVibes) ...[
                    ...List.generate(params.vibeReferences.length, (index) {
                      return _VibeReferenceItem(
                        index: index,
                        vibe: params.vibeReferences[index],
                        onRemove: () => _removeVibe(index),
                        onStrengthChanged: (value) =>
                            _updateVibeStrength(index, value),
                        onInfoExtractedChanged: (value) =>
                            _updateVibeInfoExtracted(index, value),
                      );
                    }),
                    const SizedBox(height: 8),
                  ],

                  // 添加按钮
                  if (params.vibeReferences.length < 4)
                    OutlinedButton.icon(
                      onPressed: _addVibe,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('添加参考图'),
                    ),

                  // 清除全部按钮
                  if (hasVibes) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _clearAllVibes,
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text('清除全部'),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Future<void> _addVibe() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        Uint8List? bytes;

        if (file.bytes != null) {
          bytes = file.bytes;
        } else if (file.path != null) {
          bytes = await File(file.path!).readAsBytes();
        }

        if (bytes != null) {
          ref.read(generationParamsNotifierProvider.notifier)
              .addVibeReference(VibeReference(image: bytes));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择图片失败: $e')),
        );
      }
    }
  }

  void _removeVibe(int index) {
    ref.read(generationParamsNotifierProvider.notifier)
        .removeVibeReference(index);
  }

  void _updateVibeStrength(int index, double value) {
    ref.read(generationParamsNotifierProvider.notifier)
        .updateVibeReference(index, strength: value);
  }

  void _updateVibeInfoExtracted(int index, double value) {
    ref.read(generationParamsNotifierProvider.notifier)
        .updateVibeReference(index, informationExtracted: value);
  }

  void _clearAllVibes() {
    ref.read(generationParamsNotifierProvider.notifier).clearVibeReferences();
  }
}

/// 单个 Vibe 参考图项
class _VibeReferenceItem extends StatefulWidget {
  final int index;
  final VibeReference vibe;
  final VoidCallback onRemove;
  final ValueChanged<double> onStrengthChanged;
  final ValueChanged<double> onInfoExtractedChanged;

  const _VibeReferenceItem({
    required this.index,
    required this.vibe,
    required this.onRemove,
    required this.onStrengthChanged,
    required this.onInfoExtractedChanged,
  });

  @override
  State<_VibeReferenceItem> createState() => _VibeReferenceItemState();
}

class _VibeReferenceItemState extends State<_VibeReferenceItem> {
  bool _showSliders = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // 图像预览和基本操作
          Row(
            children: [
              // 预览缩略图
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(7),
                  bottomLeft: Radius.circular(7),
                ),
                child: Image.memory(
                  widget.vibe.image,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),

              // 信息和调整
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '参考图 #${widget.index + 1}',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '强度: ${widget.vibe.strength.toStringAsFixed(2)} | '
                      '信息提取: ${widget.vibe.informationExtracted.toStringAsFixed(2)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),

              // 操作按钮
              IconButton(
                icon: Icon(
                  _showSliders ? Icons.tune : Icons.tune_outlined,
                  size: 20,
                ),
                onPressed: () => setState(() => _showSliders = !_showSliders),
                tooltip: '调整参数',
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: widget.onRemove,
                tooltip: '移除',
              ),
            ],
          ),

          // 可展开的滑块区域
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 150),
            crossFadeState: _showSliders
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                children: [
                  // 强度滑块
                  Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          '参考强度',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: widget.vibe.strength,
                          min: 0.0,
                          max: 1.0,
                          divisions: 100,
                          onChanged: widget.onStrengthChanged,
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          widget.vibe.strength.toStringAsFixed(2),
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),

                  // 信息提取滑块
                  Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text(
                          '信息提取',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      Expanded(
                        child: Slider(
                          value: widget.vibe.informationExtracted,
                          min: 0.0,
                          max: 1.0,
                          divisions: 100,
                          onChanged: widget.onInfoExtractedChanged,
                        ),
                      ),
                      SizedBox(
                        width: 40,
                        child: Text(
                          widget.vibe.informationExtracted.toStringAsFixed(2),
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),

                  // 说明
                  Text(
                    '强度: 越高越模仿视觉线索\n信息提取: 降低会减少纹理、保留构图',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
