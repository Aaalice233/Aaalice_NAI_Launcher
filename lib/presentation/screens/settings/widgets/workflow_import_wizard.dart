import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/comfyui/workflow_analyzer.dart';
import '../../../../core/comfyui/workflow_template.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../adaptive/adaptive_presenter.dart';
import '../../../providers/comfyui/comfyui_provider.dart';
import '../../../utils/comfyui_workflow_l10n.dart';
import '../../../widgets/common/app_toast.dart';

/// 工作流导入向导（多步对话框）
///
/// Step 0: 选择 JSON 文件
/// Step 1: 自动分析结果 + 元信息编辑
/// Step 2: 槽位确认/调整
/// Step 3: 确认保存
class WorkflowImportWizard extends ConsumerStatefulWidget {
  const WorkflowImportWizard({super.key, this.scrollController});

  final ScrollController? scrollController;

  static Future<void> show(BuildContext context) {
    return AdaptivePresenter.showForm<void>(
      context: context,
      sideSheetWidth: 600,
      barrierDismissible: false,
      titleBuilder: (panelContext) => Row(
        children: [
          Icon(
            Icons.upload_file,
            color: Theme.of(panelContext).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              panelContext.l10n.workflowImport_title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(panelContext).textTheme.titleLarge,
            ),
          ),
        ],
      ),
      builder: (panelContext, scrollController) =>
          WorkflowImportWizard(scrollController: scrollController),
    );
  }

  @override
  ConsumerState<WorkflowImportWizard> createState() =>
      _WorkflowImportWizardState();
}

class _WorkflowImportWizardState extends ConsumerState<WorkflowImportWizard> {
  int _step = 0;
  Map<String, dynamic>? _workflowJson;
  WorkflowAnalysisResult? _analysis;
  String? _fileName;

  // Step 1: 元信息
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  WorkflowCategory _category = WorkflowCategory.custom;

