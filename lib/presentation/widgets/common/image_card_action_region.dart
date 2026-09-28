import 'dart:async';

import 'package:flutter/material.dart';

import 'image_card_action.dart';
import 'image_card_context_menu.dart';
import 'image_card_batch_scope.dart';
import '../../../core/utils/localization_extension.dart';

typedef ImageCardActionsBuilder =
    Widget Function(BuildContext context, List<ImageCardAction> actions);

/// Keeps menu and shortcut execution attached to the same resource lifetime.
class ImageCardActionRegion extends StatefulWidget {
  const ImageCardActionRegion({
    super.key,
    required this.actions,
    required this.builder,
    this.onMenuOpened,
    this.menuActions,
    this.menuTitle,
    this.enabled = true,
    this.resourceId,
  });

  final List<ImageCardAction> actions;
  final ImageCardActionsBuilder builder;
  final VoidCallback? onMenuOpened;
  final List<ImageCardAction>? menuActions;
  final String? menuTitle;
  final bool enabled;
  final String? resourceId;

  @override
  State<ImageCardActionRegion> createState() => _ImageCardActionRegionState();
}

class _ImageCardActionRegionState extends State<ImageCardActionRegion> {
  final _runner = ImageCardActionRunner();

  @override
  void dispose() {
    _runner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _runner,
    builder: (context, _) {
      final actions = widget.actions.map((a) => a.bind(_runner)).toList();
      final batch = ImageCardBatchScope.maybeOf(context);
      final useBatch = batch?.targetIds.contains(widget.resourceId) ?? false;
      final menuActions = useBatch
          ? batch!.actions
          : widget.menuActions?.map((a) => a.bind(_runner)).toList() ?? actions;
      final title = useBatch
          ? batch!.title(context)
          : widget.menuTitle ??
                (batch != null && batch.targetIds.isNotEmpty
                    ? context.l10n.cardAction_singleScope
                    : null);
      return GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onSecondaryTapUp: widget.enabled && menuActions.isNotEmpty
            ? (details) {
                widget.onMenuOpened?.call();
                unawaited(
                  ImageCardContextMenu.show(
                    context: context,
                    position: details.globalPosition,
                    actions: menuActions,
                    title: title,
                    listenable: useBatch ? batch!.runner : _runner,
                  ),
                );
              }
            : null,
        child: ImageCardActionPresentationScope(
          runner: _runner,
          menuActions: useBatch ? menuActions : null,
          menuTitle: title,
          menuRunner: useBatch ? batch!.runner : _runner,
          onMenuOpened: widget.onMenuOpened,
          child: widget.builder(context, actions),
        ),
      );
    },
  );
}

class ImageCardActionPresentationScope extends InheritedWidget {
  const ImageCardActionPresentationScope({
    super.key,
    required this.runner,
    required super.child,
    this.onMenuOpened,
    this.menuActions,
    this.menuTitle,
    this.menuRunner,
  });

  final ImageCardActionRunner runner;
  final VoidCallback? onMenuOpened;
  final List<ImageCardAction>? menuActions;
  final String? menuTitle;
  final ImageCardActionRunner? menuRunner;

  static ImageCardActionPresentationScope? maybeOf(
    BuildContext context,
  ) => context
      .dependOnInheritedWidgetOfExactType<ImageCardActionPresentationScope>();

  @override
  bool updateShouldNotify(ImageCardActionPresentationScope oldWidget) =>
      runner != oldWidget.runner ||
      onMenuOpened != oldWidget.onMenuOpened ||
      menuActions != oldWidget.menuActions ||
      menuTitle != oldWidget.menuTitle;
}
