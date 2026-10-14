import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/platform/platform_capabilities.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/localization_extension.dart';
import '../../adaptive/interaction_policy.dart';
import '../gallery/gallery_drag_session.dart';
import 'card_drag_exit_watcher.dart';
import 'card_drag_item.dart';
import 'card_drag_resource.dart';
import 'app_toast.dart';
import 'image_hover_preview_controller.dart';

export 'card_drag_resource.dart';

class CardDragScope extends InheritedWidget {
  const CardDragScope({
    super.key,
    required this.snapshot,
    required super.child,
  });

  final FutureOr<List<CardDragResource>> Function(CardDragResource source)
  snapshot;

  static CardDragScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CardDragScope>();

  @override
  bool updateShouldNotify(CardDragScope oldWidget) =>
      snapshot != oldWidget.snapshot;
}

/// Owns exactly one native gesture, including internal and external formats.
class CardDragSource extends StatefulWidget {
  const CardDragSource({
    super.key,
    required this.resource,
    required this.child,
    this.enabled = true,
    this.feedbackBuilder,
    this.snapshot,
    this.dragOpacity = .3,
  });

  final CardDragResource Function() resource;
  final Widget child;
  final bool enabled;
  final Widget Function(BuildContext, Widget)? feedbackBuilder;
  final FutureOr<List<CardDragResource>> Function(CardDragResource)? snapshot;
  final double dragOpacity;

  @override
  State<CardDragSource> createState() => _CardDragSourceState();
}

class _CardDragSourceState extends State<CardDragSource> {
  final _dragging = GalleryDragSessionState();
  List<DragItem> _items = const [];
  bool _policyAllowsDrag = false;

  bool get _dragEnabled => widget.enabled && _policyAllowsDrag;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _policyAllowsDrag = context.interactionPolicy.usesAnchoredMenus;
  }

  @override
  void dispose() {
    _dragging.dispose();
    super.dispose();
  }

  List<DropOperation> _allowedOperations() =>
      _dragEnabled ? [DropOperation.copy] : [];

  // The desktop drag recognizer keeps the predicate it was first built with.
  bool _isLocationDraggable(Offset _) => _dragEnabled;

  Future<DragItem?> _start(DragItemRequest request) async {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final errorLabel = context.l10n.common_error;
    try {
      return await _prepareSession(request);
    } catch (error, stack) {
      AppLogger.e('Card drag could not start', error, stack, 'CardDrag');
      AppToast.errorOnOverlay(overlay, '$errorLabel: $error');
      return null;
    }
  }

  Future<DragItem?> _prepareSession(DragItemRequest request) async {
    if (!widget.enabled) return null;
    ImageHoverPreviewController.dismissAll();
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final errorLabel = context.l10n.common_error;
    final l10n = context.l10n;
    final view = View.of(context);
    final exportMode = PlatformCapabilities.current.dragFileExportMode;
    final source = widget.resource();
    final scope = CardDragScope.maybeOf(context);
    final snapshot = List<CardDragResource>.unmodifiable(
      await (scope?.snapshot(source) ??
          widget.snapshot?.call(source) ??
          [source]),
    );
    if (snapshot.isEmpty) return null;
    if (snapshot.map((resource) => resource.id).toSet().length !=
        snapshot.length) {
      throw StateError('Duplicate resource identities in drag snapshot');
    }
    final readyFiles = await Future.wait([
      for (final resource in snapshot)
        resource.readyFile?.call() ?? Future<File?>.value(),
    ]);
    final exportSlots = <int, int>{};
    for (var index = 0; index < snapshot.length; index++) {
      if (cardDragNeedsExport(snapshot[index], readyFiles[index])) {
        exportSlots[index] = exportSlots.length;
      }
    }
    ToastController? preparationToast;
    final preparation = CardDragPreparation(
      [for (final index in exportSlots.keys) snapshot[index]],
      onStarted: () {
        if (overlay?.mounted == true) {
          preparationToast = AppToast.showProgressOnOverlay(
            overlay,
            l10n.cardDrag_preparingCount(exportSlots.length),
          );
        }
      },
      onFinished: () => preparationToast?.dismiss(),
    );
    var reportedFailure = false;
    void reportFailure(Object error, StackTrace stack) {
      if (reportedFailure) return;
      reportedFailure = true;
      AppLogger.e('Card drag export failed', error, stack, 'CardDrag');
      AppToast.errorOnOverlay(overlay, '$errorLabel: $error');
    }

    final items = <DragItem>[];
    for (var index = 0; index < snapshot.length; index++) {
      final slot = exportSlots[index];
      items.add(
        await buildCardDragItem(
          snapshot[index],
          readyFile: readyFiles[index],
          bytes: slot == null ? null : () => preparation.bytesAt(slot),
          reportFailure: reportFailure,
          exportMode: exportMode,
        ),
      );
    }
    if (exportMode == DragFileExportMode.onDemandFile &&
        exportSlots.isNotEmpty) {
      // In-app drops never need the files; start once the cursor leaves.
      CardDragExitWatcher(
        session: request.session,
        startLocation: request.location,
        devicePixelRatio: view.devicePixelRatio,
        physicalSize: view.physicalSize,
        onExit: () => preparation.prepare().ignore(),
      );
    }
    _items = items;
    if (mounted) _dragging.track(request.session);
    void releaseSnapshot() {
      if (request.session.dragCompleted.value == null) return;
      request.session.dragCompleted.removeListener(releaseSnapshot);
      if (identical(_items, items)) _items = const [];
    }

    request.session.dragCompleted.addListener(releaseSnapshot);
    return items.first;
  }

  Widget _feedback(BuildContext context, Widget child) {
    final feedback = widget.feedbackBuilder?.call(context, child) ?? child;
    if (_items.length < 2) return feedback;
    return Stack(
      children: [
        feedback,
        Positioned(top: 8, right: 8, child: Badge.count(count: _items.length)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DragItemWidget(
      allowedOperations: _allowedOperations,
      dragItemProvider: _start,
      dragBuilder: _feedback,
      liftBuilder: _feedback,
      child: DraggableWidget(
        isLocationDraggable: _isLocationDraggable,
        onDragConfiguration: (configuration, session) {
          final first = configuration.items.first;
          return DragConfiguration(
            allowedOperations: configuration.allowedOperations,
            options: configuration.options,
            items: [
              first,
              for (final item in _items.skip(1))
                DragConfigurationItem(
                  item: item,
                  image: first.image.retain(),
                  liftImage: first.liftImage?.retain(),
                ),
            ],
          );
        },
        child: ValueListenableBuilder<bool>(
          valueListenable: _dragging,
          child: widget.child,
          builder: (context, dragging, child) =>
              Opacity(opacity: dragging ? widget.dragOpacity : 1, child: child),
        ),
      ),
    );
  }
}
