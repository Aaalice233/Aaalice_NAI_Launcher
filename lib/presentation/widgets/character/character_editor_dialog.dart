import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../common/themed_divider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/character/character_prompt.dart';
import '../../providers/character_prompt_provider.dart';
import '../common/themed_switch.dart';
import 'character_detail_panel.dart';
import 'character_list_panel.dart';

/// 角色编辑器对话框组件
///
/// 用于编辑多人角色的模态对话框，采用双栏布局：
/// - 左侧：角色列表面板
/// - 右侧：角色详情编辑面板
///
/// 支持响应式布局：
/// - 桌面端：并排双栏布局 (800x600)
/// - 移动端：单列视图，通过标签页切换
///
/// Requirements: 6.1, 6.2, 6.3, 6.4
class CharacterEditorDialog extends ConsumerStatefulWidget {
  const CharacterEditorDialog({super.key});

  /// 显示角色编辑器对话框
  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const CharacterEditorDialog(),
    );
  }

  @override
  ConsumerState<CharacterEditorDialog> createState() =>
      _CharacterEditorDialogState();
}

class _CharacterEditorDialogState extends ConsumerState<CharacterEditorDialog>
    with SingleTickerProviderStateMixin {
  String? _selectedCharacterId;
  late TabController _tabController;

  // 响应式布局断点
  static const double _desktopBreakpoint = 600;
  static const double _desktopDialogWidth = 840;
  static const double _desktopDialogHeight = 600;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // 初始化时选中第一个角色
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final characters = ref.read(characterListProvider);
      if (characters.isNotEmpty && _selectedCharacterId == null) {
        setState(() {
          _selectedCharacterId = characters.first.id;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onCharacterSelected(String? id) {
    setState(() {
      _selectedCharacterId = id;
    });
    // 移动端：选择角色后切换到详情标签页
    if (_tabController.length == 2 && id != null) {
      _tabController.animateTo(1);
    }
  }

  void _onCharacterUpdated(CharacterPrompt character) {
    ref
        .read(characterPromptNotifierProvider.notifier)
        .updateCharacter(character);
  }

  void _onGlobalAiChoiceChanged(bool value) {
    ref.read(characterPromptNotifierProvider.notifier).setGlobalAiChoice(value);
  }

  Future<void> _onClearAll() async {
    final confirmed = await _showClearAllConfirmDialog();
    if (confirmed == true) {
      ref.read(characterPromptNotifierProvider.notifier).clearAllCharacters();
      setState(() {
        _selectedCharacterId = null;
      });
    }
  }

  Future<bool?> _showClearAllConfirmDialog() {
    final l10n = AppLocalizations.of(context)!;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.characterEditor_clearAllTitle),
        content: Text(l10n.characterEditor_clearAllConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.common_clear),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= _desktopBreakpoint;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: isDesktop
          ? _buildDesktopLayout(context)
          : _buildMobileLayout(context),
    );
  }

  /// 桌面端布局：并排双栏
  Widget _buildDesktopLayout(BuildContext context) {
    final config = ref.watch(characterPromptNotifierProvider);
    final selectedCharacter = _selectedCharacterId != null
        ? config.findCharacterById(_selectedCharacterId!)
        : null;

    return SizedBox(
      width: _desktopDialogWidth,
      height: _desktopDialogHeight,
      child: Column(
        children: [
          // 对话框头部
          _DialogHeader(onClose: () => Navigator.of(context).pop()),

          // 主体内容：双栏布局
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 左侧：角色列表
                SizedBox(
                  width: 280,
                  child: _ListPanelContainer(
                    selectedCharacterId: _selectedCharacterId,
                    onCharacterSelected: _onCharacterSelected,
                    globalAiChoice: config.globalAiChoice,
                    onGlobalAiChoiceChanged: _onGlobalAiChoiceChanged,
                  ),
                ),

                // 分隔线
                const ThemedDivider(height: 1, vertical: true),

                // 右侧：角色详情
                Expanded(
                  child: selectedCharacter != null
                      ? CharacterDetailPanel(
                          character: selectedCharacter,
                          onCharacterUpdated: _onCharacterUpdated,
                          globalAiChoice: config.globalAiChoice,
                        )
                      : const _EmptyDetailState(),
                ),
              ],
            ),
          ),

          // 对话框底部
          _DialogFooter(
            hasCharacters: config.characters.isNotEmpty,
            onClearAll: _onClearAll,
            onConfirm: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  /// 移动端布局：标签页切换
  Widget _buildMobileLayout(BuildContext context) {
    final config = ref.watch(characterPromptNotifierProvider);
    final selectedCharacter = _selectedCharacterId != null
        ? config.findCharacterById(_selectedCharacterId!)
        : null;

    return SizedBox(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.9,
      child: Column(
        children: [
          // 对话框头部（带标签栏）
          _MobileDialogHeader(
            tabController: _tabController,
            onClose: () => Navigator.of(context).pop(),
          ),

          // 主体内容：标签页视图
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 角色列表标签页
                _ListPanelContainer(
                  selectedCharacterId: _selectedCharacterId,
                  onCharacterSelected: _onCharacterSelected,
                  globalAiChoice: config.globalAiChoice,
                  onGlobalAiChoiceChanged: _onGlobalAiChoiceChanged,
                ),

                // 角色详情标签页
                selectedCharacter != null
                    ? CharacterDetailPanel(
                        character: selectedCharacter,
                        onCharacterUpdated: _onCharacterUpdated,
                        globalAiChoice: config.globalAiChoice,
                      )
                    : const _EmptyDetailState(),
              ],
            ),
          ),

          // 对话框底部
          _DialogFooter(
            hasCharacters: config.characters.isNotEmpty,
            onClearAll: _onClearAll,
            onConfirm: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

/// 对话框头部组件（桌面端）
class _DialogHeader extends StatelessWidget {
  final VoidCallback onClose;

  const _DialogHeader({required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.people,
            size: 24,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Text(
            l10n.characterEditor_title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close),
            tooltip: l10n.characterEditor_close,
            style: IconButton.styleFrom(
              foregroundColor: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 移动端对话框头部组件（带标签栏）
class _MobileDialogHeader extends StatelessWidget {
  final TabController tabController;
  final VoidCallback onClose;

  const _MobileDialogHeader({
    required this.tabController,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题行
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              children: [
                Icon(
                  Icons.people,
                  size: 24,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.characterEditor_title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                  tooltip: l10n.characterEditor_close,
                  style: IconButton.styleFrom(
                    foregroundColor: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // 标签栏
          TabBar(
            controller: tabController,
            tabs: [
              Tab(text: l10n.characterEditor_tabList),
              Tab(text: l10n.characterEditor_tabDetail),
            ],
            labelColor: colorScheme.primary,
            unselectedLabelColor: colorScheme.onSurfaceVariant,
            indicatorColor: colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

/// 角色列表面板容器（包含全局AI选择复选框）
class _ListPanelContainer extends ConsumerWidget {
  final String? selectedCharacterId;
  final ValueChanged<String?>? onCharacterSelected;
  final bool globalAiChoice;
  final ValueChanged<bool> onGlobalAiChoiceChanged;

  const _ListPanelContainer({
    this.selectedCharacterId,
    this.onCharacterSelected,
    required this.globalAiChoice,
    required this.onGlobalAiChoiceChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        // 角色列表
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: CharacterListPanel(
              selectedCharacterId: selectedCharacterId,
              onCharacterSelected: onCharacterSelected,
              globalAiChoice: globalAiChoice,
            ),
          ),
        ),

        // 全局AI选择开关
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: colorScheme.outlineVariant.withOpacity(0.3),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => onGlobalAiChoiceChanged(!globalAiChoice),
                  child: Text(
                    l10n.characterEditor_globalAiChoice,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              Tooltip(
                message: l10n.characterEditor_globalAiChoiceHint,
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: colorScheme.onSurfaceVariant.withOpacity(0.6),
                ),
              ),
              const SizedBox(width: 8),
              ThemedSwitch(
                value: globalAiChoice,
                onChanged: onGlobalAiChoiceChanged,
                scale: 0.85,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 空详情状态提示
class _EmptyDetailState extends StatelessWidget {
  const _EmptyDetailState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_outline,
            size: 64,
            color: colorScheme.onSurface.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.characterEditor_emptyTitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.characterEditor_emptyHint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// 对话框底部组件
class _DialogFooter extends StatelessWidget {
  final bool hasCharacters;
  final VoidCallback onClearAll;
  final VoidCallback onConfirm;

  const _DialogFooter({
    required this.hasCharacters,
    required this.onClearAll,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // 清空所有按钮
          if (hasCharacters)
            TextButton.icon(
              onPressed: onClearAll,
              icon: Icon(
                Icons.delete_sweep,
                size: 18,
                color: colorScheme.error,
              ),
              label: Text(
                l10n.characterEditor_clearAll,
                style: TextStyle(color: colorScheme.error),
              ),
            ),

          const Spacer(),

          // 确定按钮
          FilledButton(
            onPressed: onConfirm,
            child: Text(l10n.characterEditor_confirm),
          ),
        ],
      ),
    );
  }
}
