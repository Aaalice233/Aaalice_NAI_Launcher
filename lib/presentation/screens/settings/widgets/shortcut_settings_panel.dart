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
      sideSheetWidth: 720,
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
            _getContextDisplayName(shortcutContext),
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
        Text(_getActionDisplayName(binding), style: theme.textTheme.bodyMedium),
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

  String _getActionDisplayName(ShortcutBinding binding) {
    final l10n = context.l10n;
    final key = binding.actionKey;

    switch (key) {
      case 'shortcut_action_navigate_to_generation':
        return l10n.shortcut_action_navigate_to_generation;
      case 'shortcut_action_navigate_to_local_gallery':
        return l10n.shortcut_action_navigate_to_local_gallery;
      case 'shortcut_action_navigate_to_online_gallery':
        return l10n.shortcut_action_navigate_to_online_gallery;
      case 'shortcut_action_navigate_to_random_config':
        return l10n.shortcut_action_navigate_to_random_config;
      case 'shortcut_action_navigate_to_tag_library':
        return l10n.shortcut_action_navigate_to_tag_library;
      case 'shortcut_action_navigate_to_statistics':
        return l10n.shortcut_action_navigate_to_statistics;
      case 'shortcut_action_navigate_to_settings':
        return l10n.shortcut_action_navigate_to_settings;
      case 'shortcut_action_generate_image':
        return l10n.shortcut_action_generate_image;
      case 'shortcut_action_generation_prev_image':
        return l10n.shortcut_action_generation_prev_image;
      case 'shortcut_action_generation_next_image':
        return l10n.shortcut_action_generation_next_image;
      case 'shortcut_action_cancel_generation':
        return l10n.shortcut_action_cancel_generation;
      case 'shortcut_action_add_to_queue':
        return l10n.shortcut_action_add_to_queue;
      case 'shortcut_action_random_prompt':
        return l10n.shortcut_action_random_prompt;
      case 'shortcut_action_clear_prompt':
        return l10n.shortcut_action_clear_prompt;
      case 'shortcut_action_toggle_prompt_mode':
        return l10n.shortcut_action_toggle_prompt_mode;
      case 'shortcut_action_open_tag_library':
        return l10n.shortcut_action_open_tag_library;
      case 'shortcut_action_save_image':
        return l10n.shortcut_action_save_image;
      case 'shortcut_action_upscale_image':
        return l10n.shortcut_action_upscale_image;
      case 'shortcut_action_copy_image':
        return l10n.shortcut_action_copy_image;
      case 'shortcut_action_fullscreen_preview':
        return l10n.shortcut_action_fullscreen_preview;
      case 'shortcut_action_open_params_panel':
        return l10n.shortcut_action_open_params_panel;
      case 'shortcut_action_open_history_panel':
        return l10n.shortcut_action_open_history_panel;
      case 'shortcut_action_reuse_params':
        return l10n.shortcut_action_reuse_params;
      case 'shortcut_action_previous_image':
        return l10n.shortcut_action_previous_image;
      case 'shortcut_action_next_image':
        return l10n.shortcut_action_next_image;
      case 'shortcut_action_zoom_in':
        return l10n.shortcut_action_zoom_in;
      case 'shortcut_action_zoom_out':
        return l10n.shortcut_action_zoom_out;
      case 'shortcut_action_reset_zoom':
        return l10n.shortcut_action_reset_zoom;
      case 'shortcut_action_toggle_fullscreen':
        return l10n.shortcut_action_toggle_fullscreen;
      case 'shortcut_action_close_viewer':
        return l10n.shortcut_action_close_viewer;
      case 'shortcut_action_toggle_favorite':
        return l10n.shortcut_action_toggle_favorite;
      case 'shortcut_action_copy_prompt':
        return l10n.shortcut_action_copy_prompt;
      case 'shortcut_action_reuse_gallery_params':
        return l10n.shortcut_action_reuse_gallery_params;
      case 'shortcut_action_delete_image':
        return l10n.shortcut_action_delete_image;
      case 'shortcut_action_previous_page':
        return l10n.shortcut_action_previous_page;
      case 'shortcut_action_next_page':
        return l10n.shortcut_action_next_page;
      case 'shortcut_action_refresh_gallery':
        return l10n.shortcut_action_refresh_gallery;
      case 'shortcut_action_focus_search':
        return l10n.shortcut_action_focus_search;
      case 'shortcut_action_enter_selection_mode':
        return l10n.shortcut_action_enter_selection_mode;
      case 'shortcut_action_open_filter_panel':
        return l10n.shortcut_action_open_filter_panel;
      case 'shortcut_action_clear_filter':
        return l10n.shortcut_action_clear_filter;
      case 'shortcut_action_toggle_category_panel':
        return l10n.shortcut_action_toggle_category_panel;
      case 'shortcut_action_jump_to_date':
        return l10n.shortcut_action_jump_to_date;
      case 'shortcut_action_open_folder':
        return l10n.shortcut_action_open_folder;
      case 'shortcut_action_select_all_tags':
        return l10n.shortcut_action_select_all_tags;
      case 'shortcut_action_deselect_all_tags':
        return l10n.shortcut_action_deselect_all_tags;
      case 'shortcut_action_new_category':
        return l10n.shortcut_action_new_category;
      case 'shortcut_action_new_tag':
        return l10n.shortcut_action_new_tag;
      case 'shortcut_action_search_tags':
        return l10n.shortcut_action_search_tags;
      case 'shortcut_action_batch_delete_tags':
        return l10n.shortcut_action_batch_delete_tags;
      case 'shortcut_action_batch_copy_tags':
        return l10n.shortcut_action_batch_copy_tags;
      case 'shortcut_action_send_to_home':
        return l10n.shortcut_action_send_to_home;
      case 'shortcut_action_exit_selection_mode':
        return l10n.shortcut_action_exit_selection_mode;
      case 'shortcut_action_sync_danbooru':
        return l10n.shortcut_action_sync_danbooru;
      case 'shortcut_action_generate_preview':
        return l10n.shortcut_action_generate_preview;
      case 'shortcut_action_search_presets':
        return l10n.shortcut_action_search_presets;
      case 'shortcut_action_new_preset':
        return l10n.shortcut_action_new_preset;
      case 'shortcut_action_duplicate_preset':
        return l10n.shortcut_action_duplicate_preset;
      case 'shortcut_action_delete_preset':
        return l10n.shortcut_action_delete_preset;
      case 'shortcut_action_close_config':
        return l10n.shortcut_action_close_config;
      case 'shortcut_action_show_shortcut_help':
        return l10n.shortcut_action_show_shortcut_help;
      case 'shortcut_action_minimize_to_tray':
        return l10n.shortcut_action_minimize_to_tray;
      case 'shortcut_action_quit_app':
        return l10n.shortcut_action_quit_app;
      case 'shortcut_action_toggle_queue':
        return l10n.shortcut_action_toggle_queue;
      case 'shortcut_action_toggle_queue_pause':
        return l10n.shortcut_action_toggle_queue_pause;
      case 'shortcut_action_toggle_theme':
        return l10n.shortcut_action_toggle_theme;
      default:
        return key.replaceAll('shortcut_action_', '');
    }
  }

  String _getContextDisplayName(ShortcutContext shortcutContext) {
    final l10n = context.l10n;

    switch (shortcutContext) {
      case ShortcutContext.global:
        return l10n.shortcut_context_global;
      case ShortcutContext.generation:
        return l10n.shortcut_context_generation;
      case ShortcutContext.gallery:
        return l10n.shortcut_context_gallery;
      case ShortcutContext.viewer:
        return l10n.shortcut_context_viewer;
      case ShortcutContext.tagLibrary:
        return l10n.shortcut_context_tag_library;
      case ShortcutContext.randomConfig:
        return l10n.shortcut_context_random_config;
      case ShortcutContext.settings:
        return l10n.shortcut_context_settings;
      case ShortcutContext.input:
        return l10n.shortcut_context_input;
      case ShortcutContext.vibeDetail:
        return l10n.shortcut_context_vibe_detail;
    }
  }
}
