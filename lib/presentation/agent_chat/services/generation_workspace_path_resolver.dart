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
         workingDirectory: p.normalize(
           p.absolute(workspaceDir ?? Directory.current.path),
         ),
         allowOutsideWorkingDirectory: allowOutsideWorkspace,
       );

  final String _workspaceDir;
  final DartIoExecutionEnv _fileEnv;

  /// Returns the exact relative argument accepted by the `read` tool, but
  /// only after the same execution environment proves that the existing file
  /// resolves back to that path inside the configured workspace.
  Future<String?> readPathForExistingFile(String filePath) async {
    final absoluteResult = await _fileEnv.absolutePath(filePath);
    final absolutePath = absoluteResult.valueOrNull;
    if (absolutePath == null || !await File(absolutePath).exists()) return null;
    if (!p.isWithin(_workspaceDir, absolutePath)) return null;

    final relativePath = p.relative(absolutePath, from: _workspaceDir);
    final roundTripResult = await _fileEnv.absolutePath(relativePath);
    final roundTripPath = roundTripResult.valueOrNull;
    if (roundTripPath == null || !p.equals(roundTripPath, absolutePath)) {
      return null;
    }
    return relativePath;
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
