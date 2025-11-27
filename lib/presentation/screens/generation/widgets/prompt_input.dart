import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/image_generation_provider.dart';

/// Prompt 输入组件
class PromptInputWidget extends ConsumerStatefulWidget {
  final bool compact;

  const PromptInputWidget({super.key, this.compact = false});

  @override
  ConsumerState<PromptInputWidget> createState() => _PromptInputWidgetState();
}

class _PromptInputWidgetState extends ConsumerState<PromptInputWidget> {
  final _promptController = TextEditingController();
  final _negativeController = TextEditingController();
  bool _showNegative = false;

  @override
  void initState() {
    super.initState();
    final params = ref.read(generationParamsNotifierProvider);
    _promptController.text = params.prompt;
    _negativeController.text = params.negativePrompt;
  }

  @override
  void dispose() {
    _promptController.dispose();
    _negativeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.compact) {
      return _buildCompactLayout(theme);
    }

    return _buildFullLayout(theme);
  }

  Widget _buildFullLayout(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 正向提示词
        TextField(
          controller: _promptController,
          decoration: InputDecoration(
            labelText: '提示词 (Prompt)',
            hintText: '描述你想要生成的图像...',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _promptController.clear();
                ref.read(generationParamsNotifierProvider.notifier)
                    .updatePrompt('');
              },
            ),
          ),
          maxLines: 3,
          minLines: 2,
          onChanged: (value) {
            ref.read(generationParamsNotifierProvider.notifier)
                .updatePrompt(value);
          },
        ),

        const SizedBox(height: 8),

        // 展开/折叠负向提示词
        InkWell(
          onTap: () {
            setState(() {
              _showNegative = !_showNegative;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  _showNegative
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_right,
                  size: 20,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  '负向提示词',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 负向提示词 (可折叠)
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _showNegative
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          firstChild: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextField(
              controller: _negativeController,
              decoration: InputDecoration(
                labelText: '负向提示词 (Undesired Content)',
                hintText: '不想出现在图像中的内容...',
                border: const OutlineInputBorder(),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              ),
              maxLines: 2,
              minLines: 1,
              style: theme.textTheme.bodySmall,
              onChanged: (value) {
                ref.read(generationParamsNotifierProvider.notifier)
                    .updateNegativePrompt(value);
              },
            ),
          ),
          secondChild: const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildCompactLayout(ThemeData theme) {
    return TextField(
      controller: _promptController,
      decoration: InputDecoration(
        hintText: '输入提示词...',
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_promptController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, size: 20),
                onPressed: () {
                  _promptController.clear();
                  ref.read(generationParamsNotifierProvider.notifier)
                      .updatePrompt('');
                },
              ),
          ],
        ),
      ),
      maxLines: 2,
      minLines: 1,
      onChanged: (value) {
        ref.read(generationParamsNotifierProvider.notifier)
            .updatePrompt(value);
      },
    );
  }
}
