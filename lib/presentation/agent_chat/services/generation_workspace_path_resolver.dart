import '../../../core/agent/harness/env/dart_io_execution_env.dart';
import '../../../core/agent/harness/harness_result.dart';

class GenerationWorkspacePathResolver {
  GenerationWorkspacePathResolver({
    String? workspaceDir,
    bool allowOutsideWorkspace = false,
  }) : _fileEnv = DartIoExecutionEnv(
         workingDirectory: workspaceDir,
         allowOutsideWorkingDirectory: allowOutsideWorkspace,
       );

  final DartIoExecutionEnv _fileEnv;

  Future<String> resolveLocalImagePath(String rawPath) async {
    final result = await _fileEnv.absolutePath(rawPath);
    final resolved = result.valueOrNull;
    if (resolved == null) {
      throw StateError(result.errorOrNull?.message ?? 'Invalid image path');
    }
    return resolved;
  }
}
