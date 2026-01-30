import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/random_preset_provider.dart';
import '../../../providers/tag_library_provider.dart';
import '../../../../data/models/prompt/random_tag_group.dart';
import '../../../../data/models/prompt/tag_category.dart';
import '../diy/panels/conditional_branch_panel.dart';
import '../diy/panels/dependency_config_panel.dart';
import '../diy/panels/visibility_rule_panel.dart';
import '../diy/panels/time_condition_panel.dart';
import '../diy/panels/post_process_rule_panel.dart';
import '../../common/elevated_card.dart';
import 'random_manager_widgets.dart';

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
  });

  final RandomTagGroup tagGroup;
  final String categoryId;
  final String categoryKey;
  final String presetId;
  final bool isPresetDefault;
  final VoidCallback? onTap;

  @override
  ConsumerState<TagGroupCard> createState() => _TagGroupCardState();
}

class _TagGroupCardState extends ConsumerState<TagGroupCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tagGroup = widget.tagGroup;
    final hasDiyAbility = tagGroup.hasConditionalBranch ||
        tagGroup.hasDependency ||
        tagGroup.hasVisibilityRules ||
        tagGroup.hasTimeCondition ||
        tagGroup.hasPostProcessRules ||
        tagGroup.emphasisProbability > 0;

    // 获取标签预览内容
    final tooltipText = _buildTagPreview(tagGroup);

    return Tooltip(
      message: tooltipText,
      waitDuration: const Duration(milliseconds: 500),
      preferBelow: false,
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap ?? () => _showEditDialog(context),
          child: Opacity(
            opacity: tagGroup.enabled ? 1.0 : 0.5,
            child: ElevatedCard(
              elevation: CardElevation.level1,
              hoverElevation: CardElevation.level2,
              enableHoverEffect: false, // 外层 MouseRegion 已处理
              borderRadius: 8,
              gradientBorder: tagGroup.enabled && _isHovered && hasDiyAbility
                  ? CardGradients.primary(colorScheme)
                  : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: 135,
                padding: const EdgeInsets.all(12),
                transform: Matrix4.identity()
                  ..translate(0.0, _isHovered ? -2.0 : 0.0),
                transformAlignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _isHovered
                      ? colorScheme.surfaceContainerHighest
                      : colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: _isHovered
                      ? [
                          BoxShadow(
                            color: colorScheme.primary.withOpacity(0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 第一行：emoji + 名称 + 开关
                    Row(
                      children: [
                        if (tagGroup.emoji.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color:
                                  colorScheme.primaryContainer.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tagGroup.emoji,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        if (tagGroup.emoji.isNotEmpty) const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            tagGroup.name,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              decoration: tagGroup.enabled
                                  ? null
                                  : TextDecoration.lineThrough,
                              color: tagGroup.enabled
                                  ? null
                                  : colorScheme.onSurfaceVariant,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        // 启用开关（移到右侧）
                        SizedBox(
                          width: 28,
                          height: 20,
                          child: Transform.scale(
                            scale: 0.6,
                            child: Switch(
                              value: tagGroup.enabled,
                              onChanged: widget.isPresetDefault
                                  ? null
                                  : (value) {
                                      ref
                                          .read(
                                            randomPresetNotifierProvider
                                                .notifier,
                                          )
                                          .toggleGroupEnabled(
                                            widget.categoryKey,
                                            tagGroup.id,
                                          );
                                    },
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 第二行：概率进度条 + 百分比
                    ProbabilityBar(
                      probability: tagGroup.probability,
                      isHovered: _isHovered,
                      height: 4.0,
                      useBadgeStyle: false,
                    ),
                    const SizedBox(height: 6),
                    // 第三行：标签数量 + DIY 图标
                    Row(
                      children: [
                        Icon(
                          Icons.label_outline,
                          size: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${ref.watch(groupTagCountProvider(tagGroup))}',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        // DIY 能力图标
                        ..._buildDiyIcons(tagGroup),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 构建标签预览文本
  String _buildTagPreview(RandomTagGroup tagGroup) {
    List<String> tags = [];

    if (tagGroup.sourceType == TagGroupSourceType.builtin) {
      // 内置词库类型：从 TagLibrary 获取
      final libraryState = ref.read(tagLibraryNotifierProvider);
      if (libraryState.library != null && tagGroup.sourceId != null) {
        final category =
            TagSubCategory.values.cast<TagSubCategory?>().firstWhere(
                  (c) => c?.name == tagGroup.sourceId,
                  orElse: () => null,
                );
        if (category != null) {
          tags = libraryState.library!
              .getCategory(category)
              .map((t) => t.tag)
              .toList();
        }
      }
    } else {
      // 其他类型：使用 tags 字段
      tags = tagGroup.tags.map((t) => t.tag).toList();
    }

    if (tags.isEmpty) return '暂无标签';

    // 显示前10个标签
    const maxShow = 10;
    final preview = tags.take(maxShow).join(', ');
    if (tags.length > maxShow) {
      return '$preview ... (共${tags.length}个)';
    }
    return preview;
  }

  List<Widget> _buildDiyIcons(RandomTagGroup tagGroup) {
    final icons = <Widget>[];

    if (tagGroup.hasConditionalBranch) {
      icons.add(
        _DiyIcon(
          icon: Icons.call_split,
          tooltip: '条件分支 (点击编辑)',
          onTap: () => _openDiyPanel(context, 'conditionalBranch'),
        ),
      );
    }
    if (tagGroup.hasDependency) {
      icons.add(
        _DiyIcon(
          icon: Icons.link,
          tooltip: '依赖配置 (点击编辑)',
          onTap: () => _openDiyPanel(context, 'dependency'),
        ),
      );
    }
    if (tagGroup.hasVisibilityRules) {
      icons.add(
        _DiyIcon(
          icon: Icons.visibility,
          tooltip: '可见性规则 (点击编辑)',
          onTap: () => _openDiyPanel(context, 'visibility'),
        ),
      );
    }
    if (tagGroup.hasTimeCondition) {
      icons.add(
        _DiyIcon(
          icon: Icons.calendar_today,
          tooltip: '时间条件 (点击编辑)',
          onTap: () => _openDiyPanel(context, 'timeCondition'),
        ),
      );
    }
    if (tagGroup.hasPostProcessRules) {
      icons.add(
        _DiyIcon(
          icon: Icons.build,
          tooltip: '后处理规则 (点击编辑)',
          onTap: () => _openDiyPanel(context, 'postProcess'),
        ),
      );
    }
    if (tagGroup.emphasisProbability > 0) {
      icons.add(
        _DiyIcon(
          icon: Icons.bolt,
          tooltip:
              '强调概率: ${(tagGroup.emphasisProbability * 100).toStringAsFixed(0)}%',
          onTap: () => _showEditDialog(context), // 强调概率在主编辑对话框中
        ),
      );
    }

    return icons;
  }

  void _openDiyPanel(BuildContext context, String panelType) {
    // 所有 DIY 功能都在编辑对话框的第二个选项卡 (index=1)
    _showEditDialog(context, initialTabIndex: 1);
  }

  void _showEditDialog(BuildContext context, {int initialTabIndex = 0}) {
    showDialog(
      context: context,
      builder: (context) => _TagGroupEditDialog(
        tagGroup: widget.tagGroup,
        categoryId: widget.categoryId,
        presetId: widget.presetId,
        isPresetDefault: widget.isPresetDefault,
        initialTabIndex: initialTabIndex,
      ),
    );
  }
}

class _DiyIcon extends StatefulWidget {
  const _DiyIcon({
    required this.icon,
    required this.tooltip,
    this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  State<_DiyIcon> createState() => _DiyIconState();
}

class _DiyIconState extends State<_DiyIcon> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Tooltip(
          message: widget.tooltip,
          child: Padding(
            padding: const EdgeInsets.only(left: 3),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: _isHovered
                    ? colorScheme.primary.withOpacity(0.25)
                    : colorScheme.secondaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(3),
                boxShadow: _isHovered
                    ? [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.2),
                          blurRadius: 4,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                widget.icon,
                size: 11,
                color: _isHovered ? colorScheme.primary : colorScheme.secondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 词组编辑对话框
class _TagGroupEditDialog extends ConsumerStatefulWidget {
  const _TagGroupEditDialog({
    required this.tagGroup,
    required this.categoryId,
    required this.presetId,
    this.isPresetDefault = false,
    this.initialTabIndex = 0,
  });

  final RandomTagGroup tagGroup;
  final String categoryId;
  final String presetId;
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

  /// 获取当前预设的类别名称列表
  List<String> get _availableCategories {
    final state = ref.read(randomPresetNotifierProvider);
    final preset =
        state.presets.firstWhereOrNull((p) => p.id == widget.presetId);
    if (preset == null) return [];
    return preset.categories.map((c) => c.name).toList();
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
    _editingTagGroup = widget.tagGroup;
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 620,
        height: 620,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: colorScheme.shadow.withOpacity(0.16),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          children: [
            // 标题栏 - 渐变背景
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primaryContainer.withOpacity(0.3),
                    colorScheme.secondaryContainer.withOpacity(0.2),
                  ],
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(8)),
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.outlineVariant.withOpacity(0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.edit_note,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '编辑词组',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    iconSize: 20,
                    style: IconButton.styleFrom(
                      backgroundColor:
                          colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            // 标签页
            TabBar(
              controller: _tabController,
              tabs: [
                const Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.list_alt, size: 16),
                      SizedBox(width: 6),
                      Text('基础'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.label_outline, size: 16),
                      const SizedBox(width: 6),
                      Text(
                          '标签 (${ref.watch(groupTagCountProvider(_editingTagGroup))})'),
                    ],
                  ),
                ),
                const Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome, size: 16),
                      SizedBox(width: 6),
                      Text('DIY 能力'),
                    ],
                  ),
                ),
              ],
            ),
            // 内容
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBasicTab(context),
                  _buildTagsTab(context),
                  _buildDiyTab(context),
                ],
              ),
            ),
            // 底部按钮
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(8)),
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outlineVariant.withOpacity(0.2),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(widget.isPresetDefault ? '关闭' : '取消'),
                  ),
                  if (!widget.isPresetDefault) ...[
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: _saveChanges,
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('保存'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicTab(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isReadOnly = widget.isPresetDefault;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 名称
          TextField(
            controller: _nameController,
            enabled: !isReadOnly,
            decoration: InputDecoration(
              labelText: '名称',
              border: const OutlineInputBorder(),
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
          Row(
            children: [
              Text(
                '概率:',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Opacity(
                  opacity: isReadOnly ? 0.6 : 1.0,
                  child: Slider(
                    value: _editingTagGroup.probability,
                    min: 0,
                    max: 1,
                    divisions: 20,
                    label: '${(_editingTagGroup.probability * 100).toInt()}%',
                    onChanged: isReadOnly
                        ? null
                        : (value) {
                            setState(() {
                              _editingTagGroup =
                                  _editingTagGroup.copyWith(probability: value);
                            });
                          },
                  ),
                ),
              ),
              SizedBox(
                width: 48,
                child: Text(
                  '${(_editingTagGroup.probability * 100).toInt()}%',
                  textAlign: TextAlign.right,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 选择模式
          Row(
            children: [
              Text(
                '选择模式:',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButton<SelectionMode>(
                  value: _editingTagGroup.selectionMode,
                  isExpanded: true,
                  items: SelectionMode.values.map((mode) {
                    final (label, desc) = switch (mode) {
                      SelectionMode.single => ('单选', '加权随机选择一个'),
                      SelectionMode.all => ('全选', '选择所有标签'),
                      SelectionMode.multipleNum => ('多选数量', '选择指定数量'),
                      SelectionMode.multipleProb => ('多选概率', '每个独立判断'),
                      SelectionMode.sequential => ('顺序轮替', '跨批次保持状态'),
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
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建标签列表Tab
  Widget _buildTagsTab(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tagCount = ref.watch(groupTagCountProvider(_editingTagGroup));

    // 获取标签列表
    List<String> tagList = [];

    if (_editingTagGroup.sourceType == TagGroupSourceType.builtin) {
      // 内置词库类型：从 TagLibrary 获取
      final libraryState = ref.watch(tagLibraryNotifierProvider);
      if (libraryState.library != null && _editingTagGroup.sourceId != null) {
        final category =
            TagSubCategory.values.cast<TagSubCategory?>().firstWhere(
                  (c) => c?.name == _editingTagGroup.sourceId,
                  orElse: () => null,
                );
        if (category != null) {
          tagList = libraryState.library!
              .getCategory(category)
              .map((t) => t.tag)
              .toList();
        }
      }
    } else {
      // 其他类型：使用 tags 字段的标签名
      tagList = _editingTagGroup.tags.map((t) => t.tag).toList();
    }

    final isEmpty = tagList.isEmpty;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标签列表标题
          Text(
            '标签列表 ($tagCount 个)',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          // 标签列表容器
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: isEmpty
                  ? Center(
                      child: Text(
                        '暂无标签',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: tagList.length,
                      itemBuilder: (context, index) {
                        final tag = tagList[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            tag,
                            style: theme.textTheme.bodyMedium,
                          ),
                        );
                      },
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 48,
              color: colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.diyNotAvailableForDefault,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.diyNotAvailableHint,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.outline,
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 条件分支
          _DiySection(
            icon: Icons.call_split,
            title: '条件分支',
            description: '根据变量值选择不同的标签子集',
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
            title: '依赖配置',
            description: '选择数量依赖其他类别的值',
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
            title: '可见性规则',
            description: '根据构图决定是否生成',
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
            title: '时间条件',
            description: '特定日期范围启用',
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
            title: '后处理规则',
            description: '根据已选标签移除冲突',
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
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.bolt,
                    size: 18,
                    color: colorScheme.tertiary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '强调概率:',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      activeTrackColor: colorScheme.tertiary,
                      inactiveTrackColor:
                          colorScheme.tertiaryContainer.withOpacity(0.3),
                      thumbColor: colorScheme.tertiary,
                      overlayColor: colorScheme.tertiary.withOpacity(0.1),
                    ),
                    child: Slider(
                      value: _editingTagGroup.emphasisProbability,
                      min: 0,
                      max: 0.1,
                      divisions: 10,
                      label:
                          '${(_editingTagGroup.emphasisProbability * 100).toInt()}%',
                      onChanged: (value) {
                        setState(() {
                          _editingTagGroup = _editingTagGroup.copyWith(
                            emphasisProbability: value,
                          );
                        });
                      },
                    ),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${(_editingTagGroup.emphasisProbability * 100).toInt()}%',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.tertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 显示条件分支编辑对话框
  void _showConditionalBranchDialog() {
    showDialog(
      context: context,
      builder: (context) => _DiyConfigDialog(
        title: '条件分支配置',
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
      ),
    );
  }

  /// 显示依赖配置编辑对话框
  void _showDependencyConfigDialog() {
    showDialog(
      context: context,
      builder: (context) => _DiyConfigDialog(
        title: '依赖配置',
        child: DependencyConfigPanel(
          config: _editingTagGroup.dependencyConfig,
          onConfigChanged: (config) {
            setState(() {
              _editingTagGroup = _editingTagGroup.copyWith(
                dependencyConfig: config,
              );
            });
          },
          availableCategories: _availableCategories,
        ),
      ),
    );
  }

  /// 显示可见性规则编辑对话框
  void _showVisibilityRuleDialog() {
    showDialog(
      context: context,
      builder: (context) => _DiyConfigDialog(
        title: '可见性规则',
        child: VisibilityRulePanel(
          rules: _editingTagGroup.visibilityRules,
          onRulesChanged: (rules) {
            setState(() {
              _editingTagGroup = _editingTagGroup.copyWith(
                visibilityRules: rules,
              );
            });
          },
          availableCategories: _availableCategories,
        ),
      ),
    );
  }

  /// 显示时间条件编辑对话框
  void _showTimeConditionDialog() {
    showDialog(
      context: context,
      builder: (context) => _DiyConfigDialog(
        title: '时间条件',
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
      ),
    );
  }

  /// 显示后处理规则编辑对话框
  void _showPostProcessRuleDialog() {
    showDialog(
      context: context,
      builder: (context) => _DiyConfigDialog(
        title: '后处理规则',
        child: PostProcessRulePanel(
          rules: _editingTagGroup.postProcessRules,
          onRulesChanged: (rules) {
            setState(() {
              _editingTagGroup = _editingTagGroup.copyWith(
                postProcessRules: rules,
              );
            });
          },
          availableCategories: _availableCategories,
        ),
      ),
    );
  }

  void _saveChanges() {
    final notifier = ref.read(randomPresetNotifierProvider.notifier);
    final state = ref.read(randomPresetNotifierProvider);
    final preset = state.presets.firstWhere((p) => p.id == widget.presetId);
    final category =
        preset.categories.firstWhere((c) => c.id == widget.categoryId);
    final updatedCategory = category.updateGroup(_editingTagGroup);
    notifier.updateCategory(updatedCategory);
    Navigator.pop(context);
  }
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
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.enabled
              ? colorScheme.primaryContainer.withOpacity(0.3)
              : _isHovered
                  ? colorScheme.surfaceContainerHighest
                  : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: widget.enabled
                  ? colorScheme.primary.withOpacity(0.15)
                  : colorScheme.shadow.withOpacity(0.05),
              blurRadius: widget.enabled ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.enabled
                    ? colorScheme.primary.withOpacity(0.15)
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
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
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
              ),
            ),
            if (widget.enabled)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check,
                      color: colorScheme.primary,
                      size: 16,
                    ),
                  ),
                  if (widget.onEdit != null) ...[
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: widget.onEdit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('编辑'),
                    ),
                  ],
                ],
              )
            else
              OutlinedButton(
                onPressed: widget.onAdd,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('添加'),
              ),
          ],
        ),
      ),
    );
  }
}

/// DIY 配置对话框
class _DiyConfigDialog extends StatelessWidget {
  const _DiyConfigDialog({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 620,
        height: 560,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: colorScheme.shadow.withOpacity(0.16),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          children: [
            // 标题栏 - 渐变背景
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.secondaryContainer.withOpacity(0.3),
                    colorScheme.tertiaryContainer.withOpacity(0.2),
                  ],
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(8)),
                border: Border(
                  bottom: BorderSide(
                    color: colorScheme.outlineVariant.withOpacity(0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colorScheme.secondary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      color: colorScheme.secondary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    iconSize: 20,
                    style: IconButton.styleFrom(
                      backgroundColor:
                          colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            // 内容
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: child,
              ),
            ),
            // 底部按钮
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(8)),
                border: Border(
                  top: BorderSide(
                    color: colorScheme.outlineVariant.withOpacity(0.2),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('确定'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
