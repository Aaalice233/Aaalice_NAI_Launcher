import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/agent/resources/agent_chat_resource_drag_format.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/localization_extension.dart';
import '../../utils/card_drag_format.dart';
import 'app_toast.dart';
import 'image_card_action.dart';

export '../../../core/agent/resources/agent_chat_resource_reference.dart'
    show AgentChatResourceKind;

/// Exposes the active drop state to the classification row that owns the
/// visual surface. Keeping the feedback on that row avoids stacking a second
/// rounded highlight around its built-in pointer hover state.
class LibraryClassificationDropTargetStatus extends InheritedWidget {
  const LibraryClassificationDropTargetStatus({
    super.key,
    required this.isAccepting,
    required super.child,
  });

  final bool isAccepting;

  static bool isAcceptingOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<
              LibraryClassificationDropTargetStatus
            >()
            ?.isAccepting ??
        false;
  }

  @override
  bool updateShouldNotify(LibraryClassificationDropTargetStatus oldWidget) {
    return isAccepting != oldWidget.isAccepting;
  }
}

/// Resolves the entire set before changing any classification.
class LibraryClassificationDropTarget<T extends Object> extends StatefulWidget {
  const LibraryClassificationDropTarget({
    super.key,
    required this.kind,
    required this.resolve,
    required this.onAccept,
    required this.child,
    this.needsChange,
    this.enabled = true,
  });

  final AgentChatResourceKind kind;
  final FutureOr<T?> Function(String id) resolve;
  final FutureOr<void> Function(T) onAccept;
  final bool Function(T)? needsChange;
  final Widget child;
  final bool enabled;

  @override
  State<LibraryClassificationDropTarget<T>> createState() =>
      _LibraryClassificationDropTargetState<T>();
}

class _LibraryClassificationDropTargetState<T extends Object>
    extends State<LibraryClassificationDropTarget<T>> {
  bool _accepting = false;

  bool _canRead(Iterable<DropItem> items) =>
      widget.enabled &&
      items.isNotEmpty &&
      items.every(
        (item) => decodeLocalAgentResource(item.localData)?.kind == widget.kind,
      );

  void _setAccepting(bool value) {
    if (mounted && value != _accepting) setState(() => _accepting = value);
  }

  @override
  Widget build(BuildContext context) => DropRegion(
    formats: [cardDragFormat, agentChatResourceDragFormat],
    onDropOver: (event) {
      final accepts = _canRead(event.session.items);
      _setAccepting(accepts);
      return accepts ? DropOperation.copy : DropOperation.none;
    },
    onDropLeave: (_) => _setAccepting(false),
    onPerformDrop: (event) async {
      _setAccepting(false);
      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      final errorLabel = context.l10n.common_error;
      final resolve = widget.resolve;
      final needsChange = widget.needsChange;
      final onAccept = widget.onAccept;
      try {
        if (!_canRead(event.session.items)) {
          throw StateError('Unsupported classification resource set');
        }
        final targets = <T>[];
        for (final item in event.session.items) {
          final reference = decodeLocalAgentResource(item.localData)!;
          final target = await resolve(reference.resourceId);
          if (target == null) {
            throw StateError(
              'Classification target is unavailable: ${reference.resourceId}',
            );
          }
          targets.add(target);
        }
        HapticFeedback.heavyImpact();
        final result = await ImageCardBatchResult.execute<T>(targets, (
          target,
        ) async {
          if (needsChange?.call(target) ?? true) await onAccept(target);
        });
        if (result.failures.isNotEmpty) {
          for (final failure in result.failures.values) {
            AppLogger.e(
              'Classification drop failed',
              failure.error,
              failure.stackTrace,
              'CardDrag',
            );
          }
          throw StateError(
            '${result.failures.length}/${targets.length}: ${result.failures.values.map((failure) => failure.error).join('; ')}',
          );
        }
      } catch (error, stack) {
        AppLogger.e('Classification drop failed', error, stack, 'CardDrag');
        AppToast.errorOnOverlay(overlay, '$errorLabel: $error');
      }
    },
    child: LibraryClassificationDropTargetStatus(
      isAccepting: _accepting,
      child: widget.child,
    ),
  );
}