  // Step 2: 槽位选择
  final Set<String> _enabledSlotIds = {};

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final titles = [
      context.l10n.workflowImport_stepFile,
      context.l10n.workflowImport_stepInfo,
      context.l10n.workflowImport_stepSlots,
      context.l10n.workflowImport_stepDone,
    ];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              context.l10n.workflowImport_step(_step + 1, titles[_step]),
              key: const Key('workflow-import-step-label'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            key: const Key('workflow-import-form-scroll'),
            controller: widget.scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(20),
            children: [_buildStepContent(theme)],
          ),
        ),
        _buildFooter(),
      ],
    );
  }

  Widget _buildStepContent(ThemeData theme) {
    switch (_step) {
      case 0:
        return _buildFilePickStep(theme);
      case 1:
        return _buildMetaStep(theme);
      case 2:
        return _buildSlotsStep(theme);
      case 3:
        return _buildConfirmStep(theme);
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildFooter() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final actions = <Widget>[
          if (_step > 0)
            TextButton(
              onPressed: () => setState(() => _step--),
              child: Text(context.l10n.workflowImport_previous),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(context.l10n.common_cancel),
          ),
          if (_step < 3)
            FilledButton(
              onPressed: _canProceed ? _nextStep : null,
              child: Text(context.l10n.workflowImport_next),
            )
          else
            FilledButton.icon(
              onPressed: _saveWorkflow,
              icon: const Icon(Icons.check, size: 18),
              label: Text(context.l10n.workflowImport_finish),
            ),
        ];
        final largeText = MediaQuery.textScalerOf(context).scale(1) >= 2;
        return SingleChildScrollView(
          key: const Key('workflow-import-actions-scroll'),
          scrollDirection: largeText ? Axis.horizontal : Axis.vertical,
          padding: const EdgeInsets.all(12),
          child: SafeArea(
            top: false,
            child: largeText
                ? Row(
                    key: const Key('workflow-import-actions'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var index = 0; index < actions.length; index++) ...[
                        if (index > 0) const SizedBox(width: 8),
                        actions[index],
                      ],
                    ],
                  )
                : Wrap(
                    key: const Key('workflow-import-actions'),
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

  bool get _canProceed {
    switch (_step) {
      case 0:
        return _workflowJson != null;
      case 1:
        return _nameController.text.trim().isNotEmpty;
      case 2:
        return _enabledSlotIds.any(
          (id) => _analysis!.outputSlots.any((s) => s.id == id),
        );
      default:
        return true;
    }
  }

  void _nextStep() {
    if (_step == 0 && _workflowJson != null && _analysis == null) {
      _runAnalysis();
    }
    setState(() => _step++);
  }

  void _runAnalysis() {
    _analysis = WorkflowAnalyzer.analyze(_workflowJson!);
    for (final slot in _analysis!.allSlots) {
      _enabledSlotIds.add(slot.id);
    }
    if (_nameController.text.isEmpty) {
      _nameController.text =
          _fileName?.replaceAll('.json', '') ??
          context.l10n.workflowImport_defaultName;
    }
  }

  // ==================== Step 0: 文件选择 ====================

  Widget _buildFilePickStep(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.workflowImport_fileInstructions,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 20),
        InkWell(
          onTap: _pickWorkflowFile,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(minHeight: 140),
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(
                color: _workflowJson != null
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline.withValues(alpha: 0.5),
                width: _workflowJson != null ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
              color: _workflowJson != null
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.1)
                  : null,
            ),
            child: Center(
              child: _workflowJson != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: theme.colorScheme.primary,
                          size: 36,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _fileName ?? 'workflow.json',
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          context.l10n.workflowImport_nodeCount(
                            _workflowJson!.length,
                          ),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          context.l10n.workflowImport_reselect,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.upload_file,
                          size: 40,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          context.l10n.workflowImport_selectWorkflowApi,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickWorkflowFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        allowMultiple: false,
      );
      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      String content;
      if (file.bytes != null) {
        content = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        content = await File(file.path!).readAsString();
      } else {
        return;
      }

      final parsed = json.decode(content);
      if (parsed is! Map<String, dynamic>) {
        if (mounted) {
          AppToast.error(context, context.l10n.workflowImport_invalidTopLevel);
        }
        return;
      }

      // 基本验证：至少有一个含 class_type 的节点
      final hasNodes = parsed.values.any(
        (v) => v is Map<String, dynamic> && v.containsKey('class_type'),
      );
      if (!hasNodes) {
        if (mounted) {
          AppToast.error(context, context.l10n.workflowImport_noComfyNodes);
        }
        return;
      }

      setState(() {
        _workflowJson = parsed;
        _fileName = file.name;
        _analysis = null;
      });
    } catch (e) {
      if (mounted) {
        AppToast.error(context, context.l10n.workflowImport_readFailed(e));
      }
    }
  }

  // ==================== Step 1: 元信息编辑 ====================

  Widget _buildMetaStep(ThemeData theme) {
    final a = _analysis!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 分析摘要
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.workflowImport_analysisResult,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              _infoRow(
                theme,
                Icons.input,
                context.l10n.workflowImport_inputImageNodes,
                context.l10n.workflowImport_countUnit(a.inputSlots.length),
              ),
              _infoRow(
                theme,
                Icons.tune,
                context.l10n.workflowImport_adjustableParams,
                context.l10n.workflowImport_countUnit(a.parameterSlots.length),
              ),
              _infoRow(
                theme,
                Icons.output,
                context.l10n.workflowImport_outputNodes,
                context.l10n.workflowImport_countUnit(a.outputSlots.length),
              ),
              _infoRow(
                theme,
                Icons.widgets_outlined,
                context.l10n.workflowImport_totalNodes,
                context.l10n.workflowImport_countUnit(a.nodes.length),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // 名称
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: context.l10n.workflowImport_workflowName,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),

        // 描述
        TextField(
          controller: _descController,
          decoration: InputDecoration(
            labelText: context.l10n.workflowImport_description,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          maxLines: 2,
        ),
        const SizedBox(height: 12),

        // 分类
        Text(
          context.l10n.workflowImport_category,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: WorkflowCategory.values.map((cat) {
            return ChoiceChip(
              label: Text(cat.localizedLabel(context)),
              selected: _category == cat,
              onSelected: (selected) {
                if (selected) setState(() => _category = cat);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _infoRow(ThemeData theme, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(label, style: theme.textTheme.bodySmall),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== Step 2: 槽位确认 ====================

  Widget _buildSlotsStep(ThemeData theme) {
    final a = _analysis!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.workflowImport_slotsHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 16),
        if (a.inputSlots.isNotEmpty) ...[
          _sectionHeader(
            theme,
            context.l10n.workflowImport_inputSection,
            Icons.input,
          ),
          ...a.inputSlots.map((s) => _slotTile(theme, s)),
          const SizedBox(height: 12),
        ],
        if (a.outputSlots.isNotEmpty) ...[
          _sectionHeader(
            theme,
            context.l10n.workflowImport_outputSection,
            Icons.output,
          ),
          ...a.outputSlots.map((s) => _slotTile(theme, s)),
          const SizedBox(height: 12),
        ],
        if (a.parameterSlots.isNotEmpty) ...[
          _sectionHeader(
            theme,
            context.l10n.workflowImport_parameterSection,
            Icons.tune,
          ),
          ...a.parameterSlots.map((s) => _slotTile(theme, s)),
        ],
        if (a.allSlots.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(context.l10n.workflowImport_noSlotsWarning),
          ),
      ],
    );
  }

  Widget _sectionHeader(ThemeData theme, String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _slotTile(ThemeData theme, WorkflowSlot slot) {
    final enabled = _enabledSlotIds.contains(slot.id);
    return CheckboxListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title: Text(slot.label, style: theme.textTheme.bodyMedium),
      subtitle: Text(
        '${slot.direction.name} · ${slot.dataType.name} · '
        '${context.l10n.workflowImport_nodeRef(slot.nodeId)}'
        '${slot.field != null ? ".${slot.field}" : ""}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
      value: enabled,
      onChanged: (value) {
        setState(() {
          if (value == true) {
            _enabledSlotIds.add(slot.id);
          } else {
            _enabledSlotIds.remove(slot.id);
          }
        });
      },
    );
  }

  // ==================== Step 3: 确认 ====================

  Widget _buildConfirmStep(ThemeData theme) {
    final enabledSlots = _analysis!.allSlots
        .where((s) => _enabledSlotIds.contains(s.id))
        .toList();
    final inputs = enabledSlots
        .where((s) => s.direction == SlotDirection.input)
        .length;
    final outputs = enabledSlots
        .where((s) => s.direction == SlotDirection.output)
        .length;
    final params = enabledSlots
        .where((s) => s.direction == SlotDirection.parameter)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 48,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          context.l10n.workflowImport_confirmTitle,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        _confirmRow(
          theme,
          context.l10n.workflowImport_name,
          _nameController.text.trim(),
        ),
        if (_descController.text.trim().isNotEmpty)
          _confirmRow(
            theme,
            context.l10n.workflowImport_description,
            _descController.text.trim(),
          ),
        _confirmRow(
          theme,
          context.l10n.workflowImport_category,
          _category.localizedLabel(context),
        ),
        _confirmRow(
          theme,
          context.l10n.workflowImport_inputSlots,
          context.l10n.workflowImport_countUnit(inputs),
        ),
        _confirmRow(
          theme,
          context.l10n.workflowImport_parameterSlots,
          context.l10n.workflowImport_countUnit(params),
        ),
        _confirmRow(
          theme,
          context.l10n.workflowImport_outputSlots,
          context.l10n.workflowImport_countUnit(outputs),
        ),
        _confirmRow(
          theme,
          context.l10n.workflowImport_totalNodes,
          '${_workflowJson!.length}',
        ),
        const SizedBox(height: 16),
        Text(
          context.l10n.workflowImport_afterImportHint,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _confirmRow(ThemeData theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Flexible(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 保存 ====================

  Future<void> _saveWorkflow() async {
    if (_workflowJson == null || _analysis == null) return;

    final enabledSlots = _analysis!.allSlots
        .where((s) => _enabledSlotIds.contains(s.id))
        .toList();

    final name = _nameController.text.trim();
    final id =
        'custom_${name.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_').toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}';

    final template = WorkflowTemplate(
      id: id,
      name: name,
      description: _descController.text.trim(),
      version: '1.0.0',
      author: 'User',
      category: _category,
      requiresInputImage: enabledSlots.any(
        (s) => s.direction == SlotDirection.input,
      ),
      requiresMask: enabledSlots.any((s) => s.dataType == SlotDataType.mask),
      slots: enabledSlots,
      workflowJson: _workflowJson!,
      isBuiltin: false,
    );

    await ref
        .read(comfyUIWorkflowsProvider.notifier)
        .addCustomTemplate(template);

    if (mounted) {
      AppToast.success(context, context.l10n.workflowImport_success(name));
      Navigator.of(context).pop();
    }
  }
}
