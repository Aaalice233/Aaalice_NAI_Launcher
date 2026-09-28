import 'package:nai_launcher/presentation/widgets/common/horizontal_action_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import '../../../core/shortcuts/default_shortcuts.dart';
import '../../../core/shortcuts/shortcut_config.dart';
import '../../../core/shortcuts/shortcut_manager.dart';
import '../../../presentation/router/app_routes.dart';
import '../../../presentation/screens/settings/widgets/shortcut_settings_panel.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../../providers/shortcuts_provider.dart';
import 'shortcut_display_names.dart';

/// 快捷键帮助对话框
/// 显示所有可用的快捷键
class ShortcutHelpDialog extends ConsumerStatefulWidget {
  const ShortcutHelpDialog({super.key, this.scrollController});

  final ScrollController? scrollController;

  static Future<void> show(BuildContext context) {
    return AdaptivePresenter.showForm<void>(
      context: context,
      titleBuilder: (context) => Row(
        children: [
          Icon(Icons.keyboard, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.shortcut_help_title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
        ],
      ),
      dialogWidth: 800,
      builder: (context, scrollController) =>
          ShortcutHelpDialog(scrollController: scrollController),
    );
  }

  @override
  ConsumerState<ShortcutHelpDialog> createState() => _ShortcutHelpDialogState();
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

  void _openShortcutSettings() {
    final router = GoRouter.of(context);
    final rootNavigator = Navigator.of(context, rootNavigator: true);
    Navigator.pop(context);
    router.go(AppRoutes.settings);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (rootNavigator.mounted) {
        ShortcutSettingsPanel.show(rootNavigator.context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bindingsByContext = ref.watch(shortcutsByContextProvider);

    return SingleChildScrollView(
      key: const ValueKey('shortcut-help-scroll'),
      controller: widget.scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              key: const ValueKey('shortcut-help-search'),
              controller: _searchController,
              textAlignVertical: TextAlignVertical.center,
              decoration: InputDecoration(
                hintText: context.l10n.shortcut_help_search,
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
                setState(() => _searchQuery = value.toLowerCase());
              },
            ),
          ),
          HorizontalActionStrip(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: Text(context.l10n.shortcut_help_all),
                  selected: _selectedContext == null,
                  onSelected: (_) => setState(() => _selectedContext = null),
                ),
                const SizedBox(width: 8),
                ...ShortcutContext.values.map((shortcutContext) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(
                        shortcutContextDisplayName(
                          context.l10n,
                          shortcutContext,
                        ),
                      ),
                      selected: _selectedContext == shortcutContext,
                      onSelected: (_) =>
                          setState(() => _selectedContext = shortcutContext),
                    ),
                  );
                }),
              ],
            ),
          ),
          const Divider(),
          _buildShortcutsList(bindingsByContext),
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.colorScheme.surfaceContainerHighest,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.shortcut_help_tip,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _openShortcutSettings,
                    icon: const Icon(Icons.settings, size: 16),
                    label: Text(context.l10n.shortcuts_customize),
                  ),
                ),
              ],
            ),
          ),
        ],
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
      primary: false,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: contextsToShow.length,
      itemBuilder: (context, index) {
        final shortcutContext = contextsToShow[index];
        final bindings = bindingsByContext[shortcutContext] ?? [];

        // 过滤禁用的快捷键
        final enabledBindings = bindings.where((b) => b.enabled).toList();

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
                shortcutContextDisplayName(context.l10n, shortcutContext),
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
    final actionName = shortcutActionDisplayName(
      context.l10n,
      binding.actionKey,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final shortcutChip = Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              shortcutLabel,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          );
          final stacks =
              constraints.maxWidth < 360 ||
              MediaQuery.textScalerOf(context).scale(1) >= 2;
          if (stacks) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(actionName, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                shortcutChip,
              ],
            );
          }
          return Row(
            children: [
              Expanded(
                child: Text(actionName, style: theme.textTheme.bodyMedium),
              ),
              const SizedBox(width: 8),
              Flexible(child: shortcutChip),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchResults() {
    final searchResults = ref.read(searchShortcutsProvider(_searchQuery));

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
              context.l10n.shortcut_settings_no_matches,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      primary: false,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        return _buildShortcutItem(searchResults[index]);
      },
    );
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
      tooltip: context.l10n.shortcut_help_fabTooltip,
      child: const Icon(Icons.keyboard),
    );
  }
}
