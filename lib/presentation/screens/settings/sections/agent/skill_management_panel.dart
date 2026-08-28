import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nai_launcher/core/agent/skill_archive_service.dart';
import 'package:nai_launcher/core/agent/skill_catalog.dart';
import 'package:nai_launcher/core/services/file_export_service.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/presentation/agent_settings/providers/agent_settings_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/app_toast.dart';
import '../../widgets/settings_card.dart';

enum _SkillFilter { all, enabled, disabled, diagnostics }

class SkillManagementPanel extends ConsumerStatefulWidget {
  const SkillManagementPanel({super.key});

  @override
  ConsumerState<SkillManagementPanel> createState() =>
      _SkillManagementPanelState();
}

class _SkillManagementPanelState extends ConsumerState<SkillManagementPanel> {
  final _searchController = TextEditingController();
  final _archiveService = const SkillArchiveService();
  _SkillFilter _filter = _SkillFilter.all;
  bool _busy = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(agentSettingsProvider);
    final query = _searchController.text.trim().toLowerCase();
    final entries = state.skills.effectiveEntries.where((entry) {
      final matchesQuery =
          query.isEmpty ||
          entry.id.toLowerCase().contains(query) ||
          entry.skill.description.toLowerCase().contains(query);
      final matchesFilter = switch (_filter) {
        _SkillFilter.all => true,
        _SkillFilter.enabled => entry.enabled,
        _SkillFilter.disabled => !entry.enabled,
        _SkillFilter.diagnostics => false,
      };
      return matchesQuery && matchesFilter;
    }).toList();
    return SettingsCard(
      title: context.l10n.agentSettings_skillsTitle,
      icon: Icons.extension_outlined,
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: context.l10n.agentSettings_reloadSkills,
            onPressed: state.refreshingSkills || _busy ? null : _reload,
            icon: state.refreshingSkills
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
          PopupMenuButton<String>(
            enabled: !_busy,
            tooltip: context.l10n.agentSettings_skillTransfer,
            onSelected: (value) => value == 'import' ? _import() : _export(),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'import',
                child: Text(context.l10n.agentSettings_importSkills),
              ),
              PopupMenuItem(
                value: 'export',
                child: Text(context.l10n.agentSettings_exportSkills),
              ),
            ],
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: context.l10n.agentSettings_searchSkills,
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<_SkillFilter>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: _SkillFilter.all,
                  label: Text(context.l10n.agentSettings_filterAll),
                ),
                ButtonSegment(
                  value: _SkillFilter.enabled,
                  label: Text(context.l10n.agentSettings_filterEnabled),
                ),
                ButtonSegment(
                  value: _SkillFilter.disabled,
                  label: Text(context.l10n.agentSettings_filterDisabled),
                ),
                ButtonSegment(
                  value: _SkillFilter.diagnostics,
                  label: Text(context.l10n.agentSettings_diagnostics),
                ),
              ],
              selected: {_filter},
              onSelectionChanged: (value) =>
                  setState(() => _filter = value.first),
            ),
          ),
          const SizedBox(height: 12),
          if (state.error.isNotEmpty)
            Text(
              state.error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (_filter == _SkillFilter.diagnostics)
            _DiagnosticsList(snapshot: state.skills)
          else if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(context.l10n.agentSettings_noMatchingSkill),
              ),
            )
          else
            for (final entry in entries) _SkillTile(entry: entry),
        ],
      ),
    );
  }

  Future<void> _reload() async {
    try {
      await ref.read(agentSettingsProvider.notifier).reloadSkills();
      if (mounted) {
        AppToast.success(context, context.l10n.agentSettings_skillsRescanned);
      }
    } catch (error) {
      if (mounted) {
        AppToast.error(
          context,
          context.l10n.agentSettings_skillScanFailed(error.toString()),
        );
      }
    }
  }

  Future<void> _export() async {
    final effective = ref.read(agentSettingsProvider).skills.effectiveEntries;
    final selected = <String>{};
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          insetPadding: _responsiveDialogInsetPadding(context),
          title: Text(context.l10n.agentSettings_exportSkillsTitle),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: _safeDialogContentWidth(context, 480),
              maxWidth: _safeDialogContentWidth(context, 480),
              maxHeight: _safeDialogListHeight(context),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(context.l10n.agentSettings_exportPrivacy),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final entry in effective)
                        CheckboxListTile(
                          value: selected.contains(entry.id),
                          title: Text(entry.id),
                          subtitle: Text(entry.skill.description, maxLines: 2),
                          onChanged: (value) => setDialogState(() {
                            value == true
                                ? selected.add(entry.id)
                                : selected.remove(entry.id);
                          }),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(context.l10n.common_cancel),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(context, true),
              child: Text(context.l10n.agentSettings_continueExport),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final exportTitle = context.l10n.agentSettings_exportSkillsTitle;
    final exportedMessage = context.l10n.agentSettings_skillsExported;
    await _runBusy(() async {
      final bytes = await _archiveService.exportSkills([
        for (final entry in effective)
          if (selected.contains(entry.id))
            (name: entry.id, manifest: File(entry.skill.filePath)),
      ]);
      final result = await FileExportService.saveBytes(
        bytes: bytes,
        fileName: 'aaalice-skills.zip',
        dialogTitle: exportTitle,
        mimeType: 'application/zip',
        allowedExtensions: const ['zip'],
      );
      if (result != null && mounted) {
        AppToast.success(context, exportedMessage);
      }
    });
  }

  Future<void> _import() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      withData: true,
    );
    if (picked == null || !mounted) return;
    final bytes = picked.files.single.bytes;
    if (bytes == null) {
      AppToast.error(context, context.l10n.agentSettings_skillZipReadFailed);
      return;
    }
    await _runBusy(() async {
      final target = await ref
          .read(agentSettingsProvider.notifier)
          .userSkillDirectory();
      final preview = await _archiveService.previewImport(
        bytes: bytes,
        targetDirectory: target,
      );
      if (!mounted) return;
      final replace = <String>{};
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            insetPadding: _responsiveDialogInsetPadding(context),
            title: Text(context.l10n.agentSettings_confirmSkillsImport),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: _safeDialogContentWidth(context, 520),
                maxWidth: _safeDialogContentWidth(context, 520),
                maxHeight: _safeDialogListHeight(context),
              ),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final item in preview.items)
                    CheckboxListTile(
                      value: item.conflicts && replace.contains(item.name),
                      enabled: item.conflicts,
                      onChanged: (value) => setDialogState(() {
                        value == true
                            ? replace.add(item.name)
                            : replace.remove(item.name);
                      }),
                      title: Text(item.name),
                      subtitle: Text(
                        '${item.description}\n'
                        '${context.l10n.agentSettings_skillArchiveStats(item.fileCount, item.totalBytes)}'
                        '${item.conflicts ? '\n${context.l10n.agentSettings_skillConflictReplace}' : ''}',
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.l10n.common_cancel),
              ),
              FilledButton(
                onPressed:
                    preview.items.any(
                      (item) => item.conflicts && !replace.contains(item.name),
                    )
                    ? null
                    : () => Navigator.pop(context, true),
                child: Text(context.l10n.agentSettings_install),
              ),
            ],
          ),
        ),
      );
      if (confirmed != true) return;
      await _archiveService.install(
        bytes: bytes,
        targetDirectory: target,
        replaceSkillNames: replace,
      );
      await ref.read(agentSettingsProvider.notifier).reloadSkills();
      if (mounted) {
        AppToast.success(context, context.l10n.agentSettings_skillsInstalled);
      }
    });
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) {
        AppToast.error(
          context,
          context.l10n.agentSettings_operationFailed(error.toString()),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _SkillTile extends ConsumerWidget {
  const _SkillTile({required this.entry});

  final SkillCatalogEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invocationDisabled = entry.skill.disableModelInvocation == true;
    return SwitchListTile(
      key: ValueKey('agent-skill-${entry.id}'),
      value: entry.enabled,
      onChanged: (value) async {
        try {
          await ref
              .read(agentSettingsProvider.notifier)
              .setSkillEnabled(entry.id, value);
        } catch (error) {
          if (context.mounted) {
            AppToast.error(
              context,
              context.l10n.agentSettings_operationFailed(error.toString()),
            );
          }
        }
      },
      title: Row(
        children: [
          Flexible(child: Text(entry.id)),
          const SizedBox(width: 8),
          _SourceBadge(source: entry.source),
          if (invocationDisabled) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: context.l10n.agentSettings_skillExplicitOnly,
              child: const Icon(Icons.visibility_off_outlined, size: 16),
            ),
          ],
        ],
      ),
      subtitle: Text('${entry.skill.description}\n${entry.safePath}'),
      isThreeLine: true,
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.source});

  final SkillSource source;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      child: Text(
        _skillSourceLabel(context, source),
        style: Theme.of(context).textTheme.labelSmall,
      ),
    ),
  );
}

