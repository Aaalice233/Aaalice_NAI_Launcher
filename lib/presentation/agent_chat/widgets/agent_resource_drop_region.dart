import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/agent/resources/agent_chat_resource_drag_format.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/database/database_providers.dart';
import '../../widgets/common/app_toast.dart';
import '../providers/agent_chat_notifier.dart';
import '../../widgets/common/image_card_actions.dart';
import '../../widgets/common/card_drag_source.dart';
import '../../selection/card_selection.dart';
import '../../selection/card_selection_scope.dart';
import '../../utils/card_resource_drag_factory.dart';
import '../../utils/card_drag_format.dart';
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

class AgentResourceDropRegion extends ConsumerWidget {
  const AgentResourceDropRegion({
    super.key,
    required this.onDrop,
    required this.child,
  });

  final Future<void> Function(AgentChatResourceReference reference) onDrop;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DropRegion(
      formats: [agentChatResourceDragFormat, cardDragFormat],
      onDropOver: (event) =>
          event.session.items.isNotEmpty &&
              event.session.items.every(
                (item) =>
                    canReadAgentResourceDropItem(item) ||
                    galleryInternalDragPathFromLocalData(item.localData) !=
                        null,
              )
          ? DropOperation.copy
          : DropOperation.none,
      onPerformDrop: (event) async {
        final overlay = Overlay.maybeOf(context, rootOverlay: true);
        final errorLabel = context.l10n.common_error;
        final localPaths = event.session.items
            .map((item) => galleryInternalDragPathFromLocalData(item.localData))
            .toList();
        final database = localPaths.any((path) => path != null)
            ? ref.read(databaseManagerProvider.future)
            : null;
        try {
          final decoded = await Future.wait(
            event.session.items.map(readAgentResourceDropItem),
          );
          final references = <AgentChatResourceReference>[];
          for (var index = 0; index < event.session.items.length; index++) {
            var reference = decoded[index];
            final path = localPaths[index];
            if (reference == null && path != null) {
              final source = (await database!).galleryDataSource;
              final id = await source?.getImageIdByPath(path);
              if (id != null) {
                reference = AgentChatResourceReference(
                  kind: AgentChatResourceKind.localGalleryImage,
                  source: 'local_gallery',
                  resourceId: id.toString(),
                );
              }
            }
            if (reference == null) {
              throw StateError(
                'Unsupported or unavailable Agent resource at ${index + 1}',
              );
            }
            references.add(reference);
          }
          final result = await ImageCardBatchResult.execute(references, onDrop);
          if (result.failures.isNotEmpty) {
            for (final failure in result.failures.values) {
              AppLogger.e(
                'Agent resource drop failed',
                failure.error,
                failure.stackTrace,
                'CardDrag',
              );
            }
            throw StateError(
              '${result.failures.length}/${references.length}: ${result.failures.values.map((failure) => failure.error).join('; ')}',
            );
          }
        } catch (error, stack) {
          AppLogger.e('Agent resource drop failed', error, stack, 'CardDrag');
          AppToast.errorOnOverlay(overlay, '$errorLabel: $error');
        }
      },
      child: child,
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
