import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../adaptive/adaptive_chrome_placement.dart';
import '../../../adaptive/adaptive_form_footer.dart';
import '../../../adaptive/adaptive_pinned_header_sliver.dart';
import '../../../adaptive/adaptive_presenter.dart';
import '../../../adaptive/content_sized_adaptive_form.dart';
import '../../../providers/random_preset_provider.dart';
import '../../../themes/core/layered_surface_style.dart';
import '../../common/ink_host.dart';
import '../../common/tab_swipe_detector.dart';
import '../../../../data/models/prompt/diy_category_references.dart';
import '../../../../data/models/prompt/random_category.dart';
import '../../../../data/models/prompt/random_tag_group.dart';
import '../diy/panels/conditional_branch_panel.dart';
import '../diy/panels/dependency_config_panel.dart';
import '../diy/panels/visibility_rule_panel.dart';
import '../diy/panels/time_condition_panel.dart';
import '../diy/panels/post_process_rule_panel.dart';
import 'random_config_l10n.dart';
import 'tag_group_basic_tab.dart';
import 'tag_group_diy_options.dart';
import 'tag_group_diy_tab.dart';
import 'tag_group_tags_sliver.dart';

/// 词组编辑面板：基础设置、标签列表与 DIY 能力三个标签页
class TagGroupEditDialog extends ConsumerStatefulWidget {
  const TagGroupEditDialog({
    super.key,
    required this.tagGroup,
    required this.categoryId,
    required this.presetId,
    required this.scrollController,
    this.isPresetDefault = false,
    this.initialTabIndex = 0,
    this.initialBranchIndex,
  });

  final RandomTagGroup tagGroup;
  final String categoryId;
  final String presetId;
  final ScrollController scrollController;
  final bool isPresetDefault;
  final int initialTabIndex;

  /// 打开后直接进入 DIY 页编辑该分支
  final int? initialBranchIndex;

