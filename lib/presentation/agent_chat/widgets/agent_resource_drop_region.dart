import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/database/database_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../widgets/common/app_toast.dart';
import '../../widgets/drop/global_drop_overlay.dart';
import '../providers/agent_chat_notifier.dart';
import '../services/agent_chat_drop_reader.dart';
import '../../widgets/common/image_card_actions.dart';
import '../../widgets/common/card_drag_source.dart';
import '../../selection/card_selection.dart';
import '../../selection/card_selection_scope.dart';
import '../../utils/card_drop_reader.dart';
import '../../utils/card_resource_drag_factory.dart';
import '../../utils/gallery_drop_reader.dart';

export '../../../core/agent/resources/agent_chat_resource_drag_format.dart';

Future<void> addAgentResourceToComposer({
  required BuildContext context,
  required WidgetRef ref,
  required AgentChatResourceReference reference,
}) async {
  if (!context.mounted) return;
  try {
    await ref
        .read(agentChatNotifierProvider.notifier)
        .addPendingResource(reference);
    if (context.mounted) {
      AppToast.success(context, context.l10n.agentChat_resourceAdded);
    }
  } on Object catch (error) {
    if (context.mounted) {
      AppToast.error(
        context,
        context.l10n.agentChat_addResourceFailed('$error'),
      );
    }
  }
}

/// 应用内资源拖进来仍是引用，应用外的图片作为内联附件。
class AgentResourceDropRegion extends ConsumerStatefulWidget {
  const AgentResourceDropRegion({
    super.key,
    required this.onDrop,
    required this.onDropImages,
    required this.child,
    this.enabled = true,
    this.readExternalImage = readExternalDropImage,
  });

  final Future<void> Function(AgentChatResourceReference reference) onDrop;
  final Future<void> Function(List<DroppedFileData> files) onDropImages;
  final Widget child;
  final bool enabled;
  final AgentChatExternalImageReader readExternalImage;

  @override
  ConsumerState<AgentResourceDropRegion> createState() =>
      _AgentResourceDropRegionState();
}

class _AgentResourceDropRegionState
    extends ConsumerState<AgentResourceDropRegion> {
  bool _hovering = false;
  bool _readingExternal = false;

  void _setHovering(bool value) {
    if (_hovering == value || !mounted) return;
    setState(() => _hovering = value);
  }

  void _setReadingExternal(bool value) {
    if (_readingExternal == value || !mounted) return;
    setState(() => _readingExternal = value);
  }

  DropOperation _onDropOver(DropOverEvent event) {
    final accepted =
        widget.enabled && AgentChatDropReader.accepts(event.session.items);
    _setHovering(accepted);
    return accepted ? DropOperation.copy : DropOperation.none;
  }

  Future<void> _onPerformDrop(PerformDropEvent event) async {
    _setHovering(false);
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final l10n = context.l10n;
    final items = List<DropItem>.unmodifiable(event.session.items);
    final reader = _dropReaderFor(items);
    _setReadingExternal(
      items.any((item) => !AgentChatDropReader.isInternal(item)),
    );
    try {
      final payloads = await reader.read(items);
      _setReadingExternal(false);
      final failures = await _addToComposer(payloads);
      if (failures.isNotEmpty) {
        _reportFailures(overlay, l10n, failures, items.length);
      }
    } catch (error, stack) {
      AppLogger.e('Agent resource drop failed', error, stack, 'CardDrag');
      AppToast.errorOnOverlay(overlay, '${l10n.common_error}: $error');
    } finally {
      _setReadingExternal(false);
    }
  }

  /// 数据库句柄在第一次 await 之前取好，读取途中面板卸载也不再碰 ref。
  AgentChatDropReader _dropReaderFor(List<DropItem> items) {
    final database =
        items.any(
          (item) => galleryInternalDragPathFromLocalData(item.localData) != null,
        )
        ? ref.read(databaseManagerProvider.future)
        : null;
    return AgentChatDropReader(
      galleryImageIdForPath: (path) async =>
          (await database!).galleryDataSource?.getImageIdByPath(path),
      readExternalImage: widget.readExternalImage,
    );
  }

  Future<List<({Object error, StackTrace stackTrace})>> _addToComposer(
    List<AgentChatDropPayload> payloads,
  ) async {
    final images = [
      for (final payload in payloads)
        if (payload is AgentChatDroppedImage) payload.file,
    ];
    final references = [
      for (final payload in payloads)
        if (payload is AgentChatDroppedResource) payload.reference,
    ];
    if (images.isNotEmpty) await widget.onDropImages(images);
    final added = await ImageCardBatchResult.execute(references, widget.onDrop);
    return [
      for (final payload in payloads)
        if (payload is AgentChatDropFailure)
          (error: payload.error, stackTrace: payload.stackTrace),
      ...added.failures.values,
    ];
  }

  void _reportFailures(
    OverlayState? overlay,
    AppLocalizations l10n,
    List<({Object error, StackTrace stackTrace})> failures,
    int total,
  ) {
    for (final failure in failures) {
      AppLogger.e(
        'Agent resource drop failed',
        failure.error,
        failure.stackTrace,
        'CardDrag',
      );
    }
    final reasons = {
      for (final failure in failures)
        failure.error is AgentChatUnreadableDropImage
            ? l10n.toast_unreadableDroppedImageSource
            : '${failure.error}',
    }.join('; ');
    AppToast.errorOnOverlay(
      overlay,
      '${l10n.common_error}: ${failures.length}/$total: $reasons',
    );
  }

  @override
  Widget build(BuildContext context) {
    return DropRegion(
      formats: cardDropFormats,
      onDropOver: _onDropOver,
      onDropLeave: (_) => _setHovering(false),
      onDropEnded: (_) => _setHovering(false),
      onPerformDrop: _onPerformDrop,
      // 提示层始终挂在同一个 Stack 里，悬停开关不能让整个对话面板换父节点重建。
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          widget.child,
          if (_hovering)
            GlobalDropOverlay(message: context.l10n.agentChat_dropHint),
          if (_readingExternal) const GlobalDropProcessingOverlay(),
        ],
      ),
    );
  }
}

class AgentResourceDragSource extends ConsumerWidget {
  const AgentResourceDragSource({
    super.key,
    required this.reference,
    required this.child,
    this.enableAddToAgentAction = true,
    this.selectionId,
    this.referenceForSelection,
  });

  final AgentChatResourceReference reference;
  final Widget child;
  final bool enableAddToAgentAction;
  final String? selectionId;
  final AgentChatResourceReference Function(String id)? referenceForSelection;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reference = this.reference;
    final factory = ref.watch(cardResourceDragFactoryProvider);
    final selection = CardSelectionScope.maybeOf(context);
    final currentId = selectionId ?? reference.resourceId;
    final dragSource = CardDragSource(
      resource: () => factory.create(reference, id: currentId),
      snapshot: (source) {
        final ids = selection == null
            ? [currentId]
            : CardSelection.targets(
                selection.selection,
                currentId,
                selection.orderedIds,
              );
        return [
          for (final id in ids)
            if (id == currentId)
              source
            else
              factory.create(
                referenceForSelection?.call(id) ??
                    AgentChatResourceReference(
                      kind: reference.kind,
                      source: reference.source,
                      resourceId: id,
                    ),
                id: id,
              ),
        ];
      },
      child: child,
    );
    if (!enableAddToAgentAction) return dragSource;

    return ImageCardActionScope(
      onAddToAgent: () => addAgentResourceToComposer(
        context: context,
        ref: ref,
        reference: reference,
      ),
      child: dragSource,
    );
  }
}
