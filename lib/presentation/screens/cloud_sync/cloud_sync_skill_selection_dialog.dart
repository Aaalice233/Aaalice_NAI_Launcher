import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/agent/skill_catalog.dart';
import '../../../core/cloud_sync/content_selection.dart';
import '../../../core/utils/localization_extension.dart';
import '../../adaptive/adaptive_presenter.dart';

Future<Set<String>?> showCloudSyncSkillSelectionDialog({
  required BuildContext context,
  required Set<String> initialSelectedIds,
  required SkillCatalogSnapshot skills,
}) => AdaptivePresenter.showPanel<Set<String>>(
  context: context,
  title: context.l10n.cloudSync_chooseSkills,
  dialogWidth: 720,
  initialChildSize: 0.88,
  minChildSize: 0.56,
  maxChildSize: 0.96,
  builder: (context, scrollController) => _CloudSyncSkillSelectionBody(
    initialSelectedIds: initialSelectedIds,
    skills: skills,
    scrollController: scrollController,
  ),
);

class _CloudSyncSkillSelectionBody extends StatefulWidget {
  const _CloudSyncSkillSelectionBody({
    required this.initialSelectedIds,
    required this.skills,
    required this.scrollController,
  });

  final Set<String> initialSelectedIds;
  final SkillCatalogSnapshot skills;
  final ScrollController scrollController;

  @override
  State<_CloudSyncSkillSelectionBody> createState() =>
      _CloudSyncSkillSelectionBodyState();
}

class _CloudSyncSkillSelectionBodyState
    extends State<_CloudSyncSkillSelectionBody> {
  final _search = TextEditingController();
  late final Set<String> _selectedIds = {...widget.initialSelectedIds};

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
    final missingIds = _selectedIds.difference(availableIds);
    final height = math.min(680.0, MediaQuery.sizeOf(context).height * 0.72);

    return SizedBox(
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  context.l10n.cloudSync_skillsSelectedCount(
                    _selectedIds.length,
                  ),
                  key: const ValueKey('cloud-sync-selected-skill-count'),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                if (missingIds.isNotEmpty) _missingSkills(context, missingIds),
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
              ],
            ),
          ),
          Expanded(
            child: entries.isEmpty
                ? Center(child: Text(context.l10n.cloudSync_noSkills))
                : ListView.separated(
                    key: const ValueKey('cloud-sync-skill-list'),
                    controller: widget.scrollController,
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final selected = _selectedIds.contains(entry.backupId);
                      return CheckboxListTile(
                        key: ValueKey('cloud-sync-skill-${entry.backupId}'),
                        contentPadding: EdgeInsets.zero,
                        minTileHeight: 56,
                        dense: true,
                        value: selected,
                        title: Text(entry.id),
                        subtitle: Text(
                          '${_sourceLabel(context, entry.source)} · '
                          '${entry.skill.description}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onChanged: (value) => _toggle(entry.backupId, value),
                      );
                    },
                  ),
          ),
          _footer(context),
        ],
      ),
    );
  }

  Widget _missingSkills(BuildContext context, Set<String> missingIds) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final message = Text(
            context.l10n.cloudSync_missingSelectedSkills(missingIds.length),
            style: Theme.of(context).textTheme.bodySmall,
          );
          final action = TextButton(
            onPressed: () => setState(() => _selectedIds.removeAll(missingIds)),
            child: Text(context.l10n.cloudSync_removeMissingSkills),
          );
          if (constraints.maxWidth < 420 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.6) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                message,
                Align(alignment: Alignment.centerRight, child: action),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: message),
              action,
            ],
          );
        },
      );

  Widget _footer(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
    child: Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 4,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cloudSync_cancel),
        ),
        FilledButton(
          key: const ValueKey('cloud-sync-skill-save'),
          onPressed: () => Navigator.of(context).pop({..._selectedIds}),
          child: Text(context.l10n.cloudSync_saveSelection),
        ),
      ],
    ),
  );

  void _toggle(String id, bool? value) {
    if (value == true &&
        _selectedIds.length >= CloudSyncContentSelection.maxSelectedSkills) {
      return;
    }
    setState(
      () => value == true ? _selectedIds.add(id) : _selectedIds.remove(id),
    );
  }
}

String _sourceLabel(BuildContext context, SkillSource source) =>
    switch (source) {
      SkillSource.workspace => context.l10n.agentSettings_sourceWorkspace,
      SkillSource.piUser => context.l10n.agentSettings_sourcePiUser,
      SkillSource.commonUser => context.l10n.agentSettings_sourceCommonUser,
    };