  static Future<void> show(
    BuildContext context, {
    required RandomTagGroup tagGroup,
    required String categoryId,
    required String presetId,
    bool isPresetDefault = false,
    int initialTabIndex = 0,
    int? initialBranchIndex,
  }) {
    return AdaptivePresenter.showForm<void>(
      context: context,
      dialogWidth: 640,
      titleBuilder: (panelContext) {
        final compactTitle =
            MediaQuery.textScalerOf(panelContext).scale(1) >= 2;
        return Row(
          children: [
            Icon(
              Icons.tune_rounded,
              size: 20,
              color: Theme.of(panelContext).colorScheme.primary,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    panelContext.l10n.randomManager_editTagGroup,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(panelContext).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (!compactTitle)
                    Text(
                      panelContext.l10n.randomTagGroupName(tagGroup),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(panelContext).textTheme.bodySmall
                          ?.copyWith(
                            color: Theme.of(
                              panelContext,
                            ).colorScheme.onSurfaceVariant,
                          ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
      builder: (panelContext, scrollController) => TagGroupEditDialog(
        tagGroup: tagGroup,
        categoryId: categoryId,
        presetId: presetId,
        scrollController: scrollController,
        isPresetDefault: isPresetDefault,
        initialTabIndex: initialTabIndex,
        initialBranchIndex: initialBranchIndex,
      ),
    );
  }

  @override
  ConsumerState<TagGroupEditDialog> createState() => _TagGroupEditDialogState();
}

class _TagGroupEditDialogState extends ConsumerState<TagGroupEditDialog>
    with SingleTickerProviderStateMixin {
  static const _diyTabIndex = 2;

  late TabController _tabController;
  late TextEditingController _nameController;
  late RandomTagGroup _editingTagGroup;

  // 操作栏在固定与随正文滚动之间移动时保留焦点；两者也是横滑切页的排除区域
  final _tabBarKey = GlobalKey();
  final _actionsKey = GlobalKey();

  List<RandomCategory> get _presetCategories {
    final state = ref.read(randomPresetNotifierProvider);
    final preset = state.presets.firstWhereOrNull(
      (p) => p.id == widget.presetId,
    );
    return preset?.categories ?? const [];
  }

  TagGroupDiyOptions get _diyOptions => TagGroupDiyOptions(
    l10n: AppLocalizations.of(context)!,
    presetCategories: _presetCategories,
    categoryId: widget.categoryId,
    editingGroup: _editingTagGroup,
  );

  @override
  void initState() {
    super.initState();
    final initialBranchIndex = widget.initialBranchIndex;
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: initialBranchIndex == null
          ? widget.initialTabIndex
          : _diyTabIndex,
    );
    _nameController = TextEditingController(text: widget.tagGroup.name);
    // 存量规则与分支条件可能按名称或键名引用，打开时统一换成 ID，与生成时的解析一致
    final resolver = DiyCategoryReferenceResolver(_presetCategories);
    _editingTagGroup = widget.tagGroup.canonicalizeReferences(resolver);
    if (initialBranchIndex != null && !widget.isPresetDefault) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openDiyForm(
            TagGroupDiyAbility.conditionalBranch,
            initialBranchIndex: initialBranchIndex,
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  void _setGroup(RandomTagGroup group) =>
      setState(() => _editingTagGroup = group);

  static const _fixedActionsPadding = EdgeInsets.fromLTRB(16, 12, 16, 16);
  static const _scrollingActionsPadding = EdgeInsets.fromLTRB(16, 8, 16, 8);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tagCount = ref.watch(groupTagCountProvider(_editingTagGroup));
    final tabBar = _buildTabBar(context, tagCount: tagCount);
    final actions = _buildActions(context);
    return AdaptiveChromePlacementBuilder(
      reservedExtent: _fixedActionsPadding.vertical,
      builder: (context, placement, probes) {
        final footer = probes.footer(actions);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: TabSwipeDetector(
                controller: _tabController,
                excludedRegions: [_tabBarKey, _actionsKey],
                onSwitched: _scrollToContentStart,
                child: Padding(
                  padding: placement.footerFixed
                      ? _fixedActionsPadding
                      : _scrollingActionsPadding,
                  child: Container(
                    key: const ValueKey('tag-group-editor-surface'),
                    decoration: BoxDecoration(
                      color: sectionSurfaceColor(colorScheme),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkHost(
                      child: ListenableBuilder(
                        listenable: _tabController,
                        builder: (context, _) => CustomScrollView(
                          key: const ValueKey('tag-group-editor-scroll'),
                          controller: widget.scrollController,
                          slivers: [
                            AdaptivePinnedHeaderSliver(
                              // 滚动时外边距收窄，标签栏仍按固定操作栏时的边距判断，与操作栏同进退
                              trailingExtent: placement.footerFixed
                                  ? 0
                                  : placement.footerExtent +
                                        _fixedActionsPadding.vertical -
                                        _scrollingActionsPadding.vertical,
                              backgroundColor: sectionSurfaceColor(colorScheme),
                              child: probes.header(tabBar),
                            ),
                            KeyedSubtree(
                              key: ValueKey(
                                'tag-group-editor-tab-${_tabController.index}',
                              ),
                              child: _buildTabContent(
                                tagCount: tagCount,
                                fillViewport: placement.footerFixed,
                              ),
                            ),
                            if (!placement.footerFixed)
                              SliverToBoxAdapter(child: footer),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (placement.footerFixed) footer,
          ],
        );
      },
    );
  }

  Widget _buildTabBar(BuildContext context, {required int tagCount}) {
    final l10n = AppLocalizations.of(context)!;
    final compactTabs = MediaQuery.textScalerOf(context).scale(1) >= 2;

    Widget editorTab(IconData icon, String label) {
      if (compactTabs) {
        return Tab(
          icon: Tooltip(
            message: label,
            child: Icon(icon, size: 20, semanticLabel: label),
          ),
        );
      }
      return Tab(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 17),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      );
    }

    return KeyedSubtree(
      key: _tabBarKey,
      child: TabBar(
        controller: _tabController,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        onTap: (_) => _scrollToContentStart(),
        tabs: [
          editorTab(Icons.tune_rounded, l10n.randomManager_basicTab),
          editorTab(Icons.sell_outlined, l10n.randomManager_tagsTab(tagCount)),
          editorTab(
            Icons.account_tree_outlined,
            l10n.randomManager_diyAbilitiesTab,
          ),
        ],
      ),
    );
  }

  // 各标签共用同一个滚动视图，切换后从新内容的开头显示
  void _scrollToContentStart() {
    final controller = widget.scrollController;
    if (controller.hasClients) controller.jumpTo(0);
  }

  Widget _buildTabContent({required int tagCount, required bool fillViewport}) {
    final readOnly = widget.isPresetDefault;
    return switch (_tabController.index) {
      0 => SliverToBoxAdapter(
        child: TagGroupBasicTab(
          group: _editingTagGroup,
          nameController: _nameController,
          readOnly: readOnly,
          onChanged: _setGroup,
        ),
      ),
      1 => TagGroupTagsSliver(group: _editingTagGroup, tagCount: tagCount),
      // 锁定说明只在操作栏固定时居中撑满；随正文滚动时撑满会把关闭按钮推出视口
      _ when readOnly && fillViewport => SliverFillRemaining(
        hasScrollBody: false,
        child: _buildDiyTab(),
      ),
      _ => SliverToBoxAdapter(child: _buildDiyTab()),
    };
  }

  Widget _buildDiyTab() => TagGroupDiyTab(
    group: _editingTagGroup,
    readOnly: widget.isPresetDefault,
    onOpen: _openDiyForm,
    onChanged: _setGroup,
  );

  Widget _buildActions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return KeyedSubtree(
      key: _actionsKey,
      child: AdaptiveFormFooter(
        cancelLabel: widget.isPresetDefault
            ? l10n.common_close
            : l10n.common_cancel,
        primary: widget.isPresetDefault
            ? null
            : FilledButton.icon(
                onPressed: _saveChanges,
                icon: const Icon(Icons.check_rounded, size: 18),
                label: Text(l10n.common_save),
              ),
      ),
    );
  }

  void _openDiyForm(TagGroupDiyAbility ability, {int? initialBranchIndex}) {
    final title = ability.title(AppLocalizations.of(context)!);
    final panel = _buildDiyPanel(
      ability,
      initialBranchIndex: initialBranchIndex,
    );
    AdaptivePresenter.showForm<void>(
      context: context,
      dialogWidth: 620,
      headerScrollsWithContent: true,
      titleBuilder: (panelContext) => Row(
        children: [
          Icon(
            ability.icon,
            color: Theme.of(panelContext).colorScheme.secondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          // 单行显示，矮视口叠加放大文字时把高度留给正文
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                panelContext,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      // 确认随正文滚动：短横屏叠加软键盘时固定页脚会把正文挤到零高度
      builder: (panelContext, scrollController) => ContentSizedAdaptiveForm(
        scrollController: scrollController,
        content: [
          panel,
          const SizedBox(height: 16),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.icon(
              key: const ValueKey('tag-group-diy-form-confirm'),
              onPressed: () => Navigator.pop(panelContext),
              icon: const Icon(Icons.check, size: 18),
              label: Text(panelContext.l10n.common_confirm),
            ),
          ),
        ],
      ),
    );
  }

  // 弹出的表单路由不随本面板重建，回调按当时最新的词组合并修改
  Widget _buildDiyPanel(TagGroupDiyAbility ability, {int? initialBranchIndex}) {
    final options = _diyOptions;
    final group = _editingTagGroup;
    return switch (ability) {
      TagGroupDiyAbility.conditionalBranch => ConditionalBranchPanel(
        config: group.conditionalBranchConfig,
        onConfigChanged: (config) => _setGroup(
          _editingTagGroup.copyWith(conditionalBranchConfig: config),
        ),
        targetOptions: options.branchTargetOptions,
        cyclicTargetIds: options.cyclicBranchTargetIds,
        conditionSources: options.branchConditionSources,
        initialSelectedIndex: initialBranchIndex,
      ),
      TagGroupDiyAbility.dependency => DependencyConfigPanel(
        config: group.dependencyConfig,
        onConfigChanged: (config) =>
            _setGroup(_editingTagGroup.copyWith(dependencyConfig: config)),
        categoryOptions: options.categoryOptions,
        selectionMode: group.selectionMode,
      ),
      TagGroupDiyAbility.visibility => VisibilityRulePanel(
        rules: group.visibilityRules,
        onRulesChanged: (rules) =>
            _setGroup(_editingTagGroup.copyWith(visibilityRules: rules)),
        categoryOptions: options.categoryOptions,
        ownerGroupId: group.id,
      ),
      TagGroupDiyAbility.time => TimeConditionPanel(
        condition: group.timeCondition,
        onConditionChanged: (condition) =>
            _setGroup(_editingTagGroup.copyWith(timeCondition: condition)),
      ),
      TagGroupDiyAbility.postProcess => PostProcessRulePanel(
        rules: group.postProcessRules,
        onRulesChanged: (rules) =>
            _setGroup(_editingTagGroup.copyWith(postProcessRules: rules)),
        categoryOptions: options.categoryOptions,
        categoryResolver: options.categoryResolver,
      ),
    };
  }

  void _saveChanges() {
    final notifier = ref.read(randomPresetNotifierProvider.notifier);
    final state = ref.read(randomPresetNotifierProvider);
    final preset = state.presets.firstWhere((p) => p.id == widget.presetId);
    final category = preset.categories.firstWhere(
      (c) => c.id == widget.categoryId,
    );
    final updatedCategory = category.updateGroup(_editingTagGroup);
    notifier.updateCategory(updatedCategory);
    Navigator.pop(context);
  }
}
