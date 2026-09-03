import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../../adaptive/window_size_class.dart';
import '../common/adaptive_dialog_frame.dart';
import 'fixed_tags_columns.dart';
import 'fixed_tags_dialog_chrome.dart';
import 'fixed_tags_dialog_controller.dart';
import 'fixed_tags_dialog_models.dart';

class FixedTagsDialogView extends StatelessWidget {
  const FixedTagsDialogView({
    super.key,
    required this.data,
    required this.commands,
    required this.controller,
    this.presentationManaged = false,
  });

  final FixedTagsDialogViewData data;
  final FixedTagsDialogCommands commands;
  final FixedTagsDialogController controller;
  final bool presentationManaged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final presentationIsCompact = context.adaptiveWindow.isCompact;
    final body = LayoutBuilder(
      builder: (context, constraints) {
        final isCompact =
            WindowSizeClass.fromWidth(constraints.maxWidth).isCompact ||
            MediaQuery.textScalerOf(context).scale(1) >= 2;
        return ClipRRect(
          borderRadius: BorderRadius.circular(presentationIsCompact ? 0 : 8),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: AnimatedContainer(
              key: const ValueKey('fixed-tags-dialog-surface'),
              duration: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: isDark
                    ? theme.colorScheme.surface.withValues(alpha: 0.85)
                    : theme.colorScheme.surface.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(
                  presentationIsCompact ? 0 : 8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.15),
                    blurRadius: 32,
                    spreadRadius: -4,
                    offset: const Offset(0, 16),
                  ),
                  if (isDark)
                    BoxShadow(
                      color: theme.colorScheme.secondary.withValues(
                        alpha: 0.08,
                      ),
                      blurRadius: 48,
                      spreadRadius: -8,
                    ),
                ],
              ),
              child: Column(
                children: [
                  FixedTagsDialogHeader(
                    data: data,
                    commands: commands,
                    isCompact: isCompact,
                    isDark: isDark,
                    presentationManaged: presentationManaged,
                  ),
                  Expanded(
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
        );
      },
    );
    if (presentationManaged) return body;

    final content = AdaptiveDialogFrame(
      maxWidth: presentationIsCompact ? double.infinity : 980,
      maxHeight: presentationIsCompact ? double.infinity : 620,
      reservedVerticalSpace: presentationIsCompact ? 0 : 48,
      scaleReservedVerticalSpace: true,
      horizontalMargin: presentationIsCompact ? 0 : 40,
      child: body,
    );
    return Dialog(
      insetPadding: EdgeInsets.all(presentationIsCompact ? 0 : 24),
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(presentationIsCompact ? 0 : 8),
      ),
      child: presentationIsCompact ? SafeArea(child: content) : content,
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
