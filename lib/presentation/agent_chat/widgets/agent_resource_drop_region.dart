import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/agent/resources/agent_chat_resource_drag_format.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../../core/utils/localization_extension.dart';
import '../providers/agent_chat_notifier.dart';

export '../../../core/agent/resources/agent_chat_resource_drag_format.dart';

Future<void> showAddAgentResourceMenu({
  required BuildContext context,
  required WidgetRef ref,
  required Offset position,
  required AgentChatResourceReference reference,
}) async {
  final selected = await showMenu<bool>(
    context: context,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      position.dx + 1,
      position.dy + 1,
    ),
    items: [
      PopupMenuItem<bool>(
        value: true,
        child: Row(
          children: [
            const Icon(Icons.auto_awesome_outlined, size: 18),
            const SizedBox(width: 8),
            Text(context.l10n.agentChat_addResource),
          ],
        ),
      ),
    ],
  );
  if (selected != true || !context.mounted) return;
  try {
    await ref
        .read(agentChatNotifierProvider.notifier)
        .addPendingResource(reference);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.agentChat_resourceAdded)),
      );
    }
  } on Object catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.agentChat_addResourceFailed('$error')),
        ),
      );
    }
  }
}

class AgentResourceDropRegion extends StatelessWidget {
  const AgentResourceDropRegion({
    super.key,
    required this.onDrop,
    required this.child,
  });

  final Future<void> Function(AgentChatResourceReference reference) onDrop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DropRegion(
      formats: [agentChatResourceDragFormat],
      onDropOver: (event) =>
          event.session.items.any(canReadAgentResourceDropItem)
          ? DropOperation.copy
          : DropOperation.none,
      onPerformDrop: (event) async {
        for (final item in event.session.items) {
          final reference = await readAgentResourceDropItem(item);
          if (reference != null) await onDrop(reference);
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
  });

  final AgentChatResourceReference reference;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reference = this.reference;
    return DragItemWidget(
      allowedOperations: () => [DropOperation.copy],
      dragItemProvider: (_) async {
        final item = DragItem(
          suggestedName:
              reference.display['name'] ?? reference.display['title'],
          localData: AgentChatResourceReferenceCodec.encodeJson(reference),
        );
        addAgentResourceDragPayload(item, reference);
        return item;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onSecondaryTapDown: (details) => showAddAgentResourceMenu(
          context: context,
          ref: ref,
          position: details.globalPosition,
          reference: reference,
        ),
        child: DraggableWidget(child: child),
      ),
    );
  }
}
