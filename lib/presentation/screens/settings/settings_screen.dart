import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../adaptive/window_size_class.dart';
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
  const SettingsScreen({super.key, this.initialSectionIndex = 0});

  final int initialSectionIndex;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late int _selectedIndex;
  final _contentScrollController = ScrollController();
  bool _isContentScrolled = false;
  bool _showCompactDetail = false;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialSectionIndex.clamp(0, 8);
    _showCompactDetail = widget.initialSectionIndex != 0;
    _contentScrollController.addListener(_onContentScroll);
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSectionIndex != widget.initialSectionIndex) {
      _selectedIndex = widget.initialSectionIndex.clamp(0, 8);
      _showCompactDetail = widget.initialSectionIndex != 0;
    }
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

  void _onSectionSelected(int index, {bool showCompactDetail = false}) {
    setState(() {
      _selectedIndex = index;
      _showCompactDetail = showCompactDetail;
      if (_contentScrollController.hasClients) {
        _contentScrollController.jumpTo(0);
      }
      _isContentScrolled = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sections = _buildSections(context);
    final selectedIndex = _selectedIndex.clamp(0, sections.length - 1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final sizeClass = WindowSizeClass.fromWidth(constraints.maxWidth);
        if (sizeClass.isCompact) {
          return _buildCompactSettings(context, theme, sections, selectedIndex);
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.settings_title),
            backgroundColor: _isContentScrolled
                ? theme.colorScheme.surfaceContainerHighest
                : null,
            surfaceTintColor: Colors.transparent,
          ),
          body: Row(
            children: [
              _buildNavigationRail(context, sizeClass.isExpanded, sections),
              const VerticalDivider(thickness: 1, width: 1),
              Expanded(
                child: _buildSectionContent(
                  sections[selectedIndex].widget,
                  padding: const EdgeInsets.all(24),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _returnToCompactSettingsList() {
    if (!_showCompactDetail) return;
    setState(() {
      _showCompactDetail = false;
      _isContentScrolled = false;
    });
  }

  Widget _buildCompactSettings(
    BuildContext context,
    ThemeData theme,
    List<_SettingsSection> sections,
    int selectedIndex,
  ) {
    return PopScope<void>(
      canPop: !_showCompactDetail,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _returnToCompactSettingsList();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: _showCompactDetail
              ? BackButton(onPressed: _returnToCompactSettingsList)
              : null,
          title: Text(
            _showCompactDetail
                ? sections[selectedIndex].label
                : context.l10n.settings_title,
          ),
          backgroundColor: _isContentScrolled
              ? theme.colorScheme.surfaceContainerHighest
              : null,
          surfaceTintColor: Colors.transparent,
        ),
        body: AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: _showCompactDetail
              ? KeyedSubtree(
                  key: ValueKey('settings-detail-$selectedIndex'),
                  child: _buildSectionContent(
                    sections[selectedIndex].widget,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  ),
                )
              : ListView.separated(
                  key: const ValueKey('settings-section-list'),
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  itemCount: sections.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final section = sections[index];
                    return ListTile(
                      minTileHeight: 56,
                      leading: Icon(section.icon),
                      title: Text(section.label),
                      trailing: const Icon(Icons.chevron_right),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onTap: () =>
                          _onSectionSelected(index, showCompactDetail: true),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildSectionContent(Widget section, {required EdgeInsets padding}) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        controller: _contentScrollController,
        padding: padding,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight,
            maxWidth: 900,
          ),
          child: Align(alignment: Alignment.topCenter, child: section),
        ),
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
      // 必须从 textTheme 派生：NavigationRail 对这两项是整体替换而非合并，
      // 传裸 TextStyle 会把默认的 labelMedium 连同用户字体一起顶掉。
      selectedLabelTextStyle: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.primary,
        fontWeight: FontWeight.w600,
      ),
      unselectedIconTheme: IconThemeData(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
      ),
      unselectedLabelTextStyle: theme.textTheme.labelMedium?.copyWith(
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
}
