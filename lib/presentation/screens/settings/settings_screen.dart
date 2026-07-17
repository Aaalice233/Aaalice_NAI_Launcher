import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import 'sections/account_settings_section.dart';
import 'sections/appearance_settings_section.dart';
import 'sections/generation_settings_section.dart';
import 'sections/storage_settings_section.dart';
import 'sections/privacy_settings_section.dart';
import 'sections/network_settings_section.dart';
import 'sections/shortcut_settings_section.dart';
import 'sections/integrations_settings_section.dart';
import 'sections/about_settings_section.dart';

/// 设置页面 Section 数据模型
class _SettingsSection {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget widget;

  const _SettingsSection({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.widget,
  });
}

/// 设置页面 - 使用 NavigationRail 侧边栏导航布局
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _selectedIndex = 0;
  final _contentScrollController = ScrollController();
  bool _isContentScrolled = false;

  @override
  void initState() {
    super.initState();
    _contentScrollController.addListener(_onContentScroll);
  }

  List<_SettingsSection> _buildSections(BuildContext context) {
    return [
      _SettingsSection(
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        label: context.l10n.settings_account,
        widget: const AccountSettingsSection(),
      ),
      _SettingsSection(
        icon: Icons.palette_outlined,
        selectedIcon: Icons.palette,
        label: context.l10n.settings_appearance,
        widget: const AppearanceSettingsSection(),
      ),
      _SettingsSection(
        icon: Icons.tune_outlined,
        selectedIcon: Icons.tune,
        label: context.l10n.settings_generation,
        widget: const GenerationSettingsSection(),
      ),
      _SettingsSection(
        icon: Icons.storage_outlined,
        selectedIcon: Icons.storage,
        label: context.l10n.settings_dataStorage,
        widget: const StorageSettingsSection(),
      ),
      _SettingsSection(
        icon: Icons.shield_outlined,
        selectedIcon: Icons.shield,
        label: context.l10n.settings_privacySharing,
        widget: const PrivacySettingsSection(),
      ),
      _SettingsSection(
        icon: Icons.network_check_outlined,
        selectedIcon: Icons.network_check,
        label: context.l10n.settings_network,
        widget: const NetworkSettingsSection(),
      ),
      _SettingsSection(
        icon: Icons.keyboard_outlined,
        selectedIcon: Icons.keyboard,
        label: context.l10n.settings_shortcuts,
        widget: const ShortcutSettingsSection(),
      ),
      _SettingsSection(
        icon: Icons.extension_outlined,
        selectedIcon: Icons.extension,
        label: context.l10n.settings_integrations,
        widget: const IntegrationsSettingsSection(),
      ),
      _SettingsSection(
        icon: Icons.info_outlined,
        selectedIcon: Icons.info,
        label: context.l10n.settings_about,
        widget: const AboutSettingsSection(),
      ),
    ];
  }

  @override
  void dispose() {
    _contentScrollController.removeListener(_onContentScroll);
    _contentScrollController.dispose();
    super.dispose();
  }

  void _onContentScroll() {
    final scrolled = _contentScrollController.offset > 0;
    if (scrolled != _isContentScrolled) {
      setState(() => _isContentScrolled = scrolled);
    }
  }

  void _onSectionSelected(int index) {
    setState(() {
      _selectedIndex = index;
      // 切换 section 时重置滚动位置
      _contentScrollController.jumpTo(0);
      _isContentScrolled = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final sections = _buildSections(context);
    if (_selectedIndex >= sections.length) {
      _selectedIndex = sections.length - 1;
    }

    // 响应式断点
    // >800px: 扩展模式（显示标签）
    // 600-800px: 图标模式（仅图标）
    // <600px: 使用 Drawer
    final isExtended = screenWidth > 800;
    final isMobile = screenWidth < 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settings_title),
        // 滚动后变暗色
        backgroundColor: _isContentScrolled
            ? theme.colorScheme.surfaceContainerHighest
            : null,
        surfaceTintColor: Colors.transparent,
        // 移动端显示抽屉菜单按钮
        leading: isMobile
            ? Builder(
                builder: (context) {
                  return IconButton(
                    icon: const Icon(Icons.menu),
                    onPressed: () => Scaffold.of(context).openDrawer(),
                  );
                },
              )
            : null,
      ),
      // 移动端使用 Drawer
      drawer: isMobile ? _buildDrawer(context, sections) : null,
      body: Row(
        children: [
          // 桌面/平板端显示 NavigationRail
          if (!isMobile) _buildNavigationRail(context, isExtended, sections),
          if (!isMobile) const VerticalDivider(thickness: 1, width: 1),
          // 内容区 - 置顶排列，限制最大宽度
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  controller: _contentScrollController,
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                      maxWidth: 900,
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: sections[_selectedIndex].widget,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 构建 NavigationRail 侧边栏
  Widget _buildNavigationRail(
    BuildContext context,
    bool isExtended,
    List<_SettingsSection> sections,
  ) {
    final theme = Theme.of(context);

    return NavigationRail(
      selectedIndex: _selectedIndex,
      onDestinationSelected: _onSectionSelected,
      extended: isExtended,
      minExtendedWidth: 180,
      backgroundColor: theme.colorScheme.surface,
      selectedIconTheme: IconThemeData(color: theme.colorScheme.primary),
      selectedLabelTextStyle: TextStyle(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
      unselectedIconTheme: IconThemeData(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
      ),
      unselectedLabelTextStyle: TextStyle(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
      ),
      destinations: sections.map((section) {
        return NavigationRailDestination(
          icon: Icon(section.icon),
          selectedIcon: Icon(section.selectedIcon),
          label: Text(section.label),
        );
      }).toList(),
    );
  }

  /// 构建移动端 Drawer
  Widget _buildDrawer(BuildContext context, List<_SettingsSection> sections) {
    final theme = Theme.of(context);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.settings,
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.settings_title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: sections.length,
                itemBuilder: (context, index) {
                  final section = sections[index];
                  final isSelected = _selectedIndex == index;

                  return ListTile(
                    leading: Icon(
                      isSelected ? section.selectedIcon : section.icon,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    title: Text(
                      section.label,
                      style: TextStyle(
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedTileColor: theme.colorScheme.primaryContainer
                        .withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    onTap: () {
                      _onSectionSelected(index);
                      Navigator.of(context).pop();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
