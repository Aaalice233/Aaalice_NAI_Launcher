import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/shortcuts/default_shortcuts.dart';
import '../../../../core/shortcuts/shortcut_config.dart';
import '../../../../core/shortcuts/shortcut_manager.dart';
import '../../../providers/shortcuts_provider.dart';
import '../../../widgets/shortcuts/shortcut_binding_editor.dart';
import '../../../widgets/shortcuts/shortcut_help_dialog.dart';

/// 快捷键设置面板
/// 用于自定义和管理快捷键
class ShortcutSettingsPanel extends ConsumerStatefulWidget {
  const ShortcutSettingsPanel({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return const ShortcutSettingsPanel();
        },
      ),
    );
  }

  @override
  ConsumerState<ShortcutSettingsPanel> createState() =>
      _ShortcutSettingsPanelState();
}

class _ShortcutSettingsPanelState
    extends ConsumerState<ShortcutSettingsPanel> {
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
      data: (config) => _buildContent(context, theme, config, bindingsByContext),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => Center(
        child: Text('加载失败: $error'),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ThemeData theme,
    ShortcutConfig config,
    Map<ShortcutContext, List<ShortcutBinding>> bindingsByContext,
  ) {
    return Column(
      children: [
        // 标题栏
        Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.2),
              ),
            ),
          ),
          child: Column(
            children: [
              // 拖动条
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.keyboard,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '快捷键设置',
                    style: theme.textTheme.titleLarge,
                  ),
                  const Spacer(),
                  // 帮助按钮
                  IconButton(
                    icon: const Icon(Icons.help_outline),
                    tooltip: '查看快捷键帮助',
                    onPressed: () => ShortcutHelpDialog.show(context),
                  ),
                  // 关闭按钮
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 搜索框和全局设置
              Row(
                children: [
                  // 搜索框
                  Expanded(
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
                          vertical: 10,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value.toLowerCase();
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // 全局开关
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '启用快捷键',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(width: 4),
                      Switch(
                        value: config.enableShortcuts,
                        onChanged: (value) {
                          ref
                              .read(shortcutConfigNotifierProvider.notifier)
                              .updateSettings(enableShortcuts: value);
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 其他设置
              Row(
                children: [
                  // 显示在Tooltip中
                  FilterChip(
                    label: const Text('在提示中显示'),
                    selected: config.showShortcutInTooltip,
                    onSelected: config.enableShortcuts
                        ? (value) {
                            ref
                                .read(
                                  shortcutConfigNotifierProvider.notifier,
                                )
                                .updateSettings(
                                  showShortcutInTooltip: value,
                                );
                          }
                        : null,
                  ),
                  const SizedBox(width: 8),
                  // 显示徽章
                  FilterChip(
                    label: const Text('显示快捷键徽章'),
                    selected: config.showShortcutBadges,
                    onSelected: config.enableShortcuts
                        ? (value) {
                            ref
                                .read(
                                  shortcutConfigNotifierProvider.notifier,
                                )
                                .updateSettings(
                                  showShortcutBadges: value,
                                );
                          }
                        : null,
                  ),
                  const SizedBox(width: 8),
                  // 在菜单中显示
                  FilterChip(
                    label: const Text('在菜单中显示'),
                    selected: config.showInMenus,
                    onSelected: config.enableShortcuts
                        ? (value) {
                            ref
                                .read(
                                  shortcutConfigNotifierProvider.notifier,
                                )
                                .updateSettings(showInMenus: value);
                          }
                        : null,
                  ),
                  const Spacer(),
                  // 重置所有按钮
                  TextButton.icon(
                    onPressed: _showResetConfirmDialog,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('重置所有'),
                  ),
                ],
              ),
            ],
          ),
        ),

        // 快捷键列表
        Expanded(
          child: _searchQuery.isNotEmpty
              ? _buildSearchResults(config)
              : _buildShortcutsList(config, bindingsByContext),
        ),
      ],
    );
  }

  Widget _buildShortcutsList(
    ShortcutConfig config,
    Map<ShortcutContext, List<ShortcutBinding>> bindingsByContext,
  ) {
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
            shortcutContext.displayName,
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
        color: theme.colorScheme.primaryContainer.withOpacity(0.2),
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

    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
      title: Text(
        _getActionDisplayName(binding),
        style: theme.textTheme.bodyMedium,
      ),
      subtitle: binding.hasCustomShortcut
          ? Text(
              '默认: ${AppShortcutManager.getDisplayLabel(binding.defaultShortcut)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            )
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 快捷键标签
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: binding.hasCustomShortcut
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: binding.hasCustomShortcut
                    ? theme.colorScheme.primary.withOpacity(0.3)
                    : theme.colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: Text(
              shortcut != null
                  ? AppShortcutManager.getDisplayLabel(shortcut)
                  : '未设置',
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: binding.hasCustomShortcut
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 编辑按钮
          IconButton(
            icon: const Icon(Icons.edit, size: 18),
            tooltip: '编辑',
            visualDensity: VisualDensity.compact,
            onPressed: () {
              setState(() {
                _editingId = binding.id;
              });
            },
          ),
          // 重置按钮（仅当有自定义快捷键时显示）
          if (binding.hasCustomShortcut)
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              tooltip: '重置为默认',
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                await ref
                    .read(shortcutConfigNotifierProvider.notifier)
                    .resetToDefault(binding.id);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(ShortcutConfig config) {
    final searchResults = ref.watch(searchShortcutsProvider(_searchQuery));

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
        return _buildShortcutTile(config, searchResults[index]);
      },
    );
  }

  void _showResetConfirmDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重置所有快捷键'),
        content: const Text(
          '确定要将所有快捷键重置为默认设置吗？此操作不可撤销。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              await ref
                  .read(shortcutConfigNotifierProvider.notifier)
                  .resetAllToDefault();
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('重置'),
          ),
        ],
      ),
    );
  }

  String _getActionDisplayName(ShortcutBinding binding) {
    final Map<String, String> actionNames = {
      'shortcut_action_navigate_to_generation': '生成页面',
      'shortcut_action_navigate_to_local_gallery': '本地画廊',
      'shortcut_action_navigate_to_online_gallery': '在线画廊',
      'shortcut_action_navigate_to_random_config': '随机配置',
      'shortcut_action_navigate_to_tag_library': '词库页面',
      'shortcut_action_navigate_to_statistics': '统计页面',
      'shortcut_action_navigate_to_settings': '设置页面',
      'shortcut_action_generate_image': '生成图像',
      'shortcut_action_cancel_generation': '取消生成',
      'shortcut_action_add_to_queue': '加入队列',
      'shortcut_action_random_prompt': '随机提示词',
      'shortcut_action_clear_prompt': '清空提示词',
      'shortcut_action_toggle_prompt_mode': '切换正/负面模式',
      'shortcut_action_open_tag_library': '打开词库',
      'shortcut_action_save_image': '保存图像',
      'shortcut_action_upscale_image': '放大图像',
      'shortcut_action_copy_image': '复制图像',
      'shortcut_action_fullscreen_preview': '全屏预览',
      'shortcut_action_open_params_panel': '打开参数面板',
      'shortcut_action_open_history_panel': '打开历史面板',
      'shortcut_action_reuse_params': '复用参数',
      'shortcut_action_previous_image': '上一张',
      'shortcut_action_next_image': '下一张',
      'shortcut_action_zoom_in': '放大',
      'shortcut_action_zoom_out': '缩小',
      'shortcut_action_reset_zoom': '重置缩放',
      'shortcut_action_toggle_fullscreen': '全屏切换',
      'shortcut_action_close_viewer': '关闭查看器',
      'shortcut_action_toggle_favorite': '收藏切换',
      'shortcut_action_copy_prompt': '复制Prompt',
      'shortcut_action_reuse_gallery_params': '复用参数',
      'shortcut_action_delete_image': '删除图片',
      'shortcut_action_previous_page': '上一页',
      'shortcut_action_next_page': '下一页',
      'shortcut_action_refresh_gallery': '刷新',
      'shortcut_action_focus_search': '搜索聚焦',
      'shortcut_action_enter_selection_mode': '进入选择模式',
      'shortcut_action_open_filter_panel': '打开筛选面板',
      'shortcut_action_clear_filter': '清除筛选',
      'shortcut_action_toggle_category_panel': '切换分类面板',
      'shortcut_action_jump_to_date': '跳转到日期',
      'shortcut_action_open_folder': '打开文件夹',
      'shortcut_action_select_all_tags': '全选',
      'shortcut_action_deselect_all_tags': '取消全选',
      'shortcut_action_new_category': '新建分类',
      'shortcut_action_new_tag': '新建词条',
      'shortcut_action_search_tags': '搜索',
      'shortcut_action_batch_delete_tags': '批量删除',
      'shortcut_action_batch_copy_tags': '批量复制',
      'shortcut_action_send_to_home': '发送到主页',
      'shortcut_action_exit_selection_mode': '退出选择模式',
      'shortcut_action_sync_danbooru': '同步Danbooru',
      'shortcut_action_generate_preview': '生成预览',
      'shortcut_action_search_presets': '搜索预设',
      'shortcut_action_new_preset': '新建预设',
      'shortcut_action_duplicate_preset': '复制预设',
      'shortcut_action_delete_preset': '删除预设',
      'shortcut_action_close_config': '关闭窗口',
      'shortcut_action_show_shortcut_help': '显示快捷键帮助',
      'shortcut_action_minimize_to_tray': '最小化到托盘',
      'shortcut_action_quit_app': '退出应用',
      'shortcut_action_toggle_queue': '显示/隐藏队列',
      'shortcut_action_toggle_queue_pause': '开始/暂停队列',
      'shortcut_action_toggle_theme': '切换主题',
    };

    return actionNames[binding.actionKey] ??
        binding.actionKey.replaceAll('shortcut_action_', '');
  }
}
