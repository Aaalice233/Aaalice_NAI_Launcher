import 'package:flutter/material.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:nai_launcher/presentation/themes/core/input_surface_style.dart';

/// 提示词输入框的搜索与替换悬浮工具栏。
class PromptSearchToolbar extends StatelessWidget {
  const PromptSearchToolbar({
    super.key,
    required this.canReplace,
    required this.replaceVisible,
    required this.searchController,
    required this.searchFocusNode,
    required this.replaceController,
    required this.replaceFocusNode,
    required this.matchCount,
    required this.activeMatchIndex,
    required this.canRunReplace,
    required this.onToggleReplaceVisible,
    required this.onPreviousMatch,
    required this.onNextMatch,
    required this.onClose,
    required this.onReplaceActive,
    required this.onReplaceAll,
  });

  final bool canReplace;
  final bool replaceVisible;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final TextEditingController replaceController;
  final FocusNode replaceFocusNode;
  final int matchCount;
  final int activeMatchIndex;
  final bool canRunReplace;
  final VoidCallback onToggleReplaceVisible;
  final VoidCallback onPreviousMatch;
  final VoidCallback onNextMatch;
  final VoidCallback onClose;
  final VoidCallback onReplaceActive;
  final VoidCallback onReplaceAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final showReplaceRow = canReplace && replaceVisible;

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: canReplace ? 400 : 360),
        child: Material(
          elevation: 0,
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (canReplace)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: _PromptSearchIconButton(
                      key: const ValueKey('prompt_input_replace_toggle'),
                      icon: replaceVisible
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      tooltip: context.l10n.prompt_replaceToggle,
                      onPressed: onToggleReplaceVisible,
                    ),
                  ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSearchRow(context, theme, colorScheme),
                      if (showReplaceRow) ...[
                        const SizedBox(height: 6),
                        _buildReplaceRow(context, theme, colorScheme),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchRow(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final total = matchCount;
    final current = total == 0 ? 0 : activeMatchIndex + 1;

    final field = _PromptSearchToolbarField(
      fieldKey: const ValueKey('prompt_input_search_field'),
      controller: searchController,
      focusNode: searchFocusNode,
      hintText: context.l10n.prompt_searchHint,
      prefixIcon: Icons.search,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => onNextMatch(),
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.prompt_searchMatchCount(current, total),
          style: theme.textTheme.labelMedium?.copyWith(
            color: total == 0 && searchController.text.isNotEmpty
                ? colorScheme.error
                : colorScheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 2),
        _PromptSearchIconButton(
          icon: Icons.keyboard_arrow_up,
          tooltip: context.l10n.prompt_searchPrevious,
          onPressed: total == 0 ? null : onPreviousMatch,
        ),
        _PromptSearchIconButton(
          icon: Icons.keyboard_arrow_down,
          tooltip: context.l10n.prompt_searchNext,
          onPressed: total == 0 ? null : onNextMatch,
        ),
        _PromptSearchIconButton(
          icon: Icons.close,
          tooltip: context.l10n.prompt_searchClose,
          onPressed: onClose,
        ),
      ],
    );
    if (MediaQuery.textScalerOf(context).scale(14) >= 20) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          field,
          const SizedBox(height: 4),
          Align(alignment: Alignment.centerRight, child: actions),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(child: field),
        const SizedBox(width: 8),
        actions,
      ],
    );
  }

  Widget _buildReplaceRow(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final field = _PromptSearchToolbarField(
      fieldKey: const ValueKey('prompt_input_replace_field'),
      controller: replaceController,
      focusNode: replaceFocusNode,
      hintText: context.l10n.prompt_replaceHint,
      prefixIcon: Icons.find_replace,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => onReplaceActive(),
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PromptSearchIconButton(
          key: const ValueKey('prompt_input_replace_current'),
          icon: Icons.find_replace,
          tooltip: context.l10n.prompt_replaceCurrent,
          onPressed: canRunReplace ? onReplaceActive : null,
        ),
        _PromptSearchIconButton(
          key: const ValueKey('prompt_input_replace_all'),
          icon: Icons.done_all,
          tooltip: context.l10n.prompt_replaceAll,
          onPressed: canRunReplace ? onReplaceAll : null,
        ),
      ],
    );
    if (MediaQuery.textScalerOf(context).scale(14) >= 20) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          field,
          Align(alignment: Alignment.centerRight, child: actions),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(child: field),
        const SizedBox(width: 2),
        actions,
      ],
    );
  }
}

class _PromptSearchToolbarField extends StatelessWidget {
  const _PromptSearchToolbarField({
    required this.fieldKey,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.prefixIcon,
    required this.textInputAction,
    required this.onSubmitted,
  });

  final Key fieldKey;
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final IconData prefixIcon;
  final TextInputAction textInputAction;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final minHeight = (MediaQuery.textScalerOf(context).scale(14) * 1.35 + 16)
        .clamp(34.0, double.infinity);
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: TextField(
        key: fieldKey,
        controller: controller,
        focusNode: focusNode,
        textInputAction: textInputAction,
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(prefixIcon, size: 18),
          isDense: true,
          filled: true,
          fillColor: inputSurfaceFillColor(colorScheme),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
        ),
        onSubmitted: onSubmitted,
      ),
    );
  }
}

class _PromptSearchIconButton extends StatelessWidget {
  const _PromptSearchIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }
}
