import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../data/models/queue/replication_task.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../adaptive/window_size_class.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/replication_queue_provider.dart';
import '../autocomplete/autocomplete_config.dart';
import '../common/adaptive_dialog_frame.dart';
import '../common/app_toast.dart';
import '../autocomplete/autocomplete_wrapper.dart';
import '../prompt/prompt_formatter_wrapper.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';

import 'queue_task_thumbnail.dart';

/// 任务编辑对话框
class TaskEditDialog extends ConsumerStatefulWidget {
  final ReplicationTask task;
  final ScrollController? scrollController;
  final bool? compactLayout;

  const TaskEditDialog({
    super.key,
    required this.task,
    this.scrollController,
    this.compactLayout,
  });

  static Future<bool?> show({
    required BuildContext context,
    required ReplicationTask task,
  }) {
    final compactLayout = context.adaptiveWindow.isCompact;
    return AdaptivePresenter.showForm<bool>(
      context: context,
      titleBuilder: (panelContext) => Row(
        children: [
          const Icon(Icons.edit),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              panelContext.l10n.queue_editTask,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(panelContext).textTheme.titleLarge,
            ),
          ),
        ],
      ),
      width: 560,
      builder: (panelContext, scrollController) => TaskEditDialog(
        task: task,
        scrollController: scrollController,
        compactLayout: compactLayout,
      ),
    );
  }

  @override
  ConsumerState<TaskEditDialog> createState() => _TaskEditDialogState();
}

class _TaskEditDialogState extends ConsumerState<TaskEditDialog> {
  late TextEditingController _promptController;
  late FocusNode _promptFocusNode;
  bool _showParameters = false;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;

    final content = SingleChildScrollView(
      key: const Key('task-edit-dialog-scroll'),
      controller: widget.scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 内容区域
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 缩略图预览
                if (widget.task.thumbnailUrl != null &&
                    widget.task.thumbnailUrl!.isNotEmpty)
                  Center(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: QueueTaskThumbnail(
                        source: widget.task.thumbnailUrl!,
                        width: 150,
                        height: 150,
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

          const Divider(height: 1),

          // 操作按钮在窄屏、大字号和短视口中自动换行并随内容滚动。
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Wrap(
                alignment: WrapAlignment.end,
                spacing: 8,
                runSpacing: 8,
                children: [
                  TextButton.icon(
                    key: const Key('task-edit-duplicate'),
                    onPressed: _duplicateTask,
                    icon: const Icon(Icons.copy),
                    label: Text(l10n.queue_duplicateTask),
                  ),
                  TextButton(
                    key: const Key('task-edit-cancel'),
                    onPressed: () => Navigator.pop(context),
                    child: Text(l10n.common_cancel),
                  ),
                  FilledButton(
                    key: const Key('task-edit-save'),
                    onPressed: _saveTask,
                    child: Text(l10n.common_save),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    if (widget.compactLayout ?? context.adaptiveWindow.isCompact) {
      return content;
    }

    return AdaptiveDialogFrame(
      maxWidth: 560,
      maxHeight: 720,
      reservedVerticalSpace: 80,
      scaleReservedVerticalSpace: true,
      horizontalMargin: 0,
      child: content,
    );
  }

  Widget _buildPromptEditor(
    BuildContext context,
    ThemeData theme,
    AppLocalizations l10n,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标题
        Text(l10n.queue_positivePrompt, style: theme.textTheme.titleSmall),
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
              config: const AutocompleteConfig(autoInsertComma: true),
              maxLines: 6,
              expands: false,
              contentPadding: const EdgeInsets.all(12),
              child: ThemedInput(
                controller: _promptController,
                focusNode: _promptFocusNode,
                maxLines: 6,
                minLines: 6,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.all(12),
                  hintText: l10n.queue_enterPositivePrompt,
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
    final hasParameters =
        task.seed != null ||
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
          key: const Key('task-edit-parameters-toggle'),
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackValues =
              constraints.maxWidth < 360 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.5;
          final labelWidget = Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          );
          final valueWidget = Text(
            value,
            textAlign: stackValues ? TextAlign.start : TextAlign.end,
          );

          if (stackValues) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelWidget, const SizedBox(height: 2), valueWidget],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              labelWidget,
              const SizedBox(width: 12),
              Expanded(child: valueWidget),
            ],
          );
        },
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
        AppToast.success(context, l10n.queue_taskDuplicated);
      } else {
        AppToast.warning(context, l10n.queue_queueFull);
      }
    }
  }
}
