import 'package:collection/collection.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../adaptive/adaptive_presenter.dart';
import '../../../adaptive/content_sized_adaptive_form.dart';
import '../../../providers/random_preset_provider.dart';
import '../../../providers/tag_library_provider.dart';
import '../../../themes/core/layered_surface_style.dart';
import '../../common/ink_host.dart';
import '../../common/themed_slider.dart';
import '../../common/translated_tag_text.dart';
import '../../../../data/models/prompt/diy_category_references.dart';
import '../../../../data/models/prompt/random_category.dart';
import '../../../../data/models/prompt/random_tag_group.dart';
import '../../../../data/models/prompt/tag_category.dart';
import '../diy/diy_category_field.dart';
import '../diy/panels/conditional_branch_panel.dart';
import '../diy/panels/dependency_config_panel.dart';
import '../diy/panels/visibility_rule_panel.dart';
import '../diy/panels/time_condition_panel.dart';
import '../diy/panels/post_process_rule_panel.dart';
import 'probability_text.dart';
import 'random_config_l10n.dart';

/// 词组卡片组件
///
/// 显示词组信息，包括名称、概率、标签数量和 DIY 能力图标
class TagGroupCard extends ConsumerStatefulWidget {
  const TagGroupCard({
    super.key,
    required this.tagGroup,
    required this.categoryId,
    required this.categoryKey,
    required this.presetId,
    this.isPresetDefault = false,
    this.onTap,
    this.dragHandle,
  });

  final RandomTagGroup tagGroup;
  final String categoryId;
  final String categoryKey;
  final String presetId;
  final bool isPresetDefault;
  final VoidCallback? onTap;
  final Widget? dragHandle;

  @override
  ConsumerState<TagGroupCard> createState() => _TagGroupCardState();
}

