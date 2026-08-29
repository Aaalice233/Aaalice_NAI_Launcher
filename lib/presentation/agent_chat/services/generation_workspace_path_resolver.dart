import 'dart:io';

import 'package:path/path.dart' as p;

import '../../../core/agent/harness/env/dart_io_execution_env.dart';
import '../../../core/agent/harness/harness_result.dart';

class GenerationWorkspacePathResolver {
  GenerationWorkspacePathResolver({
    String? workspaceDir,
    bool allowOutsideWorkspace = false,
  }) : _workspaceDir = p.normalize(
         p.absolute(workspaceDir ?? Directory.current.path),
       ),
       _fileEnv = DartIoExecutionEnv(
         workingDirectory: workspaceDir,
         allowOutsideWorkingDirectory: allowOutsideWorkspace,
       );

  final String _workspaceDir;
  final DartIoExecutionEnv _fileEnv;

  String? readableRelativePath(String filePath) {
    final absolutePath = p.normalize(
      p.isAbsolute(filePath) ? filePath : p.join(_workspaceDir, filePath),
    );
    if (!p.isWithin(_workspaceDir, absolutePath)) return null;
    return p.relative(absolutePath, from: _workspaceDir);
  }

  Future<String> resolveLocalImagePath(String rawPath) async {
    final result = await _fileEnv.absolutePath(rawPath);
    final resolved = result.valueOrNull;
    if (resolved == null) {
      throw StateError(result.errorOrNull?.message ?? 'Invalid image path');
    }
    return resolved;
  }
}
