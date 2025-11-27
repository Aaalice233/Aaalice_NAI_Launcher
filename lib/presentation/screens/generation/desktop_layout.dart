import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../providers/image_generation_provider.dart';
import '../../widgets/common/themed_container.dart';
import '../../widgets/common/themed_button.dart';
import 'widgets/parameter_panel.dart';
import 'widgets/prompt_input.dart';
import 'widgets/image_preview.dart';
import 'widgets/history_panel.dart';

/// 桌面端三栏布局
class DesktopGenerationLayout extends ConsumerWidget {
  const DesktopGenerationLayout({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Row(
      children: [
        // 左侧栏 - 参数面板
        ThemedContainer(
          width: 300,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              right: BorderSide(
                color: theme.dividerColor,
                width: 1,
              ),
            ),
          ),
          child: const ParameterPanel(),
        ),

        // 中间 - 主工作区
        Expanded(
          child: Column(
            children: [
              // 顶部 Prompt 输入区
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.5),
                  border: Border(
                    bottom: BorderSide(
                      color: theme.dividerColor,
                      width: 1,
                    ),
                  ),
                ),
                child: const PromptInputWidget(),
              ),

              // 中间图像预览区
              const Expanded(
                child: ImagePreviewWidget(),
              ),

              // 底部生成控制区
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withOpacity(0.5),
                  border: Border(
                    top: BorderSide(
                      color: theme.dividerColor,
                      width: 1,
                    ),
                  ),
                ),
                child: const GenerationControls(),
              ),
            ],
          ),
        ),

        // 右侧栏 - 历史面板
        ThemedContainer(
          width: 280,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              left: BorderSide(
                color: theme.dividerColor,
                width: 1,
              ),
            ),
          ),
          child: const HistoryPanel(),
        ),
      ],
    );
  }
}

/// 生成控制按钮
class GenerationControls extends ConsumerWidget {
  const GenerationControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final generationState = ref.watch(imageGenerationNotifierProvider);
    final params = ref.watch(generationParamsNotifierProvider);
    final isGenerating = generationState.isGenerating;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 生成按钮
        SizedBox(
          width: 200,
          height: 48,
          child: ThemedButton(
            onPressed: isGenerating
                ? null
                : () {
                    if (params.prompt.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('请输入提示词')),
                      );
                      return;
                    }
                    ref.read(imageGenerationNotifierProvider.notifier)
                        .generate(params);
                  },
            icon: isGenerating
                ? null 
                : const Icon(Icons.auto_awesome),
            isLoading: isGenerating,
            label: Text(isGenerating ? '生成中...' : '生成'),
            style: ThemedButtonStyle.filled,
          ),
        ),

        const SizedBox(width: 16),

        // 取消按钮 (仅在生成中显示)
        if (isGenerating)
          ThemedButton(
            onPressed: () {
              ref.read(imageGenerationNotifierProvider.notifier).cancel();
            },
            icon: const Icon(Icons.stop),
            label: const Text('取消'),
            style: ThemedButtonStyle.outlined,
          ),

        // 保存按钮 (仅在有图像时显示)
        if (!isGenerating && generationState.hasImages)
          ThemedButton(
            onPressed: () {
              // TODO: 实现保存功能
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('保存功能开发中...')),
              );
            },
            icon: const Icon(Icons.save_alt),
            label: const Text('保存'),
            style: ThemedButtonStyle.outlined,
          ),
      ],
    );
  }
}

