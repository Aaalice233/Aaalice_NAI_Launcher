import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/data/models/agent/agent_settings.dart';
import 'package:nai_launcher/presentation/agent_settings/providers/agent_prompt_draft_provider.dart';
import 'package:nai_launcher/presentation/agent_settings/providers/agent_settings_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/app_toast.dart';
import '../../widgets/settings_card.dart';

class AgentSystemPromptEditor extends ConsumerStatefulWidget {
  const AgentSystemPromptEditor({super.key, this.panelSelector});

  final Widget? panelSelector;

  @override
  ConsumerState<AgentSystemPromptEditor> createState() =>
      _AgentSystemPromptEditorState();
}

class _AgentSystemPromptEditorState
    extends ConsumerState<AgentSystemPromptEditor> {
  late final TextEditingController _controller;
  bool _showPreview = false;
  String _preview = '';
  String _defaultPrompt = '';
  int _previewRevision = 0;
  bool _syncScheduled = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  void _onChanged() {
    _previewRevision++;
    final current = ref.read(agentPromptDraftProvider).draft;
    if (_controller.text != current) {
      ref.read(agentPromptDraftProvider.notifier).updateDraft(_controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(agentSettingsProvider);
    final settings = settingsState.settings;
    final draft = ref.watch(agentPromptDraftProvider);
    _defaultPrompt = ref
        .read(agentSettingsProvider.notifier)
        .buildDefaultSystemPrompt();
    final usesDefaultPrompt = settings.chat.customSystemPrompt.trim().isEmpty;
    final saved = usesDefaultPrompt && _defaultPrompt.isNotEmpty
        ? _defaultPrompt
        : settings.chat.customSystemPrompt;
    final savedMode = usesDefaultPrompt && _defaultPrompt.isNotEmpty
        ? AgentSystemPromptMode.override
        : settings.chat.systemPromptMode;
    if (draft.saved != saved ||
        draft.savedMode != savedMode ||
        _controller.text != draft.draft) {
      _scheduleSynchronization(saved, savedMode);
    }
    final defaultDraft =
        draft.draftMode == AgentSystemPromptMode.override &&
        draft.draft == _defaultPrompt;
    return SettingsCard(
      navigation: widget.panelSelector,
      title: context.l10n.agentSettings_systemPrompt,
      description: context.l10n.agentSettings_systemPromptDescription,
      icon: Icons.subject_outlined,
      trailing: TextButton.icon(
        onPressed: () => _togglePreview(draft.revision),
        icon: Icon(_showPreview ? Icons.edit_outlined : Icons.preview_outlined),
        label: Text(
          _showPreview
              ? context.l10n.agentSettings_edit
              : context.l10n.agentSettings_previewFinalPrompt,
        ),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: _showPreview
            ? SelectableText(
                _preview,
                key: const ValueKey('agent-system-prompt-preview'),
              )
            : Column(
                key: const ValueKey('agent-system-prompt-editor'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SegmentedButton<AgentSystemPromptMode>(
                      key: const ValueKey('agent-system-prompt-mode'),
                      segments: [
                        ButtonSegment(
                          value: AgentSystemPromptMode.append,
                          icon: const Icon(Icons.playlist_add_outlined),
                          label: Text(
                            context.l10n.agentSettings_promptModeAppend,
                          ),
                        ),
                        ButtonSegment(
                          value: AgentSystemPromptMode.override,
                          icon: const Icon(Icons.find_replace_outlined),
                          label: Text(
                            context.l10n.agentSettings_promptModeOverride,
                          ),
                        ),
                      ],
                      selected: {draft.draftMode},
                      onSelectionChanged: draft.saving
                          ? null
                          : (selection) => _updateMode(selection.single, draft),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    draft.draftMode == AgentSystemPromptMode.append
                        ? context.l10n.agentSettings_promptModeAppendDescription
                        : context
                              .l10n
                              .agentSettings_promptModeOverrideDescription,
                    key: const ValueKey('agent-system-prompt-mode-description'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('agent-custom-system-prompt'),
                    controller: _controller,
                    minLines: 6,
                    maxLines: 14,
                    maxLength: 50000,
                    decoration: InputDecoration(
                      hintText: context.l10n.agentSettings_systemPromptHint,
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: draft.saving || defaultDraft
                            ? null
                            : _restoreDefault,
                        child: Text(context.l10n.agentSettings_restoreDefault),
                      ),
                      FilledButton.icon(
                        key: const ValueKey('agent-system-prompt-save'),
                        onPressed: draft.dirty && !draft.saving
                            ? () => _save(draft)
                            : null,
                        icon: draft.saving
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(context.l10n.common_save),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  void _updateMode(AgentSystemPromptMode mode, AgentPromptDraftState draft) {
    if (mode == draft.draftMode) return;
    final notifier = ref.read(agentPromptDraftProvider.notifier);
    if (mode == AgentSystemPromptMode.append && draft.draft == _defaultPrompt) {
      _setControllerText('');
      notifier.updateMode(mode);
      return;
    }
    if (mode == AgentSystemPromptMode.override && draft.draft.trim().isEmpty) {
      _setControllerText(_defaultPrompt);
    }
    notifier.updateMode(mode);
  }

  void _restoreDefault() {
    _setControllerText(_defaultPrompt);
    ref
        .read(agentPromptDraftProvider.notifier)
        .updateMode(AgentSystemPromptMode.override);
  }

  void _setControllerText(String text) {
    if (_controller.text == text) return;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _scheduleSynchronization(String saved, AgentSystemPromptMode savedMode) {
    if (_syncScheduled) return;
    _syncScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncScheduled = false;
      if (!mounted) return;
      ref
          .read(agentPromptDraftProvider.notifier)
          .synchronizeSaved(value: saved, mode: savedMode);
      final text = ref.read(agentPromptDraftProvider).draft;
      if (_controller.text == text) return;
      _controller.removeListener(_onChanged);
      _controller.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      _controller.addListener(_onChanged);
    });
  }

  Future<void> _save(AgentPromptDraftState draft) async {
    final notifier = ref.read(agentPromptDraftProvider.notifier);
    notifier.beginSave();
    final restoresDefault =
        draft.draftMode == AgentSystemPromptMode.override &&
        draft.draft == _defaultPrompt;
    final persistedMode = restoresDefault
        ? AgentSystemPromptMode.append
        : draft.draftMode;
    final persistedValue = restoresDefault ? '' : draft.draft;
    try {
      await ref
          .read(agentSettingsProvider.notifier)
          .saveCustomSystemPrompt(mode: persistedMode, value: persistedValue);
      notifier.finishSave(
        revision: draft.revision,
        saved: restoresDefault ? _defaultPrompt : draft.draft,
        savedMode: restoresDefault
            ? AgentSystemPromptMode.override
            : draft.draftMode,
      );
      if (mounted) {
        AppToast.success(context, context.l10n.agentSettings_promptSaved);
      }
    } catch (error) {
      notifier.failSave();
      if (mounted) {
        AppToast.error(
          context,
          context.l10n.agentSettings_operationFailed(error.toString()),
        );
      }
    }
  }

  Future<void> _togglePreview(int revision) async {
    if (_showPreview) {
      setState(() => _showPreview = false);
      return;
    }
    final currentRevision = ++_previewRevision;
    final preview = ref
        .read(agentSettingsProvider.notifier)
        .buildSystemPromptPreview(
          customInstructions: ref.read(agentPromptDraftProvider).draft,
          mode: ref.read(agentPromptDraftProvider).draftMode,
        );
    if (!mounted ||
        currentRevision != _previewRevision ||
        revision != ref.read(agentPromptDraftProvider).revision) {
      return;
    }
    setState(() {
      _preview = preview;
      _showPreview = true;
    });
  }
}
