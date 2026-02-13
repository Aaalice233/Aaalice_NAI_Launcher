import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/shortcuts/default_shortcuts.dart';
import '../../../core/shortcuts/shortcut_config.dart';
import '../../../core/shortcuts/shortcut_manager.dart';
import '../../../presentation/router/app_router.dart';
import '../../../presentation/screens/settings/widgets/shortcut_settings_panel.dart';
import '../../providers/shortcuts_provider.dart';

/// 快捷键帮助对话框
/// 显示所有可用的快捷键
class ShortcutHelpDialog extends ConsumerStatefulWidget {
  const ShortcutHelpDialog({super.key});

  static Future<void> show(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (context) => const ShortcutHelpDialog(),
    );
  }

  @override
  ConsumerState<ShortcutHelpDialog> createState() =>
      _ShortcutHelpDialogState();
}

class _ShortcutHelpDialogState extends ConsumerState<ShortcutHelpDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  ShortcutContext? _selectedContext;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bindingsByContext = ref.watch(shortcutsByContextProvider);

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
        child: Column(
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.keyboard,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '快捷键帮助',
                    style: theme.textTheme.titleLarge,
                  ),
                  const Spacer(),
                  // 搜索框
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: '搜索快捷键...',
                        prefixIcon: const Icon(Icons.search, size: 20),
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.toLowerCase();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // 上下文筛选标签
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('全部'),
                    selected: _selectedContext == null,
                    onSelected: (_) {
                      setState(() {
                        _selectedContext = null;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  ...ShortcutContext.values.map((context) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(context.displayName),
                        selected: _selectedContext == context,
                        onSelected: (_) {
                          setState(() {
                            _selectedContext = context;
                          });
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),

            const Divider(),

            // 快捷键列表
            Expanded(
              child: _buildShortcutsList(bindingsByContext),
            ),

            // 底部提示
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '提示：按 F1 或 ? 键可随时打开此帮助对话框',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // 导航到设置页面并打开快捷键设置面板
                      context.go(AppRoutes.settings);
                      // 使用微任务确保页面导航完成后再打开面板
                      Future.microtask(() {
                        if (context.mounted) {
                          ShortcutSettingsPanel.show(context);
                        }
                      });
                    },
                    icon: const Icon(Icons.settings, size: 16),
                    label: Text(context.l10n.shortcuts_customize),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShortcutsList(
    Map<ShortcutContext, List<ShortcutBinding>> bindingsByContext,
  ) {
    if (_searchQuery.isNotEmpty) {
      return _buildSearchResults();
    }

    final contextsToShow = _selectedContext != null
        ? [_selectedContext!]
        : ShortcutContext.values;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: contextsToShow.length,
      itemBuilder: (context, index) {
        final shortcutContext = contextsToShow[index];
        final bindings = bindingsByContext[shortcutContext] ?? [];

        // 过滤禁用的快捷键
        final enabledBindings =
            bindings.where((b) => b.enabled).toList();

        if (enabledBindings.isEmpty) return const SizedBox.shrink();

        return _buildContextSection(shortcutContext, enabledBindings);
      },
    );
  }

  Widget _buildContextSection(
    ShortcutContext shortcutContext,
    List<ShortcutBinding> bindings,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 上下文标题
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                shortcutContext.displayName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${bindings.length})',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),

        // 快捷键列表
        ...bindings.map((binding) => _buildShortcutItem(binding)),

        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildShortcutItem(ShortcutBinding binding) {
    final theme = Theme.of(context);
    final shortcut = binding.effectiveShortcut;

    if (shortcut == null) return const SizedBox.shrink();

    final shortcutLabel = AppShortcutManager.getDisplayLabel(shortcut);
    final actionName = _getActionDisplayName(binding);

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              actionName,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: Text(
              shortcutLabel,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final searchResults =
        ref.read(searchShortcutsProvider(_searchQuery));

    if (searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              '未找到匹配的快捷键',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        return _buildShortcutItem(searchResults[index]);
      },
    );
  }

  String _getActionDisplayName(ShortcutBinding binding) {
    final l10n = context.l10n;
    final key = binding.actionKey;

    // 使用 switch 从 ARB 文件获取本地化文本
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
      case 'shortcut_action_minimize_to_tray':
        return l10n.shortcut_action_minimize_to_tray;
      case 'shortcut_action_quit_app':
        return l10n.shortcut_action_quit_app;
      case 'shortcut_action_show_shortcut_help':
        return l10n.shortcut_action_show_shortcut_help;
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
}

/// 快捷键帮助悬浮按钮
/// 可以放置在页面角落快速打开帮助
class ShortcutHelpFab extends ConsumerWidget {
  const ShortcutHelpFab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton.small(
      heroTag: 'shortcut_help',
      onPressed: () => ShortcutHelpDialog.show(context),
      tooltip: '快捷键帮助 (F1)',
      child: const Icon(Icons.keyboard),
    );
  }
}
