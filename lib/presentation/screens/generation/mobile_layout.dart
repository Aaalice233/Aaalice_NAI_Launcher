import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/image_generation_provider.dart';
import 'widgets/prompt_input.dart';
import 'widgets/image_preview.dart';
import 'widgets/parameter_panel.dart';

/// 移动端单栏布局
class MobileGenerationLayout extends ConsumerStatefulWidget {
  const MobileGenerationLayout({super.key});

  @override
  ConsumerState<MobileGenerationLayout> createState() =>
      _MobileGenerationLayoutState();
}

class _MobileGenerationLayoutState
    extends ConsumerState<MobileGenerationLayout> {
  @override
  Widget build(BuildContext context) {
    final generationState = ref.watch(imageGenerationNotifierProvider);
    final params = ref.watch(generationParamsNotifierProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('生成'),
        actions: [
          // 参数设置按钮
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () => _showParameterSheet(context),
            tooltip: '参数设置',
          ),
        ],
      ),
      body: Column(
        children: [
          // Prompt 输入区
          Container(
            padding: const EdgeInsets.all(12),
            child: const PromptInputWidget(compact: true),
          ),

          // 图像预览区
          const Expanded(
            child: ImagePreviewWidget(),
          ),

          // 生成状态和进度
          if (generationState.isGenerating)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  LinearProgressIndicator(
                    value: generationState.progress,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '生成中... ${(generationState.progress * 100).toInt()}%',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
        ],
      ),

      // 底部生成按钮
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              top: BorderSide(
                color: theme.dividerColor,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // 生成按钮
              Expanded(
                child: FilledButton.icon(
                  onPressed: generationState.isGenerating
                      ? null
                      : () {
                          if (params.prompt.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('请输入提示词')),
                            );
                            return;
                          }
                          ref
                              .read(imageGenerationNotifierProvider.notifier)
                              .generate(params);
                        },
                  icon: generationState.isGenerating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(generationState.isGenerating ? '生成中' : '生成'),
                ),
              ),

              // 取消按钮
              if (generationState.isGenerating) ...[
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () {
                    ref.read(imageGenerationNotifierProvider.notifier).cancel();
                  },
                  child: const Icon(Icons.stop),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showParameterSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // 拖动指示器
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 标题
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '生成参数',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                // 参数面板
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: const ParameterPanel(inBottomSheet: true),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
