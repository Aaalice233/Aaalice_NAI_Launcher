// Utilities for checking whether a ComfyUI workflow can run in the connected
// server before submitting it to `/prompt`.
Set<String> extractWorkflowNodeTypes(Map<String, dynamic> workflow) {
  final nodeTypes = <String>{};
  for (final node in workflow.values) {
    if (node is! Map) continue;
    final classType = node['class_type'];
    if (classType is String && classType.trim().isNotEmpty) {
      nodeTypes.add(classType.trim());
    }
  }
  return nodeTypes;
}

List<String> findMissingWorkflowNodeTypes({
  required Map<String, dynamic> workflow,
  required Map<String, dynamic> objectInfo,
}) {
  final availableTypes = objectInfo.keys
      .map((key) => key.trim())
      .where((key) => key.isNotEmpty)
      .toSet();
  final missing = extractWorkflowNodeTypes(
    workflow,
  ).where((nodeType) => !availableTypes.contains(nodeType)).toList();
  missing.sort();
  return missing;
}

typedef MissingWorkflowNodeInput = ({
  String nodeId,
  String nodeType,
  String inputName,
});

List<MissingWorkflowNodeInput> findMissingWorkflowRequiredInputs({
  required Map<String, dynamic> workflow,
  required Map<String, dynamic> objectInfo,
}) {
  final missing = <MissingWorkflowNodeInput>[];

  for (final entry in workflow.entries) {
    final node = entry.value;
    if (node is! Map) continue;

    final nodeType = node['class_type'];
    final inputs = node['inputs'];
    if (nodeType is! String || inputs is! Map) continue;

    final nodeInfo = objectInfo[nodeType];
    if (nodeInfo is! Map) continue;
    final inputInfo = nodeInfo['input'];
    if (inputInfo is! Map) continue;
    final requiredInputs = inputInfo['required'];
    if (requiredInputs is! Map) continue;

    for (final inputName in requiredInputs.keys.whereType<String>()) {
      if (!inputs.containsKey(inputName)) {
        missing.add((
          nodeId: entry.key,
          nodeType: nodeType,
          inputName: inputName,
        ));
      }
    }
  }

  missing.sort((a, b) {
    final nodeComparison = a.nodeId.compareTo(b.nodeId);
    return nodeComparison != 0
        ? nodeComparison
        : a.inputName.compareTo(b.inputName);
  });
  return missing;
}

String formatMissingWorkflowNodeTypesMessage(List<String> missingNodeTypes) {
  final joined = missingNodeTypes.join(', ');
  return '缺少 ComfyUI 节点: $joined。请在 ComfyUI 中安装或启用对应自定义节点后重启 ComfyUI。';
}

String formatMissingWorkflowRequiredInputsMessage(
  List<MissingWorkflowNodeInput> missingInputs,
) {
  final joined = missingInputs
      .map(
        (missing) =>
            '节点 ${missing.nodeId} (${missing.nodeType}): ${missing.inputName}',
      )
      .join('；');
  return 'ComfyUI 工作流缺少必需输入：$joined。自定义节点可能已更新，请刷新启动器或更新工作流模板。';
}
