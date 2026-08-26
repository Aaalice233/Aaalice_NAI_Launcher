import '../agent_types.dart';
import 'harness_result.dart';

/// 与 harness/system-prompt.ts。

export 'harness_result.dart';

// ---------------------------------------------------------------------------
// Skill / PromptTemplate / Resources
// ---------------------------------------------------------------------------

/// 从 `SKILL.md` 加载或应用提供的 Skill。
///
/// `name`、`description`、`filePath` 以 agentskills.io 建议的 XML 块
/// 注入系统提示词，见 [formatSkillsForSystemPrompt]。
class HarnessSkill {
  const HarnessSkill({
    required this.name,
    required this.description,
    required this.content,
    required this.filePath,
    this.disableModelInvocation,
  });

  /// 用于查找与模型可见列表的稳定名称。
  final String name;

  /// 何时使用该技能的简短模型可见描述。
  final String description;

  /// 完整技能指令。
  final String content;

  /// 技能文件绝对路径；用于模型可见位置与解析相对引用。
  final String filePath;

  /// 从模型可见列表排除，但保留显式应用调用能力。
  final bool? disableModelInvocation;
}

/// 可格式化为提示词、供显式调用的模板。
class HarnessPromptTemplate {
  const HarnessPromptTemplate({
    required this.name,
    this.description,
    required this.content,
  });

  /// 用于查找或应用命令路由的稳定模板名。
  final String name;

  /// 命令列表/自动补全的描述。
  final String? description;

  /// 模板内容。参数占位符由 formatPromptTemplateInvocation 格式化。
  final String content;
}

/// 显式调用方法与系统提示词回调可用的资源。
class AgentHarnessResources {
  const AgentHarnessResources({this.promptTemplates, this.skills});

  final List<HarnessPromptTemplate>? promptTemplates;
  final List<HarnessSkill>? skills;
}

/// 由 AgentHarness 执行、携带应用定义上下文的工具定义
/// 。
abstract class AgentHarnessTool extends AgentTool {
  const AgentHarnessTool({
    required super.name,
    required super.description,
    required super.parameters,
    required super.label,
  });

  Future<AgentToolResult> executeWithContext(
    String toolCallId,
    Map<String, dynamic> params,
    AbortSignal? signal,
    AgentToolUpdateCallback? onUpdate,
    dynamic context,
  );

  @override
  Future<AgentToolResult> execute(
    String toolCallId,
    Map<String, dynamic> params, [
    AbortSignal? signal,
    AgentToolUpdateCallback? onUpdate,
  ]) {
    return executeWithContext(
      toolCallId,
      params,
      signal,
      onUpdate,
      null,
    );
  }
}

// ---------------------------------------------------------------------------
// harness 维护的流选项
// ---------------------------------------------------------------------------

class AgentHarnessStreamOptions {
  const AgentHarnessStreamOptions({
    this.timeoutMs,
    this.maxRetries,
    this.maxRetryDelayMs,
    this.headers,
    this.metadata,
  });

  final int? timeoutMs;
  final int? maxRetries;
  final int? maxRetryDelayMs;
  final Map<String, String>? headers;
  final Map<String, dynamic>? metadata;
}

// ---------------------------------------------------------------------------
// 稳定错误码
// ---------------------------------------------------------------------------

enum FileErrorCode {
  aborted,
  notFound,
  permissionDenied,
  notDirectory,
  isDirectory,
  invalid,
  notSupported,
  unknown,
}

class FileError implements Exception {
  FileError(this.code, this.message, [this.path]);

  final FileErrorCode code;
  final String message;

  /// 与失败关联的绝对寻址路径（可用时）。
  final String? path;

  @override
  String toString() =>
      'FileError($code): $message${path == null ? '' : ' @ $path'}';
}

enum ExecutionErrorCode {
  aborted,
  timeout,
  shellUnavailable,
  spawnError,
  callbackError,
  unknown,
}

class ExecutionError implements Exception {
  ExecutionError(this.code, this.message);

  final ExecutionErrorCode code;
  final String message;

  @override
  String toString() => 'ExecutionError($code): $message';
}

enum CompactionErrorCode { aborted, summarizationFailed }

class CompactionError implements Exception {
  CompactionError(this.code, this.message);

  final CompactionErrorCode code;
  final String message;

  @override
  String toString() => 'CompactionError($code): $message';
}

enum BranchSummaryErrorCode { aborted, summarizationFailed }

class BranchSummaryError implements Exception {
  BranchSummaryError(this.code, this.message);

  final BranchSummaryErrorCode code;
  final String message;

  @override
  String toString() => 'BranchSummaryError($code): $message';
}

// ---------------------------------------------------------------------------
// FileSystem / Shell 能力接口
// ---------------------------------------------------------------------------

enum FileKind { file, directory, symlink }

class FileInfo {
  const FileInfo({
    required this.name,
    required this.path,
    required this.kind,
    required this.size,
    required this.mtimeMs,
  });

  /// path 的 basename。
  final String name;

  /// 执行环境中的绝对、语法归一化寻址路径。不解析 symlink。
  final String path;

  /// 对象种类。symlink 目标不被跟随。
  final FileKind kind;

  /// 寻址对象的字节大小。
  final int size;

  /// Unix 纪元以来的修改毫秒数。
  final int mtimeMs;
}

