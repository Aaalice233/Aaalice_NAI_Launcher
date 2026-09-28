import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/utils/localization_extension.dart';
import '../bulk_action_bar.dart';
import 'image_card_action.dart';
import 'image_card_action_dispatch.dart';

/// A page builds batch actions from a target snapshot, once for its toolbar and
/// card menus. Single-item editing is never promoted to a loop here.
class ImageCardBatchScope extends StatefulWidget {
  const ImageCardBatchScope({
    super.key,
    required this.targetIds,
    required this.actions,
    required this.child,
    this.runner,
  });

  final Set<String> targetIds;
  final List<ImageCardAction> actions;
  final Widget child;
  final ImageCardActionRunner? runner;

  static ImageCardBatchPresentation? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ImageCardBatchPresentation>();

  @override
  State<ImageCardBatchScope> createState() => _ImageCardBatchScopeState();
}

class _ImageCardBatchScopeState extends State<ImageCardBatchScope> {
  late final _runner = widget.runner ?? ImageCardActionRunner();

  @override
  void dispose() {
    if (widget.runner == null) _runner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _runner,
    builder: (context, _) => ImageCardBatchPresentation(
      targetIds: Set.unmodifiable(widget.targetIds),
      actions: [
        for (final action in widget.actions)
          if (action.supportsBatch) action.bind(_runner),
      ],
      runner: _runner,
      child: widget.child,
    ),
  );
}

class ImageCardBatchPresentation extends InheritedWidget {
  const ImageCardBatchPresentation({
    super.key,
    required this.targetIds,
    required this.actions,
    required this.runner,
    required super.child,
  });

  final Set<String> targetIds;
  final List<ImageCardAction> actions;
  final ImageCardActionRunner runner;

  String title(BuildContext context) =>
      context.l10n.bulkAction_selectedCount(targetIds.length);

  @override
  bool updateShouldNotify(ImageCardBatchPresentation oldWidget) => true;
}

List<BulkActionItem> imageCardBulkItems(
  BuildContext context, {
  List<ImageCardAction> actions = const [],
}) {
  final batch = ImageCardBatchScope.maybeOf(context);
  return [
    for (final action in orderedImageCardActions(batch?.actions ?? actions))
      BulkActionItem(
        icon: action.icon,
        label: action.isLoading
            ? '${action.label} · ${context.l10n.common_loading}'
            : action.label,
        color: action.iconColor,
        isDanger: action.isDanger,
        showDividerBefore: action.isDanger,
        onPressed:
            action.canInvoke && (batch == null || batch.targetIds.isNotEmpty)
            ? () => unawaited(dispatchImageCardAction(context, action))
            : null,
      ),
  ];
}
