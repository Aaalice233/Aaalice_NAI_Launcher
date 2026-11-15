import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../adaptive/interaction_policy.dart';
import 'completion_non_focusable_icon_button.dart';

class CompletionOverlayHeader extends StatelessWidget {
  const CompletionOverlayHeader({
    super.key,
    required this.query,
    required this.resultCount,
    required this.related,
    required this.isRelatedPinned,
    required this.onToggleRelatedPin,
    required this.onOpenSettings,
    required this.onClose,
  });

  final String query;
  final int resultCount;
  final bool related;
  final bool isRelatedPinned;
  final VoidCallback? onToggleRelatedPin;
  final VoidCallback? onOpenSettings;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final touchInput = context.interactionPolicy.touchAvailable;
    final minimumHeight = touchInput ? 56.0 : 36.0;
    final scaledHeight = MediaQuery.textScalerOf(context).scale(14) * 1.35 + 14;
    final headerHeight = scaledHeight > minimumHeight
        ? scaledHeight
        : minimumHeight;
    return Container(
      key: const ValueKey('autocomplete-popup-header'),
      height: headerHeight,
      padding: EdgeInsets.fromLTRB(
        8,
        touchInput ? 3 : 5,
        4,
        touchInput ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final touchCompact = touchInput && constraints.maxWidth < 600;
          final showTitle = constraints.maxWidth >= 440;
          final showFullShortcuts = constraints.maxWidth >= 650;
          final showCompactShortcuts = constraints.maxWidth >= 540;
          return Row(
            children: [
              if (showTitle) ...[
                Container(
                  width: 3,
                  height: 17,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.4),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  related
                      ? context.l10n.autocomplete_relatedHeaderTitle
                      : context.l10n.autocomplete_headerTitle,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Container(
                  key: const ValueKey('autocomplete-popup-query'),
                  height: headerHeight - (touchInput ? 6 : 10),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                      theme.colorScheme.onSurface.withValues(alpha: 0.07),
                      theme.colorScheme.surfaceContainerHigh,
                    ),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    query,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Semantics(
                label: context.l10n.autocomplete_resultsCount(resultCount),
                child: Text(
                  touchCompact
                      ? '$resultCount'
                      : context.l10n.autocomplete_resultsCount(resultCount),
                  key: const ValueKey('autocomplete-popup-result-count'),
                  maxLines: 1,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              SizedBox(width: touchCompact ? 4 : 9),
              if (!touchCompact) ...[
                if (showFullShortcuts)
                  const _KeyboardHints()
                else if (showCompactShortcuts)
                  const _KeyboardHints(compact: true)
                else
                  Tooltip(
                    message: _shortcutDescription(context),
                    child: Icon(
                      Icons.keyboard_alt_outlined,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(width: 2),
              ],
              if (onOpenSettings != null)
                CompletionNonFocusableIconButton(
                  key: const ValueKey('autocomplete-popup-settings'),
                  tooltip: context.l10n.autocomplete_openSettings,
                  icon: Icons.settings_rounded,
                  onPressed: onOpenSettings!,
                ),
              if (related && onToggleRelatedPin != null)
                CompletionNonFocusableIconButton(
                  key: const ValueKey('autocomplete-popup-related-pin'),
                  tooltip: isRelatedPinned
                      ? context.l10n.autocomplete_relatedUnpin
                      : context.l10n.autocomplete_relatedPin,
                  icon: isRelatedPinned
                      ? Icons.push_pin_rounded
                      : Icons.push_pin_outlined,
                  active: isRelatedPinned,
                  onPressed: onToggleRelatedPin!,
                ),
              CompletionNonFocusableIconButton(
                key: const ValueKey('autocomplete-popup-close'),
                tooltip: context.l10n.autocomplete_actionClose,
                icon: Icons.close_rounded,
                onPressed: onClose,
              ),
            ],
          );
        },
      ),
    );
  }

  static String _shortcutDescription(BuildContext context) =>
      '↑↓ ${context.l10n.autocomplete_actionSelect} · '
      'Enter/Tab ${context.l10n.autocomplete_actionConfirm} · '
      'Esc ${context.l10n.autocomplete_actionClose}';
}

class _KeyboardHints extends StatelessWidget {
  const _KeyboardHints({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontSize: 10.5,
    );
    final keyStyle = mutedStyle?.copyWith(
      color: theme.colorScheme.onSurface,
      fontWeight: FontWeight.w600,
    );
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: compact
          ? [
              Text('↑↓', style: keyStyle),
              Text(' · ', style: mutedStyle),
              Text('Enter/Tab', style: keyStyle),
              Text(' · ', style: mutedStyle),
              Text('Esc', style: keyStyle),
            ]
          : [
              Text('↑↓', style: keyStyle),
              const SizedBox(width: 3),
              Text(context.l10n.autocomplete_actionSelect, style: mutedStyle),
              Text(' · ', style: mutedStyle),
              Text('Enter/Tab', style: keyStyle),
              const SizedBox(width: 3),
              Text(context.l10n.autocomplete_actionConfirm, style: mutedStyle),
              Text(' · ', style: mutedStyle),
              Text('Esc', style: keyStyle),
              const SizedBox(width: 3),
              Text(context.l10n.autocomplete_actionClose, style: mutedStyle),
            ],
    );
    return Tooltip(
      message: CompletionOverlayHeader._shortcutDescription(context),
      child: ClipRect(
        child: SizedBox(
          width: compact ? 105 : 218,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: content,
          ),
        ),
      ),
    );
  }
}
