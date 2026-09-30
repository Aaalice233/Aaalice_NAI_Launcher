import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../providers/random_preset_provider.dart';
import '../../../providers/tag_library_provider.dart';
import '../../../themes/core/layered_surface_style.dart';
import '../../../../data/models/prompt/conditional_branch_targets.dart';
import '../../../../data/models/prompt/random_category.dart';
import '../../../../data/models/prompt/random_tag_group.dart';
import '../../../../data/models/prompt/tag_category.dart';
import 'branch_output_badge.dart';
import 'probability_text.dart';
import 'random_config_l10n.dart';
import 'tag_group_edit_dialog.dart';

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
    this.branchOutputBy = const [],
  });

  final RandomTagGroup tagGroup;
  final String categoryId;
  final String categoryKey;
  final String presetId;
  final bool isPresetDefault;
  final VoidCallback? onTap;
  final Widget? dragHandle;

  /// 输出本词组的启用分支；非空时本词组不参与类别的常规抽取
  final List<BranchReference> branchOutputBy;

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
                              if (widget.branchOutputBy.isNotEmpty)
                                BranchOutputBadge(
                                  references: widget.branchOutputBy,
                                  onOpen: (reference) => _showEditDialog(
                                    context,
                                    group: reference.owner,
                                    initialBranchIndex: reference.branchIndex,
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
    // 删除后引用它的分支保留这一项并显示为已失效，这里先告知
    final branchOwners = {
      for (final reference
          in _category?.branchReferences()[widget.tagGroup.id] ??
              const <BranchReference>[])
        context.l10n.randomTagGroupName(reference.owner),
    };
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(context.l10n.randomManager_deleteTagGroupTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.randomManager_deleteTagGroupConfirm(
                context.l10n.randomTagGroupName(widget.tagGroup),
              ),
            ),
            if (branchOwners.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                context.l10n.randomManager_deleteBranchTargetWarning(
                  branchOwners.join(', '),
                ),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
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

  RandomCategory? get _category => ref
      .read(randomPresetNotifierProvider)
      .presets
      .firstWhereOrNull((preset) => preset.id == widget.presetId)
      ?.categories
      .firstWhereOrNull((category) => category.id == widget.categoryId);

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

  /// [group] 为空时编辑本词组；[initialBranchIndex] 打开后直接编辑该分支
  void _showEditDialog(
    BuildContext context, {
    RandomTagGroup? group,
    int initialTabIndex = 0,
    int? initialBranchIndex,
  }) {
    TagGroupEditDialog.show(
      context,
      tagGroup: group ?? widget.tagGroup,
      categoryId: widget.categoryId,
      presetId: widget.presetId,
      isPresetDefault: widget.isPresetDefault,
      initialTabIndex: initialTabIndex,
      initialBranchIndex: initialBranchIndex,
    );
  }
}

enum _TagGroupAction { edit, delete }