class _DiagnosticsList extends StatelessWidget {
  const _DiagnosticsList({required this.snapshot});

  final SkillCatalogSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final shadowed = snapshot.entries
        .where((entry) => !entry.isEffective)
        .toList();
    if (snapshot.diagnostics.isEmpty && shadowed.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text(context.l10n.agentSettings_noDiagnostics)),
      );
    }
    return Column(
      children: [
        for (final entry in shadowed)
          ListTile(
            leading: const Icon(Icons.layers_outlined),
            title: Text(context.l10n.agentSettings_skillShadowed(entry.id)),
            subtitle: Text(
              '${entry.safePath}\n'
              '${context.l10n.agentSettings_preferredSource(_skillSourceLabel(context, entry.shadowedBy!))}',
            ),
          ),
        for (final item in snapshot.diagnostics)
          ListTile(
            leading: Icon(
              Icons.warning_amber,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(item.diagnostic.code.name),
            subtitle: Text('${item.diagnostic.message}\n${item.safePath}'),
          ),
      ],
    );
  }
}

String _skillSourceLabel(BuildContext context, SkillSource source) =>
    switch (source) {
      SkillSource.workspace => context.l10n.agentSettings_sourceWorkspace,
      SkillSource.piUser => context.l10n.agentSettings_sourcePiUser,
      SkillSource.commonUser => context.l10n.agentSettings_sourceCommonUser,
    };

EdgeInsets _responsiveDialogInsetPadding(BuildContext context) =>
    MediaQuery.sizeOf(context).width <= 400
    ? const EdgeInsets.symmetric(horizontal: 16, vertical: 24)
    : const EdgeInsets.symmetric(horizontal: 40, vertical: 24);

double _safeDialogListHeight(BuildContext context) =>
    (MediaQuery.sizeOf(context).height * 0.55).clamp(160.0, 480.0);

double _safeDialogContentWidth(BuildContext context, double maximum) {
  final screenWidth = MediaQuery.sizeOf(context).width;
  final outerInsets = screenWidth <= 400 ? 32.0 : 80.0;
  const contentInsets = 48.0;
  return (screenWidth - outerInsets - contentInsets).clamp(0.0, maximum);
}
