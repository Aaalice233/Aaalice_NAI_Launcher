import 'package:flutter/material.dart';

import '../../../core/agent/skill_catalog.dart';
import '../../../core/cloud_sync/content_selection.dart';
import '../../../core/utils/localization_extension.dart';

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
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final entries =
        widget.skills.entries.where((entry) {
          if (query.isEmpty) return true;
          return entry.id.toLowerCase().contains(query) ||
              entry.skill.description.toLowerCase().contains(query) ||
              _sourceLabel(context, entry.source).toLowerCase().contains(query);
        }).toList()..sort((a, b) {
          final byName = a.id.compareTo(b.id);
          return byName != 0
              ? byName
              : a.source.index.compareTo(b.source.index);
        });
    final availableIds = {
      for (final entry in widget.skills.entries) entry.backupId,
    };
    final missingIds = widget.selection.selectedSkillIds.difference(
      availableIds,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.cloudSync_agentContentTitle,
          style: Theme.of(context).textTheme.titleSmall,
        ),
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
          const SizedBox(height: 8),
          Text(
            context.l10n.cloudSync_skillsSelectedCount(
              widget.selection.selectedSkillIds.length,
            ),
            key: const ValueKey('cloud-sync-selected-skill-count'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          if (missingIds.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.cloudSync_missingSelectedSkills(
                      missingIds.length,
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                TextButton(
                  onPressed: () => widget.onChanged(
                    widget.selection.copyWith(
                      selectedSkillIds: widget.selection.selectedSkillIds
                          .difference(missingIds),
                    ),
                  ),
                  child: Text(context.l10n.cloudSync_removeMissingSkills),
                ),
              ],
            ),
          const SizedBox(height: 8),
          TextField(
            key: const ValueKey('cloud-sync-skill-search'),
            controller: _search,
            decoration: InputDecoration(
              hintText: context.l10n.cloudSync_searchSkills,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).deleteButtonTooltip,
                      onPressed: () {
                        _search.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.close),
                    ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(context.l10n.cloudSync_noSkills),
            )
          else
            SizedBox(
              height: (entries.length * 64).clamp(64, 320).toDouble(),
              child: ListView.separated(
                key: const ValueKey('cloud-sync-skill-list'),
                itemCount: entries.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final selected = widget.selection.selectedSkillIds.contains(
                    entry.backupId,
                  );
                  return CheckboxListTile(
                    key: ValueKey('cloud-sync-skill-${entry.backupId}'),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: selected,
                    title: Text(entry.id),
                    subtitle: Text(
                      '${_sourceLabel(context, entry.source)} · '
                      '${entry.skill.description}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onChanged: (value) {
                      if (value == true &&
                          widget.selection.selectedSkillIds.length >=
                              CloudSyncContentSelection.maxSelectedSkills) {
                        return;
                      }
                      final ids = {...widget.selection.selectedSkillIds};
                      value == true
                          ? ids.add(entry.backupId)
                          : ids.remove(entry.backupId);
                      widget.onChanged(
                        widget.selection.copyWith(selectedSkillIds: ids),
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ],
    );
  }
}

String _sourceLabel(BuildContext context, SkillSource source) =>
    switch (source) {
      SkillSource.workspace => context.l10n.agentSettings_sourceWorkspace,
      SkillSource.piUser => context.l10n.agentSettings_sourcePiUser,
      SkillSource.commonUser => context.l10n.agentSettings_sourceCommonUser,
    };
