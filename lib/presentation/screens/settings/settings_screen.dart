import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/localization_extension.dart';
import '../../adaptive/window_size_class.dart';
import '../../themes/core/layered_surface_style.dart';
import '../../widgets/common/owned_scroll_controller.dart';
import '../../widgets/common/themed_confirm_dialog.dart';
import '../cloud_sync/cloud_sync_screen.dart';
import 'sections/account_settings_section.dart';
import 'sections/appearance_settings_section.dart';
import 'sections/generation_settings_section.dart';
import 'sections/storage_settings_section.dart';
import 'sections/privacy_settings_section.dart';
import 'sections/network_settings_section.dart';
import 'sections/shortcut_settings_section.dart';
import 'sections/integrations_settings_section.dart';
import 'sections/about_settings_section.dart';
import 'sections/agent_settings_section.dart';
import '../../agent_settings/providers/agent_prompt_draft_provider.dart';
import 'settings_section.dart';

/// 设置页面 Section 数据模型
class _SettingsSection {
  final SettingsSection id;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget widget;

  const _SettingsSection({
    required this.id,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.widget,
  });
}

/// 设置页面 - 使用 NavigationRail 侧边栏导航布局
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({
    super.key,
    this.initialSection = SettingsSection.account,
  });

  final SettingsSection initialSection;

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late SettingsSection _selectedSection;
  final _contentScrollController = OwnedScrollController();
  bool _isContentScrolled = false;
  bool _showCompactDetail = false;
  int _externalSectionRevision = 0;
  Future<bool>? _discardConfirmation;

  @override
  void initState() {
    super.initState();
    _selectedSection = widget.initialSection;
    _showCompactDetail = widget.initialSection != SettingsSection.account;
    _contentScrollController.addListener(_onContentScroll);
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSection != widget.initialSection) {
      final section = widget.initialSection;
      final revision = ++_externalSectionRevision;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || revision != _externalSectionRevision) return;
        final changed = await _onSectionSelected(
          section,
          showCompactDetail: section != SettingsSection.account,
        );
        if (!changed) _restoreSelectedSectionInRoute();
      });
    }
  }

  List<_SettingsSection> _buildSections(BuildContext context) {
    return [
      _SettingsSection(
        id: SettingsSection.account,
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        label: context.l10n.settings_account,
        widget: const AccountSettingsSection(),
      ),
      _SettingsSection(
        id: SettingsSection.appearance,
        icon: Icons.palette_outlined,
        selectedIcon: Icons.palette,
        label: context.l10n.settings_appearance,
        widget: const AppearanceSettingsSection(),
      ),
      _SettingsSection(
        id: SettingsSection.generation,
        icon: Icons.tune_outlined,
        selectedIcon: Icons.tune,
        label: context.l10n.settings_generation,
        widget: const GenerationSettingsSection(),
      ),
      _SettingsSection(
        id: SettingsSection.agent,
        icon: Icons.smart_toy_outlined,
        selectedIcon: Icons.smart_toy,
        label: context.l10n.settings_agent,
        widget: const AgentSettingsSection(),
      ),
      _SettingsSection(
        id: SettingsSection.storage,
        icon: Icons.storage_outlined,
        selectedIcon: Icons.storage,
        label: context.l10n.settings_dataStorage,
        widget: const StorageSettingsSection(),
      ),
      _SettingsSection(
        id: SettingsSection.cloudSync,
        icon: Icons.cloud_sync_outlined,
        selectedIcon: Icons.cloud_sync,
        label: context.l10n.cloudSync_title,
        widget: const CloudSyncScreen(),
      ),
      _SettingsSection(
        id: SettingsSection.privacy,
        icon: Icons.shield_outlined,
        selectedIcon: Icons.shield,
        label: context.l10n.settings_privacySharing,
        widget: const PrivacySettingsSection(),
      ),
      _SettingsSection(
        id: SettingsSection.network,
        icon: Icons.network_check_outlined,
        selectedIcon: Icons.network_check,
        label: context.l10n.settings_network,
        widget: const NetworkSettingsSection(),
      ),
      _SettingsSection(
        id: SettingsSection.shortcuts,
        icon: Icons.keyboard_outlined,
        selectedIcon: Icons.keyboard,
        label: context.l10n.settings_shortcuts,
        widget: const ShortcutSettingsSection(),
      ),
      _SettingsSection(
        id: SettingsSection.integrations,
        icon: Icons.extension_outlined,
        selectedIcon: Icons.extension,
        label: context.l10n.settings_integrations,
        widget: const IntegrationsSettingsSection(),
      ),
      _SettingsSection(
        id: SettingsSection.about,
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

  Future<bool> _onSectionSelected(
    SettingsSection section, {
    bool showCompactDetail = false,
  }) async {
    if (section == _selectedSection) {
      if (showCompactDetail && !_showCompactDetail) {
        setState(() => _showCompactDetail = true);
      }
      return true;
    }
    if (!await _confirmDiscardAgentDraft()) return false;
    setState(() {
      _selectedSection = section;
      _showCompactDetail = showCompactDetail;
      _contentScrollController.viewport.replace(0);
      _contentScrollController.clearLayoutRestore();
      if (_contentScrollController.hasClients) {
        _contentScrollController.jumpTo(0);
      }
      _isContentScrolled = false;
    });
    return true;
  }

  void _restoreSelectedSectionInRoute() {
    final router = GoRouter.maybeOf(context);
    if (router == null) return;
    final uri = router.routeInformationProvider.value.uri;
    final queryParameters = Map<String, String>.from(uri.queryParameters)
      ..['section'] = _selectedSection.id;
    router.go(uri.replace(queryParameters: queryParameters).toString());
  }

  Future<bool> _confirmDiscardAgentDraft() async {
    if (_selectedSection != SettingsSection.agent ||
        !ref.read(agentPromptDraftProvider).dirty) {
      return true;
    }
    final existing = _discardConfirmation;
    if (existing != null) return existing;
    final confirmation = () async {
      final discard = await ThemedConfirmDialog.show(
        context: context,
        title: context.l10n.agentSettings_discardPromptTitle,
        content: context.l10n.agentSettings_discardPromptBody,
        confirmText: context.l10n.agentSettings_discardChanges,
        cancelText: context.l10n.agentSettings_keepEditing,
        type: ThemedConfirmDialogType.warning,
        icon: Icons.warning_amber_rounded,
      );
      if (discard) {
        ref.read(agentPromptDraftProvider.notifier).discard();
        return true;
      }
      return false;
    }();
    _discardConfirmation = confirmation;
    try {
      return await confirmation;
    } finally {
      if (identical(_discardConfirmation, confirmation)) {
        _discardConfirmation = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sections = _buildSections(context);
    final hasUnsavedAgentDraft =
        _selectedSection == SettingsSection.agent &&
        ref.watch(agentPromptDraftProvider.select((draft) => draft.dirty));
    final selectedIndex = sections.indexWhere(
      (item) => item.id == _selectedSection,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final sizeClass = WindowSizeClass.fromWidth(constraints.maxWidth);
        if (sizeClass.isCompact) {
          return _buildCompactSettings(context, theme, sections, selectedIndex);
        }

        return PopScope<void>(
          key: const ValueKey('settings-desktop-pop-scope'),
          canPop: !hasUnsavedAgentDraft,
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop || !await _confirmDiscardAgentDraft()) return;
            await WidgetsBinding.instance.endOfFrame;
            if (mounted) Navigator.of(this.context).maybePop();
          },
          child: Scaffold(
            appBar: _buildAppBar(context, theme),
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildNavigationRail(context, sizeClass.isWide, sections),
                Expanded(
                  child: _buildSectionContent(
                    sections[selectedIndex].widget,
                    padding: const EdgeInsets.all(24),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _returnToCompactSettingsList() async {
    if (!_showCompactDetail) return;
    if (!await _confirmDiscardAgentDraft()) return;
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
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _returnToCompactSettingsList();
      },
      child: Scaffold(
        appBar: _buildAppBar(
          context,
          theme,
          leading: _showCompactDetail
              ? BackButton(onPressed: _returnToCompactSettingsList)
              : null,
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
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final section = sections[index];
                    return ListTile(
                      minTileHeight: 56,
                      tileColor: sectionSurfaceColor(theme.colorScheme),
                      leading: Icon(section.icon),
                      title: Text(section.label),
                      trailing: const Icon(Icons.chevron_right),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      onTap: () => _onSectionSelected(
                        section.id,
                        showCompactDetail: true,
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  AppBar _buildAppBar(
    BuildContext context,
    ThemeData theme, {
    Widget? leading,
  }) {
    return AppBar(
      key: const ValueKey('settings-tonal-app-bar'),
      leading: leading,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.settings_outlined,
            size: 22,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Flexible(child: Text(context.l10n.settings_title)),
        ],
      ),
      backgroundColor: _isContentScrolled
          ? controlSurfaceColor(theme.colorScheme)
          : sectionSurfaceColor(theme.colorScheme),
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
    );
  }

  Widget _buildSectionContent(Widget section, {required EdgeInsets padding}) {
    return SafeArea(
      top: false,
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          key: const ValueKey('settings-section-scroll-view'),
          controller: _contentScrollController,
          padding: padding,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: constraints.maxWidth > 960 ? 960 : constraints.maxWidth,
              child: section,
            ),
          ),
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

    Widget buildRail() => NavigationRail(
      selectedIndex: sections.indexWhere((item) => item.id == _selectedSection),
      onDestinationSelected: (index) => _onSectionSelected(sections[index].id),
      extended: isExtended,
      minExtendedWidth: 180,
      backgroundColor: Colors.transparent,
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

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Container(
        key: const ValueKey('settings-navigation-tonal-surface'),
        decoration: BoxDecoration(
          color: sectionSurfaceColor(theme.colorScheme),
          borderRadius: BorderRadius.circular(10),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final contentHeight = sections.length * 56.0;
            final railHeight = constraints.maxHeight > contentHeight
                ? constraints.maxHeight
                : contentHeight;
            return SingleChildScrollView(
              child: SizedBox(height: railHeight, child: buildRail()),
            );
          },
        ),
      ),
    );
  }
}
