import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/data/models/agent/agent_settings.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_notifier.dart';
import 'package:nai_launcher/presentation/agent_settings/providers/agent_prompt_draft_provider.dart';
import 'package:nai_launcher/presentation/agent_settings/providers/agent_settings_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/app_toast.dart';
import '../../widgets/settings_card.dart';

class AgentSystemPromptEditor extends ConsumerStatefulWidget {
  const AgentSystemPromptEditor({super.key});

  @override
  ConsumerState<AgentSystemPromptEditor> createState() =>
      _AgentSystemPromptEditorState();
}

class _AgentSystemPromptEditorState
    extends ConsumerState<AgentSystemPromptEditor> {
  late final TextEditingController _controller;
  bool _showPreview = false;
  String _preview = '';
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
    final settings = ref.watch(agentSettingsProvider).settings;
    final draft = ref.watch(agentPromptDraftProvider);
    if (draft.saved != settings.chat.customSystemPrompt ||
        draft.savedMode != settings.chat.systemPromptMode ||
        _controller.text != draft.draft) {
      _scheduleSynchronization(
        settings.chat.customSystemPrompt,
        settings.chat.systemPromptMode,
      );
    }
    return SettingsCard(
      title: context.l10n.agentSettings_systemPrompt,
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
                  Text(
                    context.l10n.agentSettings_systemPromptDescription,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<AgentSystemPromptMode>(
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
                        : (selection) => ref
                              .read(agentPromptDraftProvider.notifier)
                              .updateMode(selection.single),
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
                        onPressed: draft.saving || draft.draft.isEmpty
                            ? null
                            : () {
                                _controller.clear();
                                ref
                                    .read(agentPromptDraftProvider.notifier)
                                    .updateDraft('');
                              },
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
    try {
      await ref
          .read(agentSettingsProvider.notifier)
          .saveCustomSystemPrompt(mode: draft.draftMode, value: draft.draft);
      notifier.finishSave(
        revision: draft.revision,
        saved: draft.draft,
        savedMode: draft.draftMode,
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
    final preview = await ref
        .read(agentChatNotifierProvider.notifier)
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