/// harness 使用的文件系统能力。
///
/// 传给方法的路径可以是绝对路径或相对 [cwd]。操作方法**绝不抛出**：
/// 一切文件系统失败（含意外后端失败）必须编码进返回的 Result。
typedef FileOp<T> = Future<HarnessResult<T, FileError>>;

abstract class FileSystem {
  /// 相对路径的工作目录。
  String get cwd;

  Future<HarnessResult<String, FileError>> absolutePath(
    String path, [
    AbortSignal? abortSignal,
  ]);

  Future<HarnessResult<String, FileError>> joinPath(
    List<String> parts, [
    AbortSignal? abortSignal,
  ]);

  Future<HarnessResult<String, FileError>> readTextFile(
    String path, [
    AbortSignal? abortSignal,
  ]);

  /// 读 UTF-8 文本行。实现应在读满 maxLines 行后停止。
  Future<HarnessResult<List<String>, FileError>> readTextLines(
    String path, {
    int? maxLines,
    AbortSignal? abortSignal,
  });

  Future<HarnessResult<List<int>, FileError>> readBinaryFile(
    String path, [
    AbortSignal? abortSignal,
  ]);

  Future<HarnessResult<void, FileError>> writeFile(
    String path,
    Object content, [
    AbortSignal? abortSignal,
  ]);

  Future<HarnessResult<void, FileError>> appendFile(
    String path,
    Object content, [
    AbortSignal? abortSignal,
  ]);

  /// 原子重命名文件，目标存在时替换。不跨文件系统复制。
  Future<HarnessResult<void, FileError>> renameFile(
    String sourcePath,
    String destinationPath, [
    AbortSignal? abortSignal,
  ]);

  Future<HarnessResult<FileInfo, FileError>> fileInfo(
    String path, [
    AbortSignal? abortSignal,
  ]);

  /// 列出目录直接子项，不跟随 symlink。
  Future<HarnessResult<List<FileInfo>, FileError>> listDir(
    String path, [
    AbortSignal? abortSignal,
  ]);

  /// 返回存在路径的规范路径，尽可能解析 symlink。
  Future<HarnessResult<String, FileError>> canonicalPath(
    String path, [
    AbortSignal? abortSignal,
  ]);

  /// 路径缺失返回 false；权限等其他失败返回 FileError。
  Future<HarnessResult<bool, FileError>> exists(
    String path, [
    AbortSignal? abortSignal,
  ]);

  Future<HarnessResult<void, FileError>> createDir(
    String path, {
    bool recursive = true,
    AbortSignal? abortSignal,
  });

  Future<HarnessResult<void, FileError>> remove(
    String path, {
    bool recursive = false,
    bool force = false,
    AbortSignal? abortSignal,
  });

  Future<HarnessResult<String, FileError>> createTempDir([
    String? prefix,
    AbortSignal? abortSignal,
  ]);

  Future<HarnessResult<String, FileError>> createTempFile({
    String? prefix,
    String? suffix,
    AbortSignal? abortSignal,
  });

  /// 释放文件系统资源。必须尽力而为且不得抛出。
  Future<void> cleanup();
}

class ShellExecResult {
  const ShellExecResult({
    required this.stdout,
    required this.stderr,
    required this.exitCode,
  });

  final String stdout;
  final String stderr;
  final int exitCode;
}

class ShellExecOptions {
  const ShellExecOptions({
    this.cwd,
    this.env,
    this.inheritEnv = true,
    this.timeout,
    this.abortSignal,
    this.onStdout,
    this.onStderr,
  });

  /// 命令工作目录；相对路径按 ExecutionEnv.cwd 解析。
  final String? cwd;

  /// 命令环境变量；inheritEnv 为 true 时覆盖继承默认值。
  final Map<String, String>? env;

  /// 是否继承执行环境默认变量。默认 true。
  final bool inheritEnv;

  /// 超时秒数。默认无超时。
  final int? timeout;

  final AbortSignal? abortSignal;
  final void Function(String chunk)? onStdout;
  final void Function(String chunk)? onStderr;
}

/// harness 使用的 shell 执行能力。
abstract class Shell {
  Future<HarnessResult<ShellExecResult, ExecutionError>> exec(
    String command, [
    ShellExecOptions? options,
  ]);

  /// 释放资源。必须尽力而为且不得抛出。
  Future<void> cleanup();
}

/// harness 使用的文件系统与进程执行环境
/// 。
abstract class ExecutionEnv implements FileSystem, Shell {}

// ---------------------------------------------------------------------------
// 系统提示词中的 skills 清单渲染
// ---------------------------------------------------------------------------

String formatSkillsForSystemPrompt(List<HarnessSkill> skills) {
  final visibleSkills = skills
      .where((skill) => skill.disableModelInvocation != true)
      .toList();
  if (visibleSkills.isEmpty) {
    return '';
  }

  final lines = [
    'The following skills provide specialized instructions for specific tasks.',
    'Read the full skill file when the task matches its description.',
    'When a skill file references a relative path, resolve it against the '
        'skill directory (parent of SKILL.md / dirname of the path) and use '
        'that absolute path in tool commands.',
    '',
    '<available_skills>',
  ];

  for (final skill in visibleSkills) {
    lines.add('  <skill>');
    lines.add('    <name>${_escapeXml(skill.name)}</name>');
    lines.add('    <description>${_escapeXml(skill.description)}</description>');
    lines.add('    <location>${_escapeXml(skill.filePath)}</location>');
    lines.add('  </skill>');
  }

  lines.add('</available_skills>');
  return lines.join('\n');
}

String _escapeXml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
