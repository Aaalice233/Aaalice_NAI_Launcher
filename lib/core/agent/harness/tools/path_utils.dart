import '../../abort_signal.dart';
import '../harness_types.dart';

/// 与 harness/tools/tool-context.ts。

final RegExp _unicodeSpaces = RegExp(
  r'[\u00A0\u2000-\u200A\u202F\u205F\u3000]',
);
const String _narrowNoBreakSpace = '\u202F';

String normalizeToolPath(String path) {
  final normalized = path.replaceAllMapped(_unicodeSpaces, (_) => ' ');
  return normalized.startsWith('@') ? normalized.substring(1) : normalized;
}

Future<String> resolveToolPath(
  ExecutionEnv env,
  String path, [
  AbortSignal? signal,
]) async {
  return getOrThrow(await env.absolutePath(normalizeToolPath(path), signal));
}

Future<String> resolveReadToolPath(
  ExecutionEnv env,
  String path, [
  AbortSignal? signal,
]) async {
  final resolved = await resolveToolPath(env, path, signal);
  final variants = <String>[
    resolved,
    resolved.replaceAllMapped(
      RegExp(r' (AM|PM)\.', caseSensitive: false),
      (m) => '$_narrowNoBreakSpace${m[1]}.',
    ),
    resolved,
    resolved.replaceAll("'", '\u2019'),
    resolved.replaceAll("'", '\u2019'),
  ];

  final seen = <String>{};
  for (final variant in variants) {
    if (!seen.add(variant)) {
      continue;
    }
    if (getOrThrow(await env.exists(variant, signal))) {
      return variant;
    }
  }
  return resolved;
}

/// 内置执行工具所需的文件系统与 shell 上下文
/// 。
class ExecutionToolContext {
  const ExecutionToolContext({required this.env});

  final ExecutionEnv env;
}
