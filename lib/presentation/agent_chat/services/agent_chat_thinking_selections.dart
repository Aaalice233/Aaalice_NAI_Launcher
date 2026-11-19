import '../../../core/agent/agent_types.dart';
import '../../../core/agent/harness/session/session.dart';

const _modelDefault = 'agentChatModelDefault';

Map<(String, String), ThinkingLevel> restoreChatThinkingSelections(
  List<SessionEntry> branch,
  Model currentModel,
) {
  final selections = <(String, String), ThinkingLevel>{};
  final levels = ThinkingLevel.values.asNameMap();
  (String, String)? route;
  ThinkingLevel? pending;
  SessionEntry? parent;
  for (final entry in branch) {
    switch (entry) {
      case ModelChangeEntry(:final provider, :final modelId):
        if (pending != null && route != null) selections[route] = pending;
        pending = null;
        route = (provider, modelId);
      case ThinkingLevelEntry(:final thinkingLevel):
        final level = levels[thinkingLevel];
        if (parent is ModelChangeEntry &&
            parent.id == entry.parentId &&
            level != null &&
            route != null) {
          selections[route] = level;
        } else {
          // 旧档位记录没有路由，随后的助手回复才带有实际使用的渠道和模型。
          pending = level;
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
  ThinkingLevel? level,
) async {
  if (level == null) {
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
  await session.appendEntry(
    ThinkingLevelEntry(id: session.idGenerator(), thinkingLevel: level.name),
    'main',
  );
}
