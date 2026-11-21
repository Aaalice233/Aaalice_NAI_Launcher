import '../../../core/agent/agent_types.dart';
import '../../../core/agent/harness/session/session.dart';

const _modelDefault = 'agentChatModelDefault';
const _reasoningFormat = 'agentChatReasoningFormat';

typedef ChatThinkingSelection = ({ThinkingLevel level, String? formatId});

Map<(String, String), ChatThinkingSelection> restoreChatThinkingSelections(
  List<SessionEntry> branch,
  Model currentModel,
) {
  final selections = <(String, String), ChatThinkingSelection>{};
  final levels = ThinkingLevel.values.asNameMap();
  (String, String)? route;
  ChatThinkingSelection? pending;
  SessionEntry? parent;
  for (final entry in branch) {
    switch (entry) {
      case ModelChangeEntry(:final provider, :final modelId):
        if (pending != null && route != null) selections[route] = pending;
        pending = null;
        route = (provider, modelId);
      case ThinkingLevelEntry(:final thinkingLevel):
        final level = levels[thinkingLevel];
        final formatId = switch (parent) {
          CustomEntry(customType: _reasoningFormat, data: final String id) =>
            id,
          _ => null,
        };
        final selection = level == null
            ? null
            : (level: level, formatId: formatId);
        if ((parent is ModelChangeEntry || formatId != null) &&
            parent?.id == entry.parentId &&
            selection != null &&
            route != null) {
          selections[route] = selection;
        } else {
          // 旧档位记录没有路由，随后的助手回复才带有实际使用的渠道和模型。
          pending = selection;
        }
      case MessageEntry(
        message: AssistantMessage(
          provider: final provider?,
          model: final model?,
        ),
      ):
        route = (provider, model);
        if (pending != null) selections[route] = pending;
        pending = null;
      case CustomEntry(
        customType: _modelDefault,
        data: {'provider': final String provider, 'model': final String model},
      ):
        route = (provider, model);
        selections.remove(route);
        pending = null;
      default:
        break;
    }
    parent = entry;
  }
  if (pending != null) {
    selections[(currentModel.provider, currentModel.id)] = pending;
  }
  return selections;
}

Future<void> appendChatThinkingSelection(
  Session session,
  Model model,
  ChatThinkingSelection? selection,
) async {
  if (selection == null) {
    await session.appendCustomEntry(_modelDefault, {
      'provider': model.provider,
      'model': model.id,
    });
    return;
  }
  await session.appendEntry(
    ModelChangeEntry(
      id: session.idGenerator(),
      provider: model.provider,
      modelId: model.id,
    ),
    'main',
  );
  if (selection.formatId case final id?) {
    await session.appendCustomEntry(_reasoningFormat, id);
  }
  await session.appendEntry(
    ThinkingLevelEntry(
      id: session.idGenerator(),
      thinkingLevel: selection.level.name,
    ),
    'main',
  );
}
