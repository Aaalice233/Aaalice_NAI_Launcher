import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/comfyui/comfyui_models.dart';
import '../../../../core/comfyui/workflow_template.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../adaptive/adaptive_presenter.dart';
import '../../../providers/comfyui/comfyui_provider.dart';
import '../../../utils/comfyui_workflow_l10n.dart';
import '../../../widgets/common/app_toast.dart';

/// 通用 ComfyUI 工作流执行对话框
///
/// 根据 [WorkflowTemplate] 的 slots 动态渲染参数 UI，
/// 支持输入图像选择、参数调节、执行和结果展示。
class ComfyUIWorkflowDialog extends ConsumerStatefulWidget {
  final WorkflowTemplate template;
  final Uint8List? initialImage;
  final Uint8List? initialMask;
  final ScrollController? scrollController;

  const ComfyUIWorkflowDialog({
    super.key,
    required this.template,
    this.initialImage,
    this.initialMask,
    this.scrollController,
  });

  static Future<List<Uint8List>?> show(
    BuildContext context, {
    required WorkflowTemplate template,
    Uint8List? image,
    Uint8List? mask,
  }) {
    return AdaptivePresenter.showForm<List<Uint8List>>(
      context: context,
      width: 560,
      titleBuilder: (panelContext) {
        final theme = Theme.of(panelContext);
        return Row(
          children: [
            Icon(
              template.isBuiltin ? Icons.auto_fix_high : Icons.account_tree,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.localizedName(panelContext),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                  if (MediaQuery.textScalerOf(panelContext).scale(1) < 2 &&
                      template.localizedDescription(panelContext).isNotEmpty)
                    Text(
                      template.localizedDescription(panelContext),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
      builder: (panelContext, scrollController) => ComfyUIWorkflowDialog(
        template: template,
        initialImage: image,
        initialMask: mask,
        scrollController: scrollController,
      ),
    );
  }

  @override
  ConsumerState<ComfyUIWorkflowDialog> createState() =>
      _ComfyUIWorkflowDialogState();
}

class _ComfyUIWorkflowDialogState extends ConsumerState<ComfyUIWorkflowDialog> {
  final Map<String, Uint8List> _inputImages = {};
  final Map<String, dynamic> _paramValues = {};
  List<Uint8List>? _results;

  @override
  void initState() {
    super.initState();
    // 初始化参数默认值
    for (final slot in widget.template.parameterSlots) {
      _paramValues[slot.id] = slot.defaultValue;
    }
    // 预填充初始图像
    if (widget.initialImage != null) {
      final firstInputSlot = widget.template.inputSlots
          .where((s) => s.dataType == SlotDataType.image)
          .firstOrNull;
      if (firstInputSlot != null) {
        _inputImages[firstInputSlot.id] = widget.initialImage!;
      }
    }
    if (widget.initialMask != null) {
      final maskSlot = widget.template.inputSlots
          .where((s) => s.dataType == SlotDataType.mask)
          .firstOrNull;
      if (maskSlot != null) {
        _inputImages[maskSlot.id] = widget.initialMask!;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final taskState = ref.watch(comfyUITaskProvider);
    final taskError = taskState.localizedError(context.l10n);

    return Column(
      children: [
        Expanded(
          child: ListView(
            key: const Key('comfy-workflow-form-scroll'),
            controller: widget.scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(16),
            children: [
              ...widget.template.inputSlots.map(
                (slot) => _buildImageInput(theme, slot),
              ),
              if (widget.template.parameterSlots.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  context.l10n.comfyWorkflow_parameters,
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                ...widget.template.parameterSlots.map(
                  (slot) => _buildParameterInput(theme, slot),
                ),
              ],
              const SizedBox(height: 16),
              if (taskState.isRunning)
                _buildProgress(theme, taskState)
              else if (taskState.status == ComfyUITaskStatus.failed &&
                  taskError != null)
                _buildError(theme, taskError)
              else if (_results != null && _results!.isNotEmpty)
                _buildResults(theme),
            ],
          ),
        ),
        _buildFooter(taskState),
      ],
    );
  }

  Widget _buildFooter(ComfyUITaskState taskState) {
    final canExecute = !taskState.isRunning && _checkRequiredInputs();
    final actions = <Widget>[
      if (_results != null && _results!.isNotEmpty)
        FilledButton.tonal(
          onPressed: () => Navigator.of(context).pop(_results),
          child: Text(context.l10n.comfyWorkflow_useResult),
        ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(context.l10n.common_close),
      ),
      if (!taskState.isRunning)
        FilledButton.icon(
          onPressed: canExecute ? _execute : null,
          icon: const Icon(Icons.play_arrow, size: 18),
          label: Text(context.l10n.comfyWorkflow_execute),
        )
      else
        TextButton.icon(
          onPressed: () => ref.read(comfyUITaskProvider.notifier).cancel(),
          icon: const Icon(Icons.stop, size: 18),
          label: Text(context.l10n.common_cancel),
        ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(1) >= 2;
        return SingleChildScrollView(
          key: const Key('comfy-workflow-actions-scroll'),
          scrollDirection: largeText ? Axis.horizontal : Axis.vertical,
          padding: const EdgeInsets.all(12),
          child: SafeArea(
            top: false,
            child: largeText
                ? Row(
                    key: const Key('comfy-workflow-actions'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var index = 0; index < actions.length; index++) ...[
                        if (index > 0) const SizedBox(width: 8),
                        actions[index],
                      ],
                    ],
                  )
                : Wrap(
                    key: const Key('comfy-workflow-actions'),
                    alignment: constraints.maxWidth < 420
                        ? WrapAlignment.center
                        : WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: actions,
                  ),
          ),
        );
      },
    );
  }

  bool _checkRequiredInputs() {
    for (final slot in widget.template.inputSlots) {
      if (slot.required && !_inputImages.containsKey(slot.id)) {
        return false;
      }
    }
    return true;
  }

  // ==================== 输入图像 ====================

  Widget _buildImageInput(ThemeData theme, WorkflowSlot slot) {
    final hasImage = _inputImages.containsKey(slot.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                slot.localizedLabel(context),
                style: theme.textTheme.titleSmall,
              ),
              if (slot.required)
                Text(' *', style: TextStyle(color: theme.colorScheme.error)),
            ],
          ),
          const SizedBox(height: 8),
          if (hasImage)
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    _inputImages[slot.id]!,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _MiniButton(
                        icon: Icons.refresh,
                        onPressed: () => _pickImageForSlot(slot.id),
                      ),
                      const SizedBox(width: 4),
                      _MiniButton(
                        icon: Icons.close,
                        onPressed: () =>
                            setState(() => _inputImages.remove(slot.id)),
                      ),
                    ],
                  ),
                ),
              ],
            )
          else
            InkWell(
              onTap: () => _pickImageForSlot(slot.id),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        slot.dataType == SlotDataType.mask
                            ? Icons.format_paint
                            : Icons.add_photo_alternate_outlined,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.l10n.comfyWorkflow_selectImage,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickImageForSlot(String slotId) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      Uint8List? bytes;
      if (file.bytes != null) {
        bytes = file.bytes;
      } else if (file.path != null) {
        bytes = await File(file.path!).readAsBytes();
      }
      if (bytes != null) {
        setState(() => _inputImages[slotId] = bytes!);
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(context, context.l10n.comfyWorkflow_pickImageFailed(e));
      }
    }
  }

  // ==================== 参数 ====================

  Widget _buildParameterInput(ThemeData theme, WorkflowSlot slot) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: switch (slot.dataType) {
        SlotDataType.choice => _buildChoiceInput(theme, slot),
        SlotDataType.integer => _buildIntegerInput(theme, slot),
        SlotDataType.number => _buildNumberInput(theme, slot),
        SlotDataType.boolean => _buildBoolInput(theme, slot),
        SlotDataType.string => _buildStringInput(theme, slot),
        _ => _buildStringInput(theme, slot),
      },
    );
  }

  Widget _buildChoiceInput(ThemeData theme, WorkflowSlot slot) {
    final choices = slot.choices ?? [];
    final current =
        _paramValues[slot.id]?.toString() ??
        slot.defaultValue?.toString() ??
        (choices.isNotEmpty ? choices.first : '');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(slot.localizedLabel(context), style: theme.textTheme.bodyMedium),
        const SizedBox(height: 4),
        if (choices.length <= 5)
          Wrap(
            spacing: 6,
            children: choices.map((c) {
              return ChoiceChip(
                label: Text(c),
                selected: current == c,
                onSelected: (_) => setState(() => _paramValues[slot.id] = c),
              );
            }).toList(),
          )
        else
          DropdownButtonFormField<String>(
            initialValue: choices.contains(current) ? current : null,
            decoration: InputDecoration(
              isDense: true,
              labelText: slot.localizedLabel(context),
            ),
            items: choices
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (v) {
              if (v != null) setState(() => _paramValues[slot.id] = v);
            },
          ),
      ],
    );
  }

  Widget _buildIntegerInput(ThemeData theme, WorkflowSlot slot) {
    final val = (_paramValues[slot.id] ?? slot.defaultValue ?? 0) as num;
    final hasRange = slot.min != null && slot.max != null;

    if (hasRange && (slot.max! - slot.min!) <= 100) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                slot.localizedLabel(context),
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                val.toInt().toString(),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Slider(
            value: val.toDouble().clamp(slot.min!, slot.max!),
            min: slot.min!,
            max: slot.max!,
            divisions: ((slot.max! - slot.min!) / (slot.step ?? 1)).round(),
            onChanged: (v) => setState(() => _paramValues[slot.id] = v.round()),
          ),
        ],
      );
    }

    return TextFormField(
      initialValue: val.toInt().toString(),
      decoration: InputDecoration(
        labelText: slot.localizedLabel(context),
        isDense: true,
      ),
      keyboardType: TextInputType.number,
      onChanged: (v) {
        final parsed = int.tryParse(v);
        if (parsed != null) _paramValues[slot.id] = parsed;
      },
    );
  }

  Widget _buildNumberInput(ThemeData theme, WorkflowSlot slot) {
    final val = (_paramValues[slot.id] ?? slot.defaultValue ?? 0.0) as num;
    final hasRange = slot.min != null && slot.max != null;

    if (hasRange) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                slot.localizedLabel(context),
                style: theme.textTheme.bodyMedium,
              ),
              Text(
                val.toStringAsFixed(2),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Slider(
            value: val.toDouble().clamp(slot.min!, slot.max!),
            min: slot.min!,
            max: slot.max!,
            divisions: slot.step != null
                ? ((slot.max! - slot.min!) / slot.step!).round()
                : null,
            onChanged: (v) => setState(() => _paramValues[slot.id] = v),
          ),
        ],
      );
    }

    return TextFormField(
      initialValue: val.toString(),
      decoration: InputDecoration(
        labelText: slot.localizedLabel(context),
        isDense: true,
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: (v) {
        final parsed = double.tryParse(v);
        if (parsed != null) _paramValues[slot.id] = parsed;
      },
    );
  }

  Widget _buildBoolInput(ThemeData theme, WorkflowSlot slot) {
    final val =
        _paramValues[slot.id] as bool? ?? slot.defaultValue as bool? ?? false;
    return SwitchListTile(
      title: Text(slot.localizedLabel(context)),
      value: val,
      dense: true,
      contentPadding: EdgeInsets.zero,
      onChanged: (v) => setState(() => _paramValues[slot.id] = v),
    );
  }

  Widget _buildStringInput(ThemeData theme, WorkflowSlot slot) {
    // 如果有 choices 且类型是 string，视为选择
    if (slot.choices != null && slot.choices!.isNotEmpty) {
      return _buildChoiceInput(theme, slot);
    }

    return TextFormField(
      initialValue: (_paramValues[slot.id] ?? slot.defaultValue ?? '')
          .toString(),
      decoration: InputDecoration(
        labelText: slot.localizedLabel(context),
        isDense: true,
      ),
      onChanged: (v) => _paramValues[slot.id] = v,
    );
  }

  // ==================== 进度/结果 ====================

  Widget _buildProgress(ThemeData theme, ComfyUITaskState taskState) {
    final statusText = switch (taskState.status) {
      ComfyUITaskStatus.uploading => context.l10n.comfyWorkflow_uploadingImage,
      ComfyUITaskStatus.queued => context.l10n.comfyWorkflow_queued,
      ComfyUITaskStatus.running =>
        taskState.totalSteps > 0
            ? context.l10n.comfyWorkflow_runningSteps(
                taskState.currentStep,
                taskState.totalSteps,
              )
            : context.l10n.comfyWorkflow_processing,
      _ => context.l10n.comfyWorkflow_processing,
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          if (taskState.hasPreview) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                taskState.previewImage!,
                height: 160,
                width: double.infinity,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
          ],
          Text(statusText, style: theme.textTheme.bodyMedium),
          if (taskState.progress > 0) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: taskState.progress),
            const SizedBox(height: 4),
            Text(
              '${(taskState.progress * 100).toInt()}%',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError(ThemeData theme, String error) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Icon(
              Icons.check_circle,
              color: theme.colorScheme.primary,
              size: 20,
            ),
            Text(
              context.l10n.comfyWorkflow_complete,
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            Text(
              context.l10n.comfyWorkflow_imageCount(_results!.length),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._results!.map(
          (img) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                img,
                height: 180,
                width: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==================== 执行 ====================

  Future<void> _execute() async {
    final results = await ref
        .read(comfyUITaskProvider.notifier)
        .execute(
          templateId: widget.template.id,
          inputImages: _inputImages,
          paramValues: _paramValues,
        );

    if (results != null && results.isNotEmpty && mounted) {
      setState(() => _results = results);
    }
  }
}

class _MiniButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;

  const _MiniButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}
