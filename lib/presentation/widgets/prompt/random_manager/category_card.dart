import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/prompt/random_category.dart';
import '../../../../data/models/prompt/tag_scope.dart';
import '../../../providers/random_preset_provider.dart';
import 'add_tag_group_dialog.dart';
import 'random_config_l10n.dart';
import 'tag_group_card.dart';

export 'add_tag_group_dialog.dart' show AddTagGroupDialog;
export 'category_card_list.dart' show CategoryCardList, CategoryCardGrid;
export 'category_card_widgets.dart'
    show
        ScopeTripleSwitch,
        ColorfulProbabilitySlider,
        AddTagGroupCard,
        AddCategoryButton,
        EmptyCategoryPlaceholder,
        CategoryStats;

class CategoryCard extends ConsumerStatefulWidget {
  const CategoryCard({
    super.key,
    required this.category,
    required this.presetId,
    this.isPresetDefault = false,
    this.onEdit,
  });

  final RandomCategory category;
  final String presetId;
  final bool isPresetDefault;
  final VoidCallback? onEdit;

  @override
  ConsumerState<CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends ConsumerState<CategoryCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Semantics(
      container: true,
      expanded: _expanded,
      enabled: category.enabled,
      label: context.l10n.randomCategoryName(category),
      child: AnimatedOpacity(
        opacity: category.enabled ? 1 : 0.56,
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 140),
        child: Container(
          decoration: BoxDecoration(
            color: _expanded
                ? colors.surfaceContainer
                : colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _CategoryHeader(
                category: category,
                expanded: _expanded,
                readOnly: widget.isPresetDefault,
                onToggleExpanded: () => setState(() => _expanded = !_expanded),
                onToggleEnabled: (enabled) =>
                    _updateCategory(category.copyWith(enabled: enabled)),
              ),
              AnimatedSize(
                duration: reduceMotion
                    ? Duration.zero
                    : const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _expanded
                    ? _CategoryEditor(
                        category: category,
                        presetId: widget.presetId,
                        readOnly: widget.isPresetDefault,
                        onCategoryChanged: _updateCategory,
                        onAddGroup: () => _addTagGroup(context),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _updateCategory(RandomCategory category) {
    ref.read(randomPresetNotifierProvider.notifier).updateCategory(category);
  }

  Future<void> _addTagGroup(BuildContext context) {
    return AddTagGroupDialog.show(
      context,
      category: widget.category,
      presetId: widget.presetId,
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({
    required this.category,
    required this.expanded,
    required this.readOnly,
    required this.onToggleExpanded,
    required this.onToggleEnabled,
  });

  final RandomCategory category;
  final bool expanded;
  final bool readOnly;
  final VoidCallback onToggleExpanded;
  final ValueChanged<bool> onToggleEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final percentage = (category.probability * 100).round();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onToggleExpanded,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 66),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(
                  _categoryIcon(category.key),
                  size: 20,
                  color: category.enabled
                      ? colors.primary
                      : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.l10n.randomCategoryName(category),
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${context.l10n.randomManager_tagGroupCount(category.groupCount.toString())} · $percentage%',
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
                if (readOnly)
                  Tooltip(
                    message: context.l10n.randomManager_readOnlyTooltip,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: 16,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                Switch(
                  value: category.enabled,
                  onChanged: readOnly ? null : onToggleEnabled,
                ),
                const SizedBox(width: 2),
                AnimatedRotation(
                  duration: reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 160),
                  curve: Curves.easeOutCubic,
                  turns: expanded ? 0.5 : 0,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryEditor extends StatelessWidget {
  const _CategoryEditor({
    required this.category,
    required this.presetId,
    required this.readOnly,
    required this.onCategoryChanged,
    required this.onAddGroup,
  });

  final RandomCategory category;
  final String presetId;
  final bool readOnly;
  final ValueChanged<RandomCategory> onCategoryChanged;
  final VoidCallback onAddGroup;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(
            height: 1,
            color: colors.outlineVariant.withValues(alpha: 0.18),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final scope = _ScopeSelector(
                value: category.scope,
                enabled: !readOnly && category.enabled,
                onChanged: (value) =>
                    onCategoryChanged(category.copyWith(scope: value)),
              );
              final probability = _ProbabilityEditor(
                value: category.probability,
                enabled: !readOnly && category.enabled,
                onChanged: (value) =>
                    onCategoryChanged(category.copyWith(probability: value)),
              );
              if (constraints.maxWidth >= 620) {
                return Row(
                  children: [
                    scope,
                    const SizedBox(width: 20),
                    Expanded(child: probability),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(alignment: Alignment.centerLeft, child: scope),
                  const SizedBox(height: 10),
                  probability,
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                context.l10n.randomManager_tagGroupList,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (!readOnly)
                TextButton.icon(
                  onPressed: onAddGroup,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(context.l10n.randomManager_addTagGroup),
                ),
            ],
          ),
          if (category.groups.isNotEmpty)
            ...category.groups.map(
              (group) => Padding(
                padding: const EdgeInsets.only(top: 6),
                child: TagGroupCard(
                  tagGroup: group,
                  categoryId: category.id,
                  categoryKey: category.key,
                  presetId: presetId,
                  isPresetDefault: readOnly,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScopeSelector extends StatelessWidget {
  const _ScopeSelector({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final TagScope value;
  final bool enabled;
  final ValueChanged<TagScope> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<TagScope>(
      segments: [
        ButtonSegment(
          value: TagScope.all,
          label: Text(context.l10n.scope_all),
          icon: const Icon(Icons.layers_outlined, size: 16),
        ),
        ButtonSegment(
          value: TagScope.global,
          label: Text(context.l10n.randomManager_global),
          icon: const Icon(Icons.public_rounded, size: 16),
        ),
        ButtonSegment(
          value: TagScope.character,
          label: Text(context.l10n.scope_character),
          icon: const Icon(Icons.person_outline_rounded, size: 16),
        ),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: enabled
          ? (selection) => onChanged(selection.first)
          : null,
      style: const ButtonStyle(
        visualDensity: VisualDensity(horizontal: -2, vertical: -2),
      ),
    );
  }
}

class _ProbabilityEditor extends StatelessWidget {
  const _ProbabilityEditor({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final double value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Row(
      children: [
        Text(
          context.l10n.randomManager_probability,
          style: theme.textTheme.labelMedium?.copyWith(
            color: colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Slider(
            value: value.clamp(0, 1),
            divisions: 20,
            onChanged: enabled ? onChanged : null,
          ),
        ),
        SizedBox(
          width: 42,
          child: Text(
            '${(value * 100).round()}%',
            textAlign: TextAlign.end,
            style: theme.textTheme.labelMedium?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

IconData _categoryIcon(String key) {
  return switch (key) {
    'hairColor' => Icons.palette_outlined,
    'eyeColor' => Icons.visibility_outlined,
    'hairStyle' => Icons.content_cut_rounded,
    'expression' => Icons.sentiment_satisfied_alt_outlined,
    'pose' => Icons.accessibility_new_rounded,
    'clothing' => Icons.checkroom_outlined,
    'bodyFeature' => Icons.person_outline_rounded,
    'accessory' => Icons.diamond_outlined,
    'style' => Icons.brush_outlined,
    'background' => Icons.landscape_outlined,
    'scene' => Icons.location_on_outlined,
    'composition' => Icons.photo_camera_outlined,
    'prop' => Icons.inventory_2_outlined,
    'effect' => Icons.auto_awesome_outlined,
    'year' => Icons.calendar_month_outlined,
    'detail' => Icons.casino_outlined,
    _ => Icons.category_outlined,
  };
}
