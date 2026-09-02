import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../core/agent/resources/agent_chat_resource_drag_format.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../../core/utils/localization_extension.dart';
import '../providers/agent_chat_notifier.dart';
import '../../widgets/common/context_menu_anchor.dart';

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

Future<void> showAddAgentResourceMenu({
  required BuildContext context,
  required WidgetRef ref,
  required Offset position,
  required AgentChatResourceReference reference,
}) async {
  final selected = await showMenu<bool>(
    context: context,
    position: contextMenuAnchorAt(context, position),
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
  await addAgentResourceToComposer(
    context: context,
    ref: ref,
    reference: reference,
  );
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
    this.enableAddToAgentMenu = true,
  });

  final AgentChatResourceReference reference;
  final Widget child;
  final bool enableAddToAgentMenu;

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
        // 必须抬起后弹菜单：按住时 push 会合成 touch 取消事件，令 DraggableWidget 整批重建闪烁
        onSecondaryTapUp: enableAddToAgentMenu
            ? (details) => showAddAgentResourceMenu(
                context: context,
                ref: ref,
                position: details.globalPosition,
                reference: reference,
              )
            : null,
        child: DraggableWidget(child: child),
      ),
    );
  }
}
