import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../data/models/prompt_assistant/assistant_execution_settings.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../adaptive/content_sized_adaptive_form.dart';
import '../../../../data/models/prompt_assistant/prompt_assistant_models.dart';
import '../../../widgets/common/themed_confirm_dialog.dart';
import '../../../widgets/common/provider_icon.dart';
import 'assistant_task_labels.dart';
import 'settings_form_footer.dart';

class PromptAssistantProviderFormResult {
  const PromptAssistantProviderFormResult({
    required this.name,
    required this.baseUrl,
    required this.apiKey,
    required this.preset,
    required this.allowImageInput,
    required this.concurrency,
  });

  final String name;
  final String baseUrl;
  final String apiKey;
  final ProviderPreset preset;
  final bool allowImageInput;
  final AssistantConcurrencySettings concurrency;
}

class PromptAssistantProviderForm extends StatefulWidget {
  const PromptAssistantProviderForm({
    super.key,
    required this.scrollController,
    this.provider,
  });

  final ScrollController scrollController;
  final ProviderConfig? provider;

  @override
  State<PromptAssistantProviderForm> createState() =>
      _PromptAssistantProviderFormState();
}

class _PromptAssistantProviderFormState
    extends State<PromptAssistantProviderForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _baseController;
  final TextEditingController _keyController = TextEditingController();
  late ProviderPreset _preset;
  late bool _allowImageInput;
  late AssistantConcurrencyMode _concurrencyMode;
  late final TextEditingController _concurrencyController;
  bool _invalidConcurrency = false;

  @override
  void initState() {
    super.initState();
    final provider = widget.provider;
    final concurrency =
        provider?.concurrency ?? const AssistantConcurrencySettings();
    _concurrencyMode = concurrency.mode;
    _concurrencyController = TextEditingController(
      text: concurrency.maxConcurrentRequests.toString(),
    );
    _nameController = TextEditingController(text: provider?.name ?? '');
    _baseController = TextEditingController(text: provider?.baseUrl ?? '');
    _preset =
        provider?.preset ??
        (provider == null
            ? ProviderPreset.openaiChat
            : provider.protocol == ProviderProtocol.openaiResponses
            ? ProviderPreset.openaiCompatibleResponses
            : ProviderPreset.openaiCompatibleChat);
    _allowImageInput =
        provider?.allowImageInput ?? _preset.defaultAllowImageInput;
    if (provider == null) {
      _nameController.text = _preset.defaultName;
      _baseController.text = _preset.defaultBaseUrl;
    }
  }

  @override
  void dispose() {
    _concurrencyController.dispose();
    _nameController.dispose();
    _baseController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  void _applyPreset(ProviderPreset value) {
    final previousPreset = _preset;
    final currentName = _nameController.text.trim();
    final currentBaseUrl = _baseController.text.trim();
    _preset = value;
    _allowImageInput = value.defaultAllowImageInput;
    if (widget.provider == null) {
      _nameController.text = value.defaultName;
      _baseController.text = value.defaultBaseUrl;
      return;
    }
    if (currentName.isEmpty || currentName == previousPreset.defaultName) {
      _nameController.text = value.defaultName;
    }
    if (currentBaseUrl.isEmpty ||
        currentBaseUrl == previousPreset.defaultBaseUrl) {
      _baseController.text = value.defaultBaseUrl;
    }
  }

  void _save() {
    final count = int.tryParse(_concurrencyController.text);
    if (_concurrencyMode == AssistantConcurrencyMode.manual &&
        (count == null || count < 1)) {
      setState(() => _invalidConcurrency = true);
      return;
    }
    Navigator.pop(
      context,
      PromptAssistantProviderFormResult(
        name: _nameController.text.trim(),
        baseUrl: _baseController.text.trim(),
        apiKey: _keyController.text,
        preset: _preset,
        allowImageInput: _allowImageInput,
        concurrency: AssistantConcurrencySettings(
          mode: _concurrencyMode,
          maxConcurrentRequests: count != null && count > 0 ? count : 5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ContentSizedAdaptiveForm(
      key: const ValueKey('prompt-assistant-provider-dialog'),
      scrollController: widget.scrollController,
      content: [
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: context.l10n.promptAssistant_name,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ProviderPreset>(
          initialValue: _preset,
          isExpanded: true,
          items: ProviderPreset.values
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: ProviderNameLabel(preset: value),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _applyPreset(value));
            }
          },
          decoration: InputDecoration(
            labelText: context.l10n.promptAssistant_protocol,
          ),
        ),
        // 已有服务商的地址和密钥在模型服务页内直接编辑，这里不再重复。
        if (widget.provider == null) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _baseController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(labelText: 'Base URL'),
          ),
        ],
        const SizedBox(height: 8),
        SwitchListTile(
          value: _allowImageInput,
          contentPadding: EdgeInsets.zero,
          title: Text(context.l10n.promptAssistant_allowImageInput),
          subtitle: Text(context.l10n.promptAssistant_allowImageInputSubtitle),
          onChanged: (value) {
            setState(() => _allowImageInput = value);
          },
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<AssistantConcurrencyMode>(
          key: const ValueKey('assistant-concurrency-mode'),
          initialValue: _concurrencyMode,
          isExpanded: true,
          itemHeight: null,
          decoration: InputDecoration(
            labelText: context.l10n.promptAssistant_concurrencyMode,
          ),
          items: [
            DropdownMenuItem(
              value: AssistantConcurrencyMode.automatic,
              child: Text(context.l10n.promptAssistant_concurrencyAuto),
            ),
            DropdownMenuItem(
              value: AssistantConcurrencyMode.manual,
              child: Text(context.l10n.promptAssistant_concurrencyManual),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _concurrencyMode = value;
                _invalidConcurrency = false;
              });
            }
          },
        ),
        const SizedBox(height: 8),
        if (_concurrencyMode == AssistantConcurrencyMode.manual)
          TextField(
            key: const ValueKey('assistant-concurrency-count'),
            controller: _concurrencyController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: context.l10n.promptAssistant_concurrencyCount,
              errorText: _invalidConcurrency
                  ? context.l10n.promptAssistant_concurrencyInvalid
                  : null,
              errorMaxLines: 3,
            ),
          )
        else
          Text(
            context.l10n.promptAssistant_concurrencyAutoDescription,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (widget.provider == null) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _keyController,
            decoration: InputDecoration(
              labelText: context.l10n.promptAssistant_apiKeyLeaveEmpty,
            ),
            obscureText: true,
          ),
        ],
      ],
      footer: SettingsFormFooter(onSave: _save),
    );
  }
}

