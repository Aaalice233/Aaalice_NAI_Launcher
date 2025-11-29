import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/image/image_params.dart';
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
        title: Text(context.l10n.generation_title),
        actions: [
          // 参数设置按钮 (打开侧边抽屉)
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () {
               _scaffoldKey.currentState?.openEndDrawer();
            },
            tooltip: context.l10n.generation_paramsSettings,
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
                     Text(context.l10n.generation_paramsSettings, style: theme.textTheme.titleLarge),
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
                    context.l10n.generation_progress((generationState.progress * 100).toInt().toString()),
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
              // 抽卡模式开关
              _MobileRandomModeToggle(
                enabled: ref.watch(randomPromptModeProvider),
              ),
              const SizedBox(width: 12),
              // 生成按钮
              Expanded(
                child: ThemedButton(
                  onPressed: generationState.isGenerating
                      ? () {
                          ref.read(imageGenerationNotifierProvider.notifier).cancel();
                        }
                      : () {
                          _handleGenerate(context, ref, params);
                        },
                  icon: generationState.isGenerating
                      ? const Icon(Icons.stop)
                      : const Icon(Icons.auto_awesome),
                  isLoading: false,
                  label: Text(generationState.isGenerating ? context.l10n.generation_cancelGeneration : context.l10n.generation_generate),
                  style: generationState.isGenerating
                      ? ThemedButtonStyle.outlined
                      : ThemedButtonStyle.filled,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleGenerate(BuildContext context, WidgetRef ref, ImageParams params) {
    if (params.prompt.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.generation_pleaseInputPrompt)),
      );
      return;
    }
    
    // 生成（抽卡模式逻辑在 generate 方法内部处理）
    ref.read(imageGenerationNotifierProvider.notifier).generate(params);
  }
}

/// 移动端抽卡模式开关
class _MobileRandomModeToggle extends ConsumerWidget {
  final bool enabled;
  
  const _MobileRandomModeToggle({required this.enabled});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    return Tooltip(
      message: enabled 
          ? context.l10n.randomMode_enabledTip
          : context.l10n.randomMode_disabledTip,
      child: GestureDetector(
        onTap: () {
          ref.read(randomPromptModeProvider.notifier).toggle();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: enabled
                ? theme.colorScheme.primary.withOpacity(0.15)
                : theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: enabled
                  ? theme.colorScheme.primary.withOpacity(0.5)
                  : theme.colorScheme.outline.withOpacity(0.3),
              width: enabled ? 1.5 : 1,
            ),
          ),
          child: Icon(
            Icons.casino_outlined,
            size: 22,
            color: enabled
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
      ),
    );
  }
}


