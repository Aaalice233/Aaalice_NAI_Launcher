import 'defined_agent_tool.dart';

Map<String, dynamic> toolboxObject({
  Map<String, dynamic> properties = const {},
  List<String> required = const [],
}) => {
  'type': 'object',
  'properties': properties,
  'required': required,
  'additionalProperties': false,
};

List<String> toolboxStrings(dynamic value) =>
    (value as List? ?? const []).map((item) => item.toString()).toList();

DefinedAgentTool toolboxIdTool({
  required String name,
  required String label,
  required String description,
  required String idKey,
  required Future<bool> Function(String id) execute,
}) => DefinedAgentTool(
  name: name,
  label: label,
  description: description,
  parameters: toolboxObject(
    properties: {
      idKey: {'type': 'string', 'minLength': 1},
    },
    required: [idKey],
  ),
  executeFn: (_, params) async {
    final id = params[idKey] as String;
    final changed = await execute(id);
    return changed
        ? agentToolJsonResult({'ok': true, idKey: id})
        : agentToolError('not_found', '$label target was not found.');
  },
);