class _TagGroupCardState extends ConsumerState<TagGroupCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final tagGroup = widget.tagGroup;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final tagCount = ref.watch(groupTagCountProvider(tagGroup));

    return Tooltip(
      message: _buildTagPreview(l10n, tagGroup),
      waitDuration: const Duration(milliseconds: 500),
      preferBelow: false,
      child: Opacity(
        opacity: tagGroup.enabled ? 1 : 0.55,
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: reduceMotion
                ? Duration.zero
                : const Duration(milliseconds: 120),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: _isHovered
                  ? Color.alphaBlend(
                      colors.onSurface.withValues(alpha: 0.035),
                      controlSurfaceColor(colors),
                    )
                  : controlSurfaceColor(colors),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onTap ?? () => _showEditDialog(context),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 54),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 7, 4, 7),
                    child: Row(
                      children: [
                        if (widget.dragHandle != null)
                          IconTheme(
                            data: IconThemeData(
                              size: 18,
                              color: colors.onSurfaceVariant,
                            ),
                            child: SizedBox(
                              width: 28,
                              height: 40,
                              child: Center(child: widget.dragHandle),
                            ),
                          )
                        else
                          Icon(
                            _sourceIcon(tagGroup.sourceType),
                            size: 18,
                            color: colors.onSurfaceVariant,
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.randomTagGroupName(tagGroup),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$tagCount · ${formatProbabilityPercent(tagGroup.probability)}',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        ..._buildCapabilityIndicators(tagGroup, colors),
                        Switch(
                          value: tagGroup.enabled,
                          onChanged: widget.isPresetDefault
                              ? null
                              : (_) => ref
                                    .read(randomPresetNotifierProvider.notifier)
                                    .toggleGroupEnabled(
                                      widget.categoryKey,
                                      tagGroup.id,
                                    ),
                        ),
                        PopupMenuButton<_TagGroupAction>(
                          tooltip: l10n.randomManager_moreActions,
                          onSelected: (action) {
                            if (action == _TagGroupAction.edit) {
                              _showEditDialog(context);
                            } else {
                              _deleteGroup(context);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: _TagGroupAction.edit,
                              child: ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.tune_rounded),
                                title: Text(l10n.common_edit),
                              ),
                            ),
                            if (!widget.isPresetDefault)
                              PopupMenuItem(
                                value: _TagGroupAction.delete,
                                child: ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(
                                    Icons.delete_outline_rounded,
                                    color: colors.error,
                                  ),
                                  title: Text(
                                    l10n.common_delete,
                                    style: TextStyle(color: colors.error),
                                  ),
                                ),
                              ),
                          ],
                          icon: const Icon(Icons.more_horiz_rounded, size: 19),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCapabilityIndicators(
    RandomTagGroup group,
    ColorScheme colors,
  ) {
    final indicators = <IconData>[
      if (group.hasConditionalBranch) Icons.call_split_rounded,
      if (group.hasDependency) Icons.link_rounded,
      if (group.hasVisibilityRules) Icons.visibility_outlined,
      if (group.hasTimeCondition) Icons.schedule_rounded,
      if (group.hasPostProcessRules) Icons.auto_fix_high_outlined,
      if (group.emphasisProbability > 0) Icons.bolt_outlined,
    ];
    return indicators
        .take(3)
        .map(
          (icon) => Padding(
            padding: const EdgeInsets.only(left: 5),
            child: Icon(icon, size: 15, color: colors.secondary),
          ),
        )
        .toList(growable: false);
  }

  IconData _sourceIcon(TagGroupSourceType type) {
    return switch (type) {
      TagGroupSourceType.builtin => Icons.inventory_2_outlined,
      TagGroupSourceType.custom => Icons.edit_note_rounded,
      TagGroupSourceType.tagGroup => Icons.cloud_sync_outlined,
      TagGroupSourceType.pool => Icons.collections_outlined,
    };
  }

  Future<void> _deleteGroup(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(context.l10n.randomManager_deleteTagGroupTitle),
        content: Text(
          context.l10n.randomManager_deleteTagGroupConfirm(
            context.l10n.randomTagGroupName(widget.tagGroup),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.l10n.common_delete),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(randomPresetNotifierProvider.notifier)
        .removeGroupFromCategory(widget.categoryKey, widget.tagGroup.id);
  }

  /// 构建标签预览文本
  String _buildTagPreview(AppLocalizations l10n, RandomTagGroup tagGroup) {
    Iterable<String> tags;
    var count = 0;

    if (tagGroup.sourceType == TagGroupSourceType.builtin) {
      final library = ref.read(tagLibraryNotifierProvider).library;
      final sourceId = tagGroup.sourceId;
      final category = sourceId == null
          ? null
          : TagSubCategory.values.cast<TagSubCategory?>().firstWhere(
              (item) => item?.name == sourceId,
              orElse: () => null,
            );
      final entries = category == null || library == null
          ? null
          : library.getCategory(category);
      count = entries?.length ?? 0;
      tags = entries?.take(10).map((item) => item.tag) ?? const [];
    } else {
      count = tagGroup.tags.length;
      tags = tagGroup.tags.take(10).map((item) => item.tag);
    }

    if (count == 0) return l10n.naiMode_noTags;
    final preview = tags.join(', ');
    if (count > 10) {
      return '$preview … (${l10n.tagGroup_tagCount(count.toString())})';
    }
    return preview;
  }

  void _showEditDialog(BuildContext context, {int initialTabIndex = 0}) {
    AdaptivePresenter.showForm<void>(
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
                      panelContext.l10n.randomTagGroupName(widget.tagGroup),
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
      builder: (panelContext, scrollController) => _TagGroupEditDialog(
        tagGroup: widget.tagGroup,
        categoryId: widget.categoryId,
        presetId: widget.presetId,
        scrollController: scrollController,
        isPresetDefault: widget.isPresetDefault,
        initialTabIndex: initialTabIndex,
      ),
    );
  }
}

enum _TagGroupAction { edit, delete }

/// 词组编辑对话框
class _TagGroupEditDialog extends ConsumerStatefulWidget {
  const _TagGroupEditDialog({
    required this.tagGroup,
    required this.categoryId,
    required this.presetId,
    required this.scrollController,
    this.isPresetDefault = false,
    this.initialTabIndex = 0,
  });

  final RandomTagGroup tagGroup;
  final String categoryId;
  final String presetId;
  final ScrollController scrollController;
  final bool isPresetDefault;
  final int initialTabIndex;

  @override
  ConsumerState<_TagGroupEditDialog> createState() =>
      _TagGroupEditDialogState();
}

class _TagGroupEditDialogState extends ConsumerState<_TagGroupEditDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _nameController;
  late RandomTagGroup _editingTagGroup;

  List<RandomCategory> get _presetCategories {
    final state = ref.read(randomPresetNotifierProvider);
    final preset = state.presets.firstWhereOrNull(
      (p) => p.id == widget.presetId,
    );
    return preset?.categories ?? const [];
  }

  /// DIY 规则按类别 ID 引用，界面显示本地化名称；重名时附上键名区分
  List<DiyCategoryOption> get _categoryOptions {
    final l10n = AppLocalizations.of(context)!;
    final categories = <String, RandomCategory>{
      for (final category in _presetCategories)
        if (category.id.isNotEmpty) category.id: category,
    }.values.toList();
    final labels = categories.map(l10n.randomCategoryName).toList();
    return [
      for (var i = 0; i < categories.length; i++)
        DiyCategoryOption(
          id: categories[i].id,
          key: categories[i].key,
          label: labels.where((label) => label == labels[i]).length > 1
              ? '${labels[i]} (${categories[i].key})'
              : labels[i],
        ),
    ];
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _nameController = TextEditingController(text: widget.tagGroup.name);
    // 存量规则可能按类别名称或键名引用，打开时统一换成 ID，保存后生成器才能匹配
    final resolver = DiyCategoryReferenceResolver(_presetCategories);
    _editingTagGroup = widget.tagGroup.mapCategoryReferences(
      resolver.canonicalId,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  // 低于此高度时标签栏与操作栏随正文滚动，否则两者固定后正文视口不足以编辑
  static const double _minBodyHeightForFixedChrome = 320;

  // 标签栏与操作栏在固定和随正文滚动之间切换时保留焦点
  final _tabBarKey = GlobalKey();
  final _actionsKey = GlobalKey();

  double _swipeDistance = 0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final tagCount = ref.watch(groupTagCountProvider(_editingTagGroup));
    final tagList = _watchTagList();
    final tabBar = _buildTabBar(context, tagCount: tagCount);
    final actions = _buildActions(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final chromeScrolls =
            constraints.maxHeight < _minBodyHeightForFixedChrome;
        // 两种排布下标签栏都是首个 sliver，正文滚动偏移与输入状态不因切换而变
        return Column(
          children: [
            Expanded(
              child: Padding(
                padding: chromeScrolls
                    ? const EdgeInsets.fromLTRB(16, 8, 16, 8)
                    : const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
                      builder: (context, _) => RawGestureDetector(
                        gestures: _tabSwipeGestures(
                          context,
                          constraints.maxWidth,
                        ),
                        child: CustomScrollView(
                          key: const ValueKey('tag-group-editor-scroll'),
                          controller: widget.scrollController,
                          slivers: [
                            if (chromeScrolls)
                              SliverToBoxAdapter(child: tabBar)
                            else
                              PinnedHeaderSliver(child: tabBar),
                            KeyedSubtree(
                              key: ValueKey(
                                'tag-group-editor-tab-${_tabController.index}',
                              ),
                              child: _buildTabContent(
                                context,
                                tagCount: tagCount,
                                tagList: tagList,
                                fillViewport: !chromeScrolls,
                              ),
                            ),
                            if (chromeScrolls)
                              SliverToBoxAdapter(child: actions),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (!chromeScrolls) actions,
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
      // 固定时正文从标签栏下方滚过，需要不透明底色遮住
      child: ColoredBox(
        color: sectionSurfaceColor(Theme.of(context).colorScheme),
        child: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          onTap: (_) => _scrollToContentStart(),
          tabs: [
            editorTab(Icons.tune_rounded, l10n.randomManager_basicTab),
            editorTab(
              Icons.sell_outlined,
              l10n.randomManager_tagsTab(tagCount),
            ),
            editorTab(
              Icons.account_tree_outlined,
              l10n.randomManager_diyAbilitiesTab,
            ),
          ],
        ),
      ),
    );
  }

  // 各标签共用同一个滚动视图，切换后从新内容的开头显示
  void _scrollToContentStart() {
    final controller = widget.scrollController;
    if (controller.hasClients) controller.jumpTo(0);
  }

  // 沿用滚动配置的拖动设备与速度追踪，横滑切页的触发条件与原 TabBarView 一致
  Map<Type, GestureRecognizerFactory> _tabSwipeGestures(
    BuildContext context,
    double width,
  ) {
    final scrollConfiguration = ScrollConfiguration.of(context);
    return {
      _TabSwipeGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<_TabSwipeGestureRecognizer>(
            () => _TabSwipeGestureRecognizer(
              startsOnChrome: _startsOnChrome,
              supportedDevices: scrollConfiguration.dragDevices,
            ),
            (instance) => instance
              ..velocityTrackerBuilder = scrollConfiguration
                  .velocityTrackerBuilder(context)
              ..gestureSettings = MediaQuery.gestureSettingsOf(context)
              ..supportedDevices = scrollConfiguration.dragDevices
              ..onStart = _startTabSwipe
              ..onUpdate = _updateTabSwipe
              ..onEnd = (details) => _finishTabSwipe(details, width),
          ),
    };
  }

  void _startTabSwipe(DragStartDetails details) => _swipeDistance = 0;

  void _updateTabSwipe(DragUpdateDetails details) =>
      _swipeDistance += details.primaryDelta ?? 0;

  bool _startsOnChrome(Offset position) => [_tabBarKey, _actionsKey].any((key) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return false;
    return (Offset.zero & box.size).contains(box.globalToLocal(position));
  });

  // 甩动按速度方向切页；慢速拖动需越过正文一半宽度，与 PageView 的吸附规则相同
  void _finishTabSwipe(DragEndDetails details, double width) {
    final velocity = details.primaryVelocity ?? 0;
    final movement = velocity != 0
        ? velocity
        : _swipeDistance.abs() > width / 2
        ? _swipeDistance
        : 0.0;
    if (movement == 0) return;
    final ltr = Directionality.of(context) == TextDirection.ltr;
    final target = _tabController.index + ((movement < 0) == ltr ? 1 : -1);
    if (target < 0 || target >= _tabController.length) return;
    _tabController.animateTo(target);
    _scrollToContentStart();
  }

  Widget _buildTabContent(
    BuildContext context, {
    required int tagCount,
    required List<String> tagList,
    required bool fillViewport,
  }) {
    return switch (_tabController.index) {
      0 => SliverToBoxAdapter(child: _buildBasicTab(context)),
      1 => _buildTagsTab(context, tagCount: tagCount, tagList: tagList),
      // 锁定说明只在操作栏固定时居中撑满；随正文滚动时撑满会把关闭按钮推出视口
      _ when widget.isPresetDefault && fillViewport => SliverFillRemaining(
        hasScrollBody: false,
        child: _buildDiyTab(context),
      ),
      _ => SliverToBoxAdapter(child: _buildDiyTab(context)),
    };
  }

  Widget _buildActions(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return KeyedSubtree(
      key: _actionsKey,
      child: SafeArea(
        top: false,
        child: Container(
          color: sectionSurfaceColor(Theme.of(context).colorScheme),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  widget.isPresetDefault
                      ? l10n.common_close
                      : l10n.common_cancel,
                ),
              ),
              if (!widget.isPresetDefault)
                FilledButton.icon(
                  onPressed: _saveChanges,
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text(l10n.common_save),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicTab(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isReadOnly = widget.isPresetDefault;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 名称
          TextField(
            controller: _nameController,
            enabled: !isReadOnly,
            decoration: InputDecoration(
              labelText: l10n.randomManager_tagGroupName,
              suffixIcon: isReadOnly
                  ? Icon(
                      Icons.lock_outline,
                      color: colorScheme.outline,
                      size: 18,
                    )
                  : null,
            ),
            onChanged: isReadOnly
                ? null
                : (value) {
                    setState(() {
                      _editingTagGroup = _editingTagGroup.copyWith(name: value);
                    });
                  },
          ),
          const SizedBox(height: 16),
          // 概率
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  constraints.maxWidth < 420 ||
                  MediaQuery.textScalerOf(context).scale(1) >= 2;
              final label = Text(
                '${l10n.randomManager_probability}:',
                style: theme.textTheme.bodyMedium,
              );
              final slider = Opacity(
                opacity: isReadOnly ? 0.6 : 1.0,
                child: NamedSlider(
                  label: l10n.randomManager_probability,
                  valueText: formatProbabilityPercent,
                  value: _editingTagGroup.probability,
                  min: 0,
                  max: 1,
                  divisions: 20,
                  onChanged: isReadOnly
                      ? null
                      : (value) {
                          setState(() {
                            _editingTagGroup = _editingTagGroup.copyWith(
                              probability: value,
                            );
                          });
                        },
                ),
              );
              final value = Text(
                formatProbabilityPercent(_editingTagGroup.probability),
                textAlign: TextAlign.right,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              );
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    label,
                    Row(
                      children: [
                        Expanded(child: slider),
                        value,
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  label,
                  const SizedBox(width: 16),
                  Expanded(child: slider),
                  SizedBox(width: 48, child: value),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          // 选择模式
          LayoutBuilder(
            builder: (context, constraints) {
              final label = Text(
                '${l10n.randomManager_selectionMode}:',
                style: theme.textTheme.bodyMedium,
              );
              final selector = DropdownButton<SelectionMode>(
                value: _editingTagGroup.selectionMode,
                isExpanded: true,
                items: SelectionMode.values.map((mode) {
                  final (label, desc) = switch (mode) {
                    SelectionMode.single => (
                      l10n.randomManager_selectionSingle,
                      l10n.randomManager_selectionSingleDesc,
                    ),
                    SelectionMode.all => (
                      l10n.randomManager_selectionAll,
                      l10n.randomManager_selectionAllDesc,
                    ),
                    SelectionMode.multipleNum => (
                      l10n.randomManager_selectionMultipleCount,
                      l10n.randomManager_selectionMultipleCountDesc,
                    ),
                    SelectionMode.multipleProb => (
                      l10n.randomManager_selectionMultipleProbability,
                      l10n.randomManager_selectionMultipleProbabilityDesc,
                    ),
                    SelectionMode.sequential => (
                      l10n.randomManager_selectionSequential,
                      l10n.randomManager_selectionSequentialDesc,
                    ),
                  };
                  return DropdownMenuItem(
                    value: mode,
                    child: Text('$label - $desc'),
                  );
                }).toList(),
                onChanged: isReadOnly
                    ? null
                    : (mode) {
                        if (mode != null) {
                          setState(() {
                            _editingTagGroup = _editingTagGroup.copyWith(
                              selectionMode: mode,
                            );
                          });
                        }
                      },
              );
              if (constraints.maxWidth < 420 ||
                  MediaQuery.textScalerOf(context).scale(1) >= 2) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [label, const SizedBox(height: 8), selector],
                );
              }
              return Row(
                children: [
                  label,
                  const SizedBox(width: 16),
                  Expanded(child: selector),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  List<String> _watchTagList() {
    if (_editingTagGroup.sourceType != TagGroupSourceType.builtin) {
      // 其他类型：使用 tags 字段的标签名
      return _editingTagGroup.tags.map((t) => t.tag).toList();
    }
    // 内置词库类型：从 TagLibrary 获取
    final libraryState = ref.watch(tagLibraryNotifierProvider);
    if (libraryState.library == null || _editingTagGroup.sourceId == null) {
      return const [];
    }
    final category = TagSubCategory.values.cast<TagSubCategory?>().firstWhere(
      (c) => c?.name == _editingTagGroup.sourceId,
      orElse: () => null,
    );
    if (category == null) return const [];
    return libraryState.library!
        .getCategory(category)
        .map((t) => t.tag)
        .toList();
  }

  /// 构建标签列表Tab
  Widget _buildTagsTab(
    BuildContext context, {
    required int tagCount,
    required List<String> tagList,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: SliverMainAxisGroup(
        slivers: [
          // 标签列表标题
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                l10n.randomManager_tagsTab(tagCount),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // 内置词库的标签可达数千条，按需构建
          DecoratedSliver(
            decoration: BoxDecoration(
              color: controlSurfaceColor(colorScheme),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            sliver: SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: tagList.isEmpty
                  ? SliverToBoxAdapter(
                      child: Center(
                        child: Text(
                          l10n.randomManager_noTags,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    )
                  : SliverList.builder(
                      itemCount: tagList.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: TranslatedTagText(
                          tagList[index],
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiyTab(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    // 默认预设不支持 DIY 配置
    if (widget.isPresetDefault) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline, size: 48, color: colorScheme.outline),
              const SizedBox(height: 16),
              Text(
                l10n.diyNotAvailableForDefault,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.diyNotAvailableHint,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 条件分支
          _DiySection(
            icon: Icons.call_split,
            title: l10n.randomManager_conditionalBranch,
            description: l10n.randomManager_conditionalBranchDesc,
            enabled: _editingTagGroup.hasConditionalBranch,
            onAdd: () => _showConditionalBranchDialog(),
            onEdit: _editingTagGroup.hasConditionalBranch
                ? () => _showConditionalBranchDialog()
                : null,
          ),
          const SizedBox(height: 12),
          // 依赖配置
          _DiySection(
            icon: Icons.link,
            title: l10n.randomManager_dependencyConfig,
            description: l10n.randomManager_dependencyConfigDesc,
            enabled: _editingTagGroup.hasDependency,
            onAdd: () => _showDependencyConfigDialog(),
            onEdit: _editingTagGroup.hasDependency
                ? () => _showDependencyConfigDialog()
                : null,
          ),
          const SizedBox(height: 12),
          // 可见性规则
          _DiySection(
            icon: Icons.visibility,
            title: l10n.randomManager_visibilityRules,
            description: l10n.randomManager_visibilityRulesDesc,
            enabled: _editingTagGroup.hasVisibilityRules,
            onAdd: () => _showVisibilityRuleDialog(),
            onEdit: _editingTagGroup.hasVisibilityRules
                ? () => _showVisibilityRuleDialog()
                : null,
          ),
          const SizedBox(height: 12),
          // 时间条件
          _DiySection(
            icon: Icons.calendar_today,
            title: l10n.randomManager_timeCondition,
            description: l10n.randomManager_timeConditionDesc,
            enabled: _editingTagGroup.hasTimeCondition,
            onAdd: () => _showTimeConditionDialog(),
            onEdit: _editingTagGroup.hasTimeCondition
                ? () => _showTimeConditionDialog()
                : null,
          ),
          const SizedBox(height: 12),
          // 后处理规则
          _DiySection(
            icon: Icons.build,
            title: l10n.randomManager_postProcessRules,
            description: l10n.randomManager_postProcessRulesDesc,
            enabled: _editingTagGroup.hasPostProcessRules,
            onAdd: () => _showPostProcessRuleDialog(),
            onEdit: _editingTagGroup.hasPostProcessRules
                ? () => _showPostProcessRuleDialog()
                : null,
          ),
          const SizedBox(height: 16),
          // 强调概率
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: controlSurfaceColor(colorScheme),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final label = Text(
                  '${l10n.randomManager_emphasisProbability}:',
                  style: theme.textTheme.bodyMedium,
                );
                final slider = SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 4,
                    activeTrackColor: colorScheme.tertiary,
                    inactiveTrackColor: colorScheme.tertiaryContainer
                        .withValues(alpha: 0.3),
                    thumbColor: colorScheme.tertiary,
                    overlayColor: colorScheme.tertiary.withValues(alpha: 0.1),
                  ),
                  child: NamedSlider(
                    label: l10n.randomManager_emphasisProbability,
                    valueText: formatProbabilityPercent,
                    value: _editingTagGroup.emphasisProbability,
                    min: 0,
                    max: 0.1,
                    divisions: 10,
                    onChanged: (value) {
                      setState(() {
                        _editingTagGroup = _editingTagGroup.copyWith(
                          emphasisProbability: value,
                        );
                      });
                    },
                  ),
                );
                final value = Text(
                  formatProbabilityPercent(
                    _editingTagGroup.emphasisProbability,
                  ),
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.tertiary,
                  ),
                );
                if (constraints.maxWidth < 420 ||
                    MediaQuery.textScalerOf(context).scale(1) >= 2) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      label,
                      Row(
                        children: [
                          Expanded(child: slider),
                          value,
                        ],
                      ),
                    ],
                  );
                }
                return Row(
                  children: [
                    Icon(Icons.bolt, size: 18, color: colorScheme.tertiary),
                    const SizedBox(width: 12),
                    label,
                    const SizedBox(width: 16),
                    Expanded(child: slider),
                    SizedBox(width: 48, child: value),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 显示条件分支编辑面板
  void _showConditionalBranchDialog() {
    _showDiyConfigForm(
      title: AppLocalizations.of(context)!.randomManager_conditionalBranch,
      child: ConditionalBranchPanel(
        config: _editingTagGroup.conditionalBranchConfig,
        onConfigChanged: (config) {
          setState(() {
            _editingTagGroup = _editingTagGroup.copyWith(
              conditionalBranchConfig: config,
            );
          });
        },
      ),
    );
  }

  /// 显示依赖配置编辑面板
  void _showDependencyConfigDialog() {
    _showDiyConfigForm(
      title: AppLocalizations.of(context)!.randomManager_dependencyConfig,
      child: DependencyConfigPanel(
        config: _editingTagGroup.dependencyConfig,
        onConfigChanged: (config) {
          setState(() {
            _editingTagGroup = _editingTagGroup.copyWith(
              dependencyConfig: config,
            );
          });
        },
        categoryOptions: _categoryOptions,
      ),
    );
  }

  /// 显示可见性规则编辑面板
  void _showVisibilityRuleDialog() {
    _showDiyConfigForm(
      title: AppLocalizations.of(context)!.randomManager_visibilityRules,
      child: VisibilityRulePanel(
        rules: _editingTagGroup.visibilityRules,
        onRulesChanged: (rules) {
          setState(() {
            _editingTagGroup = _editingTagGroup.copyWith(
              visibilityRules: rules,
            );
          });
        },
        categoryOptions: _categoryOptions,
        ownerGroupId: _editingTagGroup.id,
      ),
    );
  }

  /// 显示时间条件编辑面板
  void _showTimeConditionDialog() {
    _showDiyConfigForm(
      title: AppLocalizations.of(context)!.randomManager_timeCondition,
      child: TimeConditionPanel(
        condition: _editingTagGroup.timeCondition,
        onConditionChanged: (condition) {
          setState(() {
            _editingTagGroup = _editingTagGroup.copyWith(
              timeCondition: condition,
            );
          });
        },
      ),
    );
  }

  /// 显示后处理规则编辑面板
  void _showPostProcessRuleDialog() {
    _showDiyConfigForm(
      title: AppLocalizations.of(context)!.randomManager_postProcessRules,
      child: PostProcessRulePanel(
        rules: _editingTagGroup.postProcessRules,
        onRulesChanged: (rules) {
          setState(() {
            _editingTagGroup = _editingTagGroup.copyWith(
              postProcessRules: rules,
            );
          });
        },
        categoryOptions: _categoryOptions,
      ),
    );
  }

  Future<void> _showDiyConfigForm({
    required String title,
    required Widget child,
  }) {
    return AdaptivePresenter.showForm<void>(
      context: context,
      dialogWidth: 620,
      titleBuilder: (panelContext) => Row(
        children: [
          Icon(
            Icons.auto_awesome,
            color: Theme.of(panelContext).colorScheme.secondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          // 面板内首行标题会完整换行显示同一名称，这里单行以把高度留给正文
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
          child,
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

/// 从标签栏或操作栏开始的横滑不切换标签页，与它们位于原 TabBarView 之外时一致
class _TabSwipeGestureRecognizer extends HorizontalDragGestureRecognizer {
  _TabSwipeGestureRecognizer({
    required this.startsOnChrome,
    super.supportedDevices,
  });

  final bool Function(Offset position) startsOnChrome;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      !startsOnChrome(event.position) && super.isPointerAllowed(event);

  @override
  bool isPointerPanZoomAllowed(PointerPanZoomStartEvent event) =>
      !startsOnChrome(event.position) && super.isPointerPanZoomAllowed(event);
}

class _DiySection extends StatefulWidget {
  const _DiySection({
    required this.icon,
    required this.title,
    required this.description,
    required this.enabled,
    required this.onAdd,
    this.onEdit,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool enabled;
  final VoidCallback onAdd;
  final VoidCallback? onEdit;

  @override
  State<_DiySection> createState() => _DiySectionState();
}

class _DiySectionState extends State<_DiySection> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.enabled
              ? colorScheme.primaryContainer.withValues(alpha: 0.3)
              : _isHovered
              ? colorScheme.surfaceContainerHighest
              : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: widget.enabled
                  ? colorScheme.primary.withValues(alpha: 0.15)
                  : colorScheme.shadow.withValues(alpha: 0.05),
              blurRadius: widget.enabled ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stackContent =
                constraints.maxWidth < 420 ||
                MediaQuery.textScalerOf(context).scale(1) >= 2;
            final icon = Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.enabled
                    ? colorScheme.primary.withValues(alpha: 0.15)
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                widget.icon,
                size: 20,
                color: widget.enabled
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
            );
            final description = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: widget.enabled
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            );
            final action = FilledButton.tonal(
              key: ValueKey('tag-group-diy-action-${widget.title}'),
              onPressed: widget.enabled ? widget.onEdit : widget.onAdd,
              child: Text(
                widget.enabled
                    ? AppLocalizations.of(context)!.common_edit
                    : AppLocalizations.of(context)!.common_add,
              ),
            );

            if (stackContent) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      icon,
                      const SizedBox(width: 12),
                      Expanded(child: description),
                    ],
                  ),
                  const SizedBox(height: 12),
                  action,
                ],
              );
            }
            return Row(
              children: [
                icon,
                const SizedBox(width: 12),
                Expanded(child: description),
                if (widget.enabled) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check, color: colorScheme.primary, size: 20),
                ],
                if (!widget.enabled || widget.onEdit != null) ...[
                  const SizedBox(width: 8),
                  action,
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
