import '../../agent_types.dart';
import 'bash.dart';
import 'edit.dart';
import 'read.dart';
import 'write.dart';

export 'bash.dart';
export 'edit.dart';
export 'edit_diff.dart';
export 'file_mutation_queue.dart';
export 'image.dart';
export 'path_utils.dart';
export 'read.dart';
export 'write.dart';

///
/// 创建默认执行工具集（read/bash/edit/write）。
List<AgentTool> createExecutionTools({
  ReadToolOptions? readOptions,
  BashToolOptions? bashOptions,
}) {
  return [
    createReadTool(readOptions),
    createBashTool(bashOptions),
    createEditTool(),
    createWriteTool(),
  ];
}
