import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../data/models/queue/replication_task.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/replication_queue_provider.dart';
import '../autocomplete/autocomplete_controller.dart';
import '../autocomplete/autocomplete_wrapper.dart';
import '../autocomplete/autocomplete_strategy.dart';
import '../autocomplete/strategies/local_tag_strategy.dart';
import '../autocomplete/strategies/alias_strategy.dart';
import '../common/inset_shadow_container.dart';
import '../prompt/prompt_formatter_wrapper.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';

/// 任务编辑对话框
class TaskEditDialog extends ConsumerStatefulWidget {
  final ReplicationTask task;

  const TaskEditDialog({
    super.key,
    required this.task,
  });

  @override
  ConsumerState<TaskEditDialog> createState() => _TaskEditDialogState();
}

class _TaskEditDialogState extends ConsumerState<TaskEditDialog> {
  late TextEditingController _promptController;
  late FocusNode _promptFocusNode;
  bool _showParameters = false;

  /// 自动补全策略 Future（异步初始化）
  Future<AutocompleteStrategy>? _autocompleteStrategyFuture;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController(text: widget.task.prompt);
    _promptFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _promptController.dispose();
    _promptFocusNode.dispose();
    super.dispose();
  }

  /// 确保自动补全策略 Future 已创建
  Future<AutocompleteStrategy> _ensureAutocompleteStrategyFuture() {
    _autocompleteStrategyFuture ??= LocalTagStrategy.create(
      ref,
      const AutocompleteConfig(
        maxSuggestions: 15,
        showTranslation: true,
        showCategory: true,
        autoInsertComma: true,
      ),
    ).then((localTagStrategy) {
      return CompositeStrategy(
        strategies: [
          localTagStrategy,
          AliasStrategy.create(ref),
        ],
        strategySelector: defaultStrategySelector,
      );
    });
    return _autocompleteStrategyFuture!;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    return Dialog(
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.edit),
                  const SizedBox(width: 8),
                  Text(
                    l10n.queue_editTask,
                    style: theme.textTheme.titleLarge,
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // 内容区域
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 缩略图预览
                    if (widget.task.thumbnailUrl != null)
                      Center(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: CachedNetworkImage(
                            imageUrl: widget.task.thumbnailUrl!,
                            width: 150,
                            height: 150,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 150,
                              height: 150,
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 150,
                              height: 150,
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: const Icon(Icons.broken_image, size: 48),
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // 提示词编辑器（只有正面提示词）
                    _buildPromptEditor(context, theme, l10n),

                    const SizedBox(height: 16),

                    // 参数预览（可展开）
                    _buildParametersSection(context, theme),
                  ],
                ),
              ),
            ),

            const Divider(height: 1),

            // 操作按钮
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 复制任务
                  TextButton.icon(
                    onPressed: _duplicateTask,
                    icon: const Icon(Icons.copy),
                    label: Text(l10n.queue_duplicateTask),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.common_cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saveTask,
                    child: Text(l10n.common_save),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptEditor(
    BuildContext context,
    ThemeData theme,
    dynamic l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        Text(
          l10n.queue_positivePrompt,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        // 提示词编辑器
        SizedBox(
          height: 160,
          child: PromptFormatterWrapper(
            controller: _promptController,
            focusNode: _promptFocusNode,
            enableAutoFormat: ref.watch(autoFormatPromptSettingsProvider),
            child: AutocompleteWrapper(
              controller: _promptController,
              focusNode: _promptFocusNode,
              asyncStrategy: _ensureAutocompleteStrategyFuture(),
              maxLines: 6,
              expands: false,
              contentPadding: const EdgeInsets.all(12),
              child: InsetShadowContainer(
                borderRadius: 8,
                child: ThemedInput(
                  controller: _promptController,
                  maxLines: 6,
                  minLines: 6,
                  textAlignVertical: TextAlignVertical.top,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.all(12),
                    hintText: l10n.queue_enterPositivePrompt,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // 提示信息
        Text(
          l10n.queue_negativePromptFromMain,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }

  Widget _buildParametersSection(BuildContext context, ThemeData theme) {
    final l10n = context.l10n;
    final task = widget.task;
    final hasParameters = task.seed != null ||
        task.sampler != null ||
        task.steps != null ||
        task.cfgScale != null ||
        task.model != null ||
        task.width != null ||
        task.height != null;

    if (!hasParameters) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _showParameters = !_showParameters),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  _showParameters ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text(
                  l10n.queue_parametersPreview,
                  style: theme.textTheme.titleSmall,
                ),
              ],
            ),
          ),
        ),
        if (_showParameters)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                if (task.model != null)
                  _buildParamRow(l10n.queue_model, task.model!),
                if (task.seed != null)
                  _buildParamRow(l10n.queue_seed, task.seed.toString()),
                if (task.sampler != null)
                  _buildParamRow(l10n.queue_sampler, task.sampler!),
                if (task.steps != null)
                  _buildParamRow(l10n.queue_steps, task.steps.toString()),
                if (task.cfgScale != null)
                  _buildParamRow(
                    l10n.queue_cfg,
                    task.cfgScale!.toStringAsFixed(1),
                  ),
                if (task.width != null && task.height != null)
                  _buildParamRow(
                    l10n.queue_size,
                    '${task.width} x ${task.height}',
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildParamRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }

  void _saveTask() {
    final updatedTask = widget.task.copyWith(
      prompt: _promptController.text.trim(),
      // 不更新 negativePrompt，执行时会使用主界面设置
    );

    ref.read(replicationQueueNotifierProvider.notifier).updateTask(updatedTask);
    Navigator.pop(context, true);
  }

  Future<void> _duplicateTask() async {
    final l10n = context.l10n;
    final success = await ref
        .read(replicationQueueNotifierProvider.notifier)
        .duplicateTask(widget.task.id);

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.queue_taskDuplicated)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.queue_queueFull)),
        );
      }
    }
  }
}
