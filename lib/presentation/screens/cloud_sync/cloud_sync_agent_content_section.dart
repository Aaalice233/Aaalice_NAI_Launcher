import 'package:flutter/material.dart';

import '../../../core/agent/skill_catalog.dart';
import '../../../core/cloud_sync/content_selection.dart';
import '../../../core/utils/localization_extension.dart';
import 'cloud_sync_skill_selection_dialog.dart';

class CloudSyncAgentContentSection extends StatefulWidget {
  const CloudSyncAgentContentSection({
    required this.selection,
    required this.skills,
    required this.onChanged,
    super.key,
  });

  final CloudSyncContentSelection selection;
  final SkillCatalogSnapshot skills;
  final ValueChanged<CloudSyncContentSelection> onChanged;

  @override
  State<CloudSyncAgentContentSection> createState() =>
      _CloudSyncAgentContentSectionState();
}

class _CloudSyncAgentContentSectionState
    extends State<CloudSyncAgentContentSection> {
  @override
  Widget build(BuildContext context) {
    final availableIds = {
      for (final entry in widget.skills.entries) entry.backupId,
    };
    final missingIds = widget.selection.selectedSkillIds.difference(
      availableIds,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          key: const ValueKey('cloud-sync-agent-system-prompt'),
          contentPadding: EdgeInsets.zero,
          minTileHeight: 56,
          value: widget.selection.includeAgentSystemPrompt,
          title: Text(context.l10n.cloudSync_agentSystemPrompt),
          subtitle: Text(context.l10n.cloudSync_agentSystemPromptDescription),
          onChanged: (value) => widget.onChanged(
            widget.selection.copyWith(includeAgentSystemPrompt: value == true),
          ),
        ),
        const SizedBox(height: 4),
        SwitchListTile(
          key: const ValueKey('cloud-sync-agent-skills'),
          contentPadding: EdgeInsets.zero,
          minTileHeight: 56,
          value: widget.selection.includeSkills,
          title: Text(context.l10n.cloudSync_skillsBackup),
          subtitle: Text(context.l10n.cloudSync_skillsBackupDescription),
          onChanged: (value) =>
              widget.onChanged(widget.selection.copyWith(includeSkills: value)),
        ),
        if (widget.selection.includeSkills) ...[
          const SizedBox(height: 4),
          ListTile(
            key: const ValueKey('cloud-sync-skill-selection-entry'),
            contentPadding: EdgeInsets.zero,
            minTileHeight: 56,
            title: Text(context.l10n.cloudSync_chooseSkills),
            subtitle: Text(
              missingIds.isEmpty
                  ? context.l10n.cloudSync_skillsSelectedCount(
                      widget.selection.selectedSkillIds.length,
                    )
                  : '${context.l10n.cloudSync_skillsSelectedCount(widget.selection.selectedSkillIds.length)} · '
                        '${context.l10n.cloudSync_missingSelectedSkills(missingIds.length)}',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _editSkills,
          ),
        ],
      ],
    );
  }

  Future<void> _editSkills() async {
    final selectedIds = await showCloudSyncSkillSelectionDialog(
      context: context,
      initialSelectedIds: widget.selection.selectedSkillIds,
      skills: widget.skills,
    );
    if (selectedIds == null || !mounted) return;
    widget.onChanged(widget.selection.copyWith(selectedSkillIds: selectedIds));
  }
}
