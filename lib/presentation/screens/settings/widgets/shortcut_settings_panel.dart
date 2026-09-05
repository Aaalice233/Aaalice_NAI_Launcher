import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/shortcuts/default_shortcuts.dart';
import '../../../../core/shortcuts/shortcut_config.dart';
import '../../../../core/shortcuts/shortcut_manager.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../adaptive/adaptive_presenter.dart';
import '../../../providers/shortcuts_provider.dart';
import '../../../widgets/common/themed_confirm_dialog.dart';
import '../../../widgets/shortcuts/shortcut_binding_editor.dart';
import '../../../widgets/shortcuts/shortcut_display_names.dart';
import '../../../widgets/shortcuts/shortcut_help_dialog.dart';

/// 快捷键设置面板
/// 用于自定义和管理快捷键
class ShortcutSettingsPanel extends ConsumerStatefulWidget {
  const ShortcutSettingsPanel({super.key, this.presented = false});

  final bool presented;

  static Future<void> show(BuildContext context) {
    return AdaptivePresenter.showForm<void>(
      context: context,
      titleBuilder: (context) {
        final theme = Theme.of(context);
        return Row(
          children: [
            Icon(Icons.keyboard, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.l10n.shortcut_settings_title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: context.l10n.shortcut_settings_help,
              onPressed: () => ShortcutHelpDialog.show(context),
            ),
          ],
        );
      },
      dialogWidth: 720,
      builder: (context, scrollController) =>
          const ShortcutSettingsPanel(presented: true),
    );
  }

  @override
  ConsumerState<ShortcutSettingsPanel> createState() =>
      _ShortcutSettingsPanelState();
}

