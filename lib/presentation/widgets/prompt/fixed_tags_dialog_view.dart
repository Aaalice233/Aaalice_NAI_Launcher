import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import 'fixed_tags_columns.dart';
import 'fixed_tags_dialog_chrome.dart';
import 'fixed_tags_dialog_controller.dart';
import 'fixed_tags_dialog_models.dart';

const _collapsedWidth = 520.0;
const _expandedWidth = 980.0;
const _horizontalInset = 80.0;

class FixedTagsDialogView extends StatelessWidget {
  const FixedTagsDialogView({
    super.key,
    required this.data,
    required this.commands,
    required this.controller,
  });

  final FixedTagsDialogViewData data;
  final FixedTagsDialogCommands commands;
  final FixedTagsDialogController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenSize = MediaQuery.sizeOf(context);
    final isCompact = screenSize.width < 600;
    final horizontalInset = isCompact ? 24.0 : _horizontalInset;
    final availableWidth = math.max(0.0, screenSize.width - horizontalInset);
    final targetWidth = isCompact
        ? availableWidth
        : data.state.negativePanelExpanded
        ? _expandedWidth
        : _collapsedWidth;
    final dialogWidth = math.min(targetWidth, availableWidth);
    final maxHeight = isCompact ? math.max(0.0, screenSize.height - 24) : 620.0;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 40,
        vertical: isCompact ? 12 : 24,
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: AnimatedContainer(
            key: const ValueKey('fixed-tags-dialog-surface'),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            width: dialogWidth,
            constraints: BoxConstraints(
              minWidth: dialogWidth,
              maxWidth: dialogWidth,
              maxHeight: maxHeight,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? theme.colorScheme.surface.withValues(alpha: 0.85)
                  : theme.colorScheme.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                  blurRadius: 32,
                  spreadRadius: -4,
                  offset: const Offset(0, 16),
                ),
                if (isDark)
                  BoxShadow(
                    color: theme.colorScheme.secondary.withValues(alpha: 0.08),
                    blurRadius: 48,
                    spreadRadius: -8,
                  ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FixedTagsDialogHeader(
                  data: data,
                  commands: commands,
                  isCompact: isCompact,
                  isDark: isDark,
                ),
                Flexible(
                  child:
                      data.state.entries.isEmpty &&
                          !data.state.negativePanelExpanded &&
                          !isCompact
                      ? const _EmptyState()
                      : FixedTagsColumns(
                          data: data,
                          commands: commands,
                          controller: controller,
                          isCompact: isCompact,
                          isDark: isDark,
                        ),
                ),
                FixedTagsDialogFooter(
                  data: data,
                  commands: commands,
                  isCompact: isCompact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.fixedTags_empty,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              context.l10n.fixedTags_emptyHint,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline.withValues(alpha: 0.7),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
