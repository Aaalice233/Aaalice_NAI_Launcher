import '../../abort_signal.dart';
import '../harness_types.dart';

/// 与 harness/tools/tool-context.ts。

final RegExp _unicodeSpaces = RegExp(
  r'[\u00A0\u2000-\u200A\u202F\u205F\u3000]',
);
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
]) => resolveToolPath(env, path, signal);

/// 内置执行工具所需的文件系统与 shell 上下文
/// 。
class ExecutionToolContext {
  const ExecutionToolContext({required this.env});

  final ExecutionEnv env;
}