class _ShortcutSettingsPanelState extends ConsumerState<ShortcutSettingsPanel> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  ShortcutContext? _expandedContext;
  String? _editingId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final configAsync = ref.watch(shortcutConfigNotifierProvider);
    final bindingsByContext = ref.watch(shortcutsByContextProvider);

    return configAsync.when(
      data: (config) =>
          _buildContent(context, theme, config, bindingsByContext),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text(context.l10n.settings_loadFailed(error.toString())),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    ShortcutConfig config,
    Map<ShortcutContext, List<ShortcutBinding>> bindingsByContext,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactHeader =
            constraints.maxWidth < 520 ||
            MediaQuery.textScalerOf(context).scale(1) >= 1.6;
        final searchField = TextField(
          controller: _searchController,
          textAlignVertical: TextAlignVertical.center,
          decoration: InputDecoration(
            hintText: context.l10n.shortcut_settings_search,
            prefixIcon: const Icon(Icons.search, size: 20),
            isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
          onChanged: (value) => setState(() {
            _searchQuery = value.toLowerCase();
          }),
        );
        final enabledSwitch = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                context.l10n.shortcut_settings_enable,
                style: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: 4),
            Switch(
              value: config.enableShortcuts,
              onChanged: (value) => ref
                  .read(shortcutConfigNotifierProvider.notifier)
                  .updateSettings(enableShortcuts: value),
            ),
          ],
        );

        final header = Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
          ),
          child: Column(
            children: [
              if (!widget.presented) ...[
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.keyboard, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        context.l10n.shortcut_settings_title,
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.help_outline),
                      tooltip: context.l10n.shortcut_settings_help,
                      onPressed: () => ShortcutHelpDialog.show(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).closeButtonTooltip,
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              if (compactHeader) ...[
                searchField,
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerLeft, child: enabledSwitch),
              ] else
                Row(
                  children: [
                    Expanded(child: searchField),
                    const SizedBox(width: 12),
                    enabledSwitch,
                  ],
                ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FilterChip(
                      label: Text(
                        context.l10n.shortcut_settings_show_in_tooltips,
                      ),
                      selected: config.showShortcutInTooltip,
                      onSelected: config.enableShortcuts
                          ? (value) => ref
                                .read(shortcutConfigNotifierProvider.notifier)
                                .updateSettings(showShortcutInTooltip: value)
                          : null,
                    ),
                    FilterChip(
                      label: Text(context.l10n.shortcut_settings_show_badges),
                      selected: config.showShortcutBadges,
                      onSelected: config.enableShortcuts
                          ? (value) => ref
                                .read(shortcutConfigNotifierProvider.notifier)
                                .updateSettings(showShortcutBadges: value)
                          : null,
                    ),
                    FilterChip(
                      label: Text(context.l10n.shortcut_settings_show_in_menus),
                      selected: config.showInMenus,
                      onSelected: config.enableShortcuts
                          ? (value) => ref
                                .read(shortcutConfigNotifierProvider.notifier)
                                .updateSettings(showInMenus: value)
                          : null,
                    ),
                    TextButton.icon(
                      onPressed: _showResetConfirmDialog,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: Text(context.l10n.shortcut_settings_reset_all),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );

        return Column(
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * 0.58,
              ),
              child: SingleChildScrollView(child: header),
            ),
            Expanded(
              child: _searchQuery.isNotEmpty
                  ? _buildSearchResults(config)
                  : _buildShortcutsList(config, bindingsByContext),
            ),
          ],
        );
      },
    );
  }

  Widget _buildShortcutsList(
    ShortcutConfig config,
    Map<ShortcutContext, List<ShortcutBinding>> bindingsByContext,
  ) {
    if (bindingsByContext.values.every((bindings) => bindings.isEmpty)) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: ShortcutContext.values.length,
      itemBuilder: (context, index) {
        final shortcutContext = ShortcutContext.values[index];
        final bindings = bindingsByContext[shortcutContext] ?? [];

        if (bindings.isEmpty) return const SizedBox.shrink();

        return _buildContextExpansionTile(config, shortcutContext, bindings);
      },
    );
  }

  Widget _buildContextExpansionTile(
    ShortcutConfig config,
    ShortcutContext shortcutContext,
    List<ShortcutBinding> bindings,
  ) {
    final theme = Theme.of(context);
    final isExpanded = _expandedContext == shortcutContext;

    return Column(
      children: [
        // 上下文标题
        ListTile(
          dense: true,
          leading: Icon(
            isExpanded ? Icons.expand_less : Icons.expand_more,
            color: theme.colorScheme.primary,
          ),
          title: Text(
            shortcutContextDisplayName(context.l10n, shortcutContext),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          trailing: Text(
            '${bindings.length}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          onTap: () {
            setState(() {
              _expandedContext = isExpanded ? null : shortcutContext;
            });
          },
        ),

        // 快捷键列表
        if (isExpanded)
          ...bindings.map((binding) => _buildShortcutTile(config, binding)),

        const Divider(height: 1),
      ],
    );
  }

  Widget _buildShortcutTile(ShortcutConfig config, ShortcutBinding binding) {
    final theme = Theme.of(context);
    final isEditing = _editingId == binding.id;
    final shortcut = binding.effectiveShortcut;

    if (isEditing) {
      return Container(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
        padding: const EdgeInsets.all(16),
        child: ShortcutBindingEditor(
          binding: binding,
          inline: false,
          onSave: (newBinding) async {
            await ref
                .read(shortcutConfigNotifierProvider.notifier)
                .updateBinding(newBinding);
            setState(() {
              _editingId = null;
            });
          },
          onCancel: () {
            setState(() {
              _editingId = null;
            });
          },
        ),
      );
    }

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          shortcutActionDisplayName(context.l10n, binding.actionKey),
          style: theme.textTheme.bodyMedium,
        ),
        if (binding.hasCustomShortcut)
          Text(
            context.l10n.shortcut_settings_defaultShortcut(
              AppShortcutManager.getDisplayLabel(binding.defaultShortcut),
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
      ],
    );
    final shortcutLabel = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: binding.hasCustomShortcut
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        shortcut != null
            ? AppShortcutManager.getDisplayLabel(shortcut)
            : context.l10n.shortcut_settings_unassigned,
        style: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          fontWeight: FontWeight.w600,
          color: binding.hasCustomShortcut
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurface,
        ),
      ),
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        shortcutLabel,
        const SizedBox(width: 4),
        IconButton(
          icon: const Icon(Icons.edit, size: 18),
          tooltip: context.l10n.common_edit,
          onPressed: () => setState(() => _editingId = binding.id),
        ),
        if (binding.hasCustomShortcut)
          IconButton(
            icon: const Icon(Icons.refresh, size: 18),
            tooltip: context.l10n.shortcut_settings_reset_to_default,
            onPressed: () => ref
                .read(shortcutConfigNotifierProvider.notifier)
                .resetToDefault(binding.id),
          ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stack =
            constraints.maxWidth < 520 ||
            MediaQuery.textScalerOf(context).scale(1) >= 1.6;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
          child: stack
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleBlock,
                    const SizedBox(height: 4),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: actions,
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: titleBlock),
                    const SizedBox(width: 8),
                    actions,
                  ],
                ),
        );
      },
    );
  }

  Widget _buildSearchResults(ShortcutConfig config) {
    final searchResults = ref.watch(searchShortcutsProvider(_searchQuery));

    if (searchResults.isEmpty) return _buildEmptyState();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        return _buildShortcutTile(config, searchResults[index]);
      },
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              context.l10n.shortcut_settings_no_matches,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showResetConfirmDialog() async {
    final confirmed = await ThemedConfirmDialog.show(
      context: context,
      title: context.l10n.shortcut_settings_reset_all_title,
      content: context.l10n.shortcut_settings_reset_all_confirm,
      confirmText: context.l10n.common_reset,
      cancelText: context.l10n.common_cancel,
      type: ThemedConfirmDialogType.warning,
      icon: Icons.restart_alt_rounded,
    );
    if (!confirmed) return;
    await ref.read(shortcutConfigNotifierProvider.notifier).resetAllToDefault();
  }
}