class PromptAssistantRuleFormResult {
  const PromptAssistantRuleFormResult._({
    required this.deleted,
    this.name = '',
    this.content = '',
    this.taskType = AssistantTaskType.llm,
  });

  const PromptAssistantRuleFormResult.saved({
    required String name,
    required String content,
    required AssistantTaskType taskType,
  }) : this._(deleted: false, name: name, content: content, taskType: taskType);

  const PromptAssistantRuleFormResult.deleted() : this._(deleted: true);

  final bool deleted;
  final String name;
  final String content;
  final AssistantTaskType taskType;
}

class PromptAssistantRuleForm extends StatefulWidget {
  const PromptAssistantRuleForm({
    super.key,
    required this.scrollController,
    this.rule,
  });

  final ScrollController scrollController;
  final PromptRuleTemplate? rule;

  @override
  State<PromptAssistantRuleForm> createState() =>
      _PromptAssistantRuleFormState();
}

class _PromptAssistantRuleFormState extends State<PromptAssistantRuleForm> {
  late final TextEditingController _nameController;
  late final TextEditingController _contentController;
  late AssistantTaskType _taskType;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.rule?.name ?? '');
    _contentController = TextEditingController(
      text: widget.rule?.content ?? '',
    );
    _taskType = widget.rule?.taskType ?? AssistantTaskType.llm;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final rule = widget.rule;
    if (rule == null) return;
    final confirmed = await ThemedConfirmDialog.showDelete(
      context: context,
      itemName: localizedRuleName(context.l10n, rule),
    );
    if (confirmed && mounted) {
      Navigator.pop(context, const PromptAssistantRuleFormResult.deleted());
    }
  }

  void _save() {
    Navigator.pop(
      context,
      PromptAssistantRuleFormResult.saved(
        name: _nameController.text.trim(),
        content: _contentController.text.trim(),
        taskType: _taskType,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rule = widget.rule;
    return ContentSizedAdaptiveForm(
      key: const ValueKey('prompt-assistant-rule-dialog'),
      scrollController: widget.scrollController,
      content: [
        TextField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: context.l10n.promptAssistant_name,
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<AssistantTaskType>(
          initialValue: _taskType,
          isExpanded: true,
          items: AssistantTaskType.values
              .where((value) => value != AssistantTaskType.chat)
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(
                    value.localizedLabel(context.l10n),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _taskType = value);
          },
          decoration: InputDecoration(
            labelText: context.l10n.promptAssistant_taskType,
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _contentController,
          minLines: 4,
          maxLines: 10,
          decoration: InputDecoration(
            labelText: context.l10n.promptAssistant_ruleContent,
            alignLabelWithHint: true,
          ),
        ),
      ],
      footer: SettingsFormFooter(
        onSave: _save,
        leading: rule != null && !rule.isDefault
            ? TextButton(
                onPressed: _delete,
                child: Text(context.l10n.common_delete),
              )
            : null,
      ),
    );
  }
}
