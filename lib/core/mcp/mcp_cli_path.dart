import 'dart:io';

import 'package:path/path.dart' as p;

const String _mcpCliBaseName = 'nai_launcher_mcp';

/// Absolute path of the stdio proxy shipped next to the app executable.
String resolveBundledMcpCliPath({String? executablePath, bool? isWindows}) {
  final windows = isWindows ?? Platform.isWindows;
  final context = windows ? p.windows : p.posix;
  final host = executablePath ?? Platform.resolvedExecutable;
  final name = windows ? '$_mcpCliBaseName.exe' : _mcpCliBaseName;
  return context.join(context.dirname(host), name);
}

/// Whether the bundled proxy is present; false during development runs.
bool bundledMcpCliExists({String? executablePath, bool? isWindows}) {
  return File(
    resolveBundledMcpCliPath(
      executablePath: executablePath,
      isWindows: isWindows,
    ),
  ).existsSync();
}
