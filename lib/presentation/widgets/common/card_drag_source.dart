import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/agent/resources/agent_chat_resource_drag_format.dart';
import '../../../core/utils/image_share_sanitizer.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/localization_extension.dart';
import '../../adaptive/interaction_policy.dart';
import '../../utils/card_drag_format.dart';
import '../gallery/gallery_drag_file.dart';
import '../gallery/gallery_drag_session.dart';
import 'card_drag_resource.dart';
import 'card_virtual_file.dart';
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

  @override
  void dispose() {
    _dragging.dispose();
    super.dispose();
  }

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
    ToastController? preparationToast;
    final preparation = CardDragPreparation(
      snapshot,
      onStarted: () {
        if (overlay?.mounted == true) {
          preparationToast = AppToast.showProgressOnOverlay(
            overlay,
            l10n.cardDrag_preparingCount(snapshot.length),
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
      final resource = snapshot[index];
      final item = DragItem(
        suggestedName: resource.fileName,
        localData: resource.payload,
      );
      item.add(cardDragFormat(jsonEncode(resource.payload)));
      final reference = resource.reference;
      if (reference != null) addAgentResourceDragPayload(item, reference);
      final format = resource.format;
      if (format != null && resource.prepare != null) {
        if (item.virtualFileSupported) {
          final resourceIndex = index;
          addCardVirtualFile(
            item,
            format: format,
            prepare: () => preparation.bytesAt(resourceIndex),
            reportFailure: reportFailure,
          );
        } else {
          final bytes = await preparation.bytesAt(index);
          final transfer = GalleryDragFile(
            item: item,
            session: request.session,
          );
          final ready = await transfer.addImage(
            SanitizedShareImage(
              bytes: bytes,
              fileName: resource.fileName,
              mimeType: 'application/octet-stream',
            ),
            format: format,
          );
          if (!ready) return null;
        }
      }
      items.add(item);
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
    final enabled =
        widget.enabled && context.interactionPolicy.usesAnchoredMenus;
    return DragItemWidget(
      allowedOperations: () => enabled ? [DropOperation.copy] : [],
      dragItemProvider: _start,
      dragBuilder: _feedback,
      liftBuilder: _feedback,
      child: DraggableWidget(
        isLocationDraggable: (_) => enabled,
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
