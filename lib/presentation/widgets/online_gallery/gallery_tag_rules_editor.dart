import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../adaptive/interaction_policy.dart';
import '../autocomplete/autocomplete_config.dart';
import '../autocomplete/autocomplete_wrapper.dart';
import '../common/translated_tag_text.dart';

class GalleryTagRulesHeader extends StatelessWidget {
  const GalleryTagRulesHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.count,
    required this.accent,
    this.onUndo,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final int count;
  final Color accent;
  final VoidCallback? onUndo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 19, color: accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (onUndo != null)
          IconButton(
            tooltip: context.l10n.common_undo,
            onPressed: onUndo,
            icon: const Icon(Icons.undo, size: 19),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            '$count',
            style: theme.textTheme.labelMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class GalleryTagRulesInput extends StatelessWidget {
  const GalleryTagRulesInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onAdd,
    this.helperText,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final String? helperText;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AutocompleteWrapper(
            controller: controller,
            focusNode: focusNode,
            config: const AutocompleteConfig(
              minQueryLength: 1,
              autoInsertComma: false,
              showTranslation: true,
              enableChineseSearch: true,
            ),
            onSuggestionSelected: (_) => onAdd(),
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                isDense: true,
                border: const OutlineInputBorder(),
                hintText: hintText,
                helperText: helperText,
              ),
              onSubmitted: (_) => onAdd(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 48,
          child: Center(
            child: IconButton(
              tooltip: context.l10n.common_add,
              onPressed: onAdd,
              icon: const Icon(Icons.add),
            ),
          ),
        ),
      ],
    );
  }
}

class GalleryTagRulesList extends StatelessWidget {
  const GalleryTagRulesList({
    super.key,
    required this.tags,
    required this.emptyLabel,
    required this.onDelete,
    required this.keyPrefix,
    this.maxHeight = 280,
  });

  final List<String> tags;
  final String emptyLabel;
  final ValueChanged<String> onDelete;
  final String keyPrefix;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controlExtent = context.interactionPolicy.minimumControlExtent;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    final rowExtent = math.max(controlExtent, 22 * textScale);
    return Container(
      width: double.infinity,
      height: maxHeight,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: tags.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  emptyLabel,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            )
          : ListView.builder(
              key: ValueKey('$keyPrefix-virtual-list'),
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemExtent: rowExtent,
              itemCount: tags.length,
              itemBuilder: (context, index) {
                final tag = tags[index];
                return ListTile(
                  key: ValueKey('$keyPrefix-item-$tag'),
                  dense: true,
                  minTileHeight: controlExtent,
                  title: TranslatedTagText(
                    tag,
                    style: theme.textTheme.bodyMedium,
                    translationStyle: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  trailing: IconButton(
                    key: ValueKey('$keyPrefix-delete-$tag'),
                    tooltip: context.l10n.common_delete,
                    visualDensity: VisualDensity.standard,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints.tightFor(
                      width: controlExtent,
                      height: controlExtent,
                    ),
                    onPressed: () => onDelete(tag),
                    icon: const Icon(Icons.close, size: 17),
                  ),
                );
              },
            ),
    );
  }
}

class GalleryTagRulesActions extends StatelessWidget {
  const GalleryTagRulesActions({
    super.key,
    required this.clearEnabled,
    required this.onClear,
    this.leading,
  });

  final bool clearEnabled;
  final VoidCallback onClear;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final clear = TextButton.icon(
      onPressed: clearEnabled ? onClear : null,
      icon: const Icon(Icons.delete_outline, size: 18),
      label: Text(context.l10n.common_clear),
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.error,
      ),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        if (constraints.maxWidth < 420 || textScale > 1.5) {
          return Wrap(
            spacing: 8,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            children: [if (leading != null) leading!, clear],
          );
        }
        return Row(
          children: [if (leading != null) leading!, const Spacer(), clear],
        );
      },
    );
  }
}
