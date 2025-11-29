import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/image_generation_provider.dart';
import '../../widgets/common/themed_scaffold.dart';
import '../../widgets/common/themed_button.dart';
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final generationState = ref.watch(imageGenerationNotifierProvider);
    final params = ref.watch(generationParamsNotifierProvider);
    final theme = Theme.of(context);

    return ThemedScaffold(
      // 使用 GlobalKey 来控制 Drawer
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('生成'),
        actions: [
          // 参数设置按钮 (打开侧边抽屉)
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () {
               _scaffoldKey.currentState?.openEndDrawer();
            },
            tooltip: '参数设置',
          ),
        ],
      ),
      endDrawer: Drawer(
        width: 300,
        child: SafeArea(
          child: Column(
            children: [
               Padding(
                 padding: const EdgeInsets.all(16.0),
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Text('生成参数', style: theme.textTheme.titleLarge),
                     IconButton(
                       icon: const Icon(Icons.close),
                       onPressed: () => Navigator.pop(context),
                     ),
                   ],
                 ),
               ),
               const Divider(),
               const Expanded(
                 child: ParameterPanel(),
               ),
            ],
          ),
        ),
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
          child: SizedBox(
            width: double.infinity,
            child: ThemedButton(
              onPressed: generationState.isGenerating
                  ? () {
                      ref.read(imageGenerationNotifierProvider.notifier).cancel();
                    }
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
                  ? const Icon(Icons.stop)
                  : const Icon(Icons.auto_awesome),
              isLoading: false,
              label: Text(generationState.isGenerating ? '取消生成' : '生成'),
              style: generationState.isGenerating
                  ? ThemedButtonStyle.outlined
                  : ThemedButtonStyle.filled,
            ),
          ),
        ),
      ),
    );
  }
}

