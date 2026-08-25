import 'harness_types.dart';

///
/// npm 依赖的 Dart 等价物：
/// - `ignore` → [_IgnoreMatcher]（gitignore 模式子集：字面量、* 通配、
///   目录前缀、取反）；
/// - `yaml` → [_parseFrontmatterYaml]（扁平 key: value 子集，Skill
///   frontmatter 的全部字段形态）。

const int _maxNameLength = 64;
const int _maxDescriptionLength = 1024;
const List<String> _ignoreFileNames = ['.gitignore', '.ignore', '.fdignore'];

enum SkillDiagnosticCode {
  fileInfoFailed,
  listFailed,
  readFailed,
  parseFailed,
  invalidMetadata,
}

/// 加载 skills 时产生的告警。
class SkillDiagnostic {
  const SkillDiagnostic({
    required this.code,
    required this.message,
    required this.path,
  });

  final SkillDiagnosticCode code;
  final String message;
  final String path;
}

/// 格式化 skill 调用提示词，可选附加用户指令。
String formatSkillInvocation(
  HarnessSkill skill,
  String? additionalInstructions,
) {
  final skillBlock =
      '<skill name="${skill.name}" location="${skill.filePath}">\n'
      'References are relative to ${_dirnameEnvPath(skill.filePath)}.\n\n'
      '${skill.content}\n</skill>';
  return additionalInstructions == null || additionalInstructions.isEmpty
      ? skillBlock
      : '$skillBlock\n\n$additionalInstructions';
}

/// 从一个或多个目录加载 skills。
///
/// 递归遍历目录、加载 `SKILL.md`、加载带 skill frontmatter 的根级直接
/// `.md` 文件、遵循 ignore 文件、对无效的声明式 skill 文件返回诊断。
/// 输入目录缺失时跳过。
Future<({List<HarnessSkill> skills, List<SkillDiagnostic> diagnostics})>
loadSkills(ExecutionEnv env, Object dirs) async {
  final skills = <HarnessSkill>[];
  final diagnostics = <SkillDiagnostic>[];
  final dirList = dirs is List<String> ? dirs : [dirs as String];
  for (final dir in dirList) {
    final rootInfoResult = await env.fileInfo(dir);
    final rootInfo = rootInfoResult.valueOrNull;
    if (rootInfo == null) {
      final error = rootInfoResult.errorOrNull;
      if (error != null && error.code != FileErrorCode.notFound) {
        diagnostics.add(
          SkillDiagnostic(
            code: SkillDiagnosticCode.fileInfoFailed,
            message: error.message,
            path: dir,
          ),
        );
      }
      continue;
    }
    if (await _resolveKind(env, rootInfo, diagnostics) != FileKind.directory) {
      continue;
    }
    final result = await _loadSkillsFromDirInternal(
      env,
      rootInfo.path,
      true,
      _IgnoreMatcher(),
      rootInfo.path,
    );
    skills.addAll(result.skills);
    diagnostics.addAll(result.diagnostics);
  }
  return (skills: skills, diagnostics: diagnostics);
}

/// 从带来源标签的目录加载 skills（来源原样透传）。
Future<
    ({
      List<({HarnessSkill skill, TSource source})> skills,
      List<({SkillDiagnostic diagnostic, TSource source})> diagnostics,
    })
>
loadSourcedSkills<TSource>(
  ExecutionEnv env,
  List<({String path, TSource source})> inputs,
) async {
  final skills = <({HarnessSkill skill, TSource source})>[];
  final diagnostics = <({SkillDiagnostic diagnostic, TSource source})>[];
  for (final input in inputs) {
    final result = await loadSkills(env, input.path);
    for (final skill in result.skills) {
      skills.add((skill: skill, source: input.source));
    }
    for (final diagnostic in result.diagnostics) {
      diagnostics.add((diagnostic: diagnostic, source: input.source));
    }
  }
  return (skills: skills, diagnostics: diagnostics);
}

Future<({List<HarnessSkill> skills, List<SkillDiagnostic> diagnostics})>
_loadSkillsFromDirInternal(
  ExecutionEnv env,
  String dir,
  bool includeRootFiles,
  _IgnoreMatcher ignoreMatcher,
  String rootDir,
) async {
  final skills = <HarnessSkill>[];
  final diagnostics = <SkillDiagnostic>[];

  final dirInfoResult = await env.fileInfo(dir);
  final dirInfo = dirInfoResult.valueOrNull;
  if (dirInfo == null) {
    final error = dirInfoResult.errorOrNull;
    if (error != null && error.code != FileErrorCode.notFound) {
      diagnostics.add(
        SkillDiagnostic(
          code: SkillDiagnosticCode.fileInfoFailed,
          message: error.message,
          path: dir,
        ),
      );
    }
    return (skills: skills, diagnostics: diagnostics);
  }
  if (await _resolveKind(env, dirInfo, diagnostics) != FileKind.directory) {
    return (skills: skills, diagnostics: diagnostics);
  }

  await _addIgnoreRules(env, ignoreMatcher, dir, rootDir, diagnostics);

  final entriesResult = await env.listDir(dir);
  final entries = entriesResult.valueOrNull;
  if (entries == null) {
    diagnostics.add(
      SkillDiagnostic(
        code: SkillDiagnosticCode.listFailed,
        message: entriesResult.errorOrNull!.message,
        path: dir,
      ),
    );
    return (skills: skills, diagnostics: diagnostics);
  }

  for (final entry in entries) {
    if (entry.name != 'SKILL.md') {
      continue;
    }
    final fullPath = entry.path;
    final kind = await _resolveKind(env, entry, diagnostics);
    if (kind != FileKind.file) {
      continue;
    }
    final relPath = _relativeEnvPath(rootDir, fullPath);
    if (ignoreMatcher.ignores(relPath)) {
      continue;
    }

    final result = await _loadSkillFromFile(env, fullPath, dirInfo.name);
    if (result.skill != null) {
      skills.add(result.skill!);
    }
    diagnostics.addAll(result.diagnostics);
    return (skills: skills, diagnostics: diagnostics);
  }

  final sortedEntries = List.of(entries)
    ..sort((a, b) => a.name.compareTo(b.name));
  for (final entry in sortedEntries) {
    if (entry.name.startsWith('.') || entry.name == 'node_modules') {
      continue;
    }
    final fullPath = entry.path;
    final kind = await _resolveKind(env, entry, diagnostics);
    if (kind == null) {
      continue;
    }

    final relPath = _relativeEnvPath(rootDir, fullPath);
    final ignorePath =
        kind == FileKind.directory ? '$relPath/' : relPath;
    if (ignoreMatcher.ignores(ignorePath)) {
      continue;
    }

    if (kind == FileKind.directory) {
      final result = await _loadSkillsFromDirInternal(
        env,
        fullPath,
        false,
        ignoreMatcher,
        rootDir,
      );
      skills.addAll(result.skills);
      diagnostics.addAll(result.diagnostics);
      continue;
    }

    if (kind != FileKind.file ||
        !includeRootFiles ||
        !entry.name.endsWith('.md')) {
      continue;
    }
    final result = await _loadSkillFromFile(env, fullPath, dirInfo.name);
    if (result.skill != null) {
      skills.add(result.skill!);
    }
    diagnostics.addAll(result.diagnostics);
  }

  return (skills: skills, diagnostics: diagnostics);
}

Future<void> _addIgnoreRules(
  ExecutionEnv env,
  _IgnoreMatcher ig,
  String dir,
  String rootDir,
  List<SkillDiagnostic> diagnostics,
) async {
  final relativeDir = _relativeEnvPath(rootDir, dir);
  final prefix = relativeDir.isEmpty ? '' : '$relativeDir/';

  for (final filename in _ignoreFileNames) {
    final ignorePathResult = await env.joinPath([dir, filename]);
    final ignorePath = ignorePathResult.valueOrNull;
    if (ignorePath == null) {
      diagnostics.add(
        SkillDiagnostic(
          code: SkillDiagnosticCode.fileInfoFailed,
          message: ignorePathResult.errorOrNull!.message,
          path: dir,
        ),
      );
      continue;
    }
    final info = await env.fileInfo(ignorePath);
    final infoValue = info.valueOrNull;
    if (infoValue == null) {
      final error = info.errorOrNull;
      if (error != null && error.code != FileErrorCode.notFound) {
        diagnostics.add(
          SkillDiagnostic(
            code: SkillDiagnosticCode.fileInfoFailed,
            message: error.message,
            path: ignorePath,
          ),
        );
      }
      continue;
    }
    if (infoValue.kind != FileKind.file) {
      continue;
    }
    final content = await env.readTextFile(ignorePath);
    final contentValue = content.valueOrNull;
    if (contentValue == null) {
      diagnostics.add(
        SkillDiagnostic(
          code: SkillDiagnosticCode.readFailed,
          message: content.errorOrNull!.message,
          path: ignorePath,
        ),
      );
      continue;
    }
    final patterns = contentValue
        .split(RegExp(r'\r?\n'))
        .map((line) => _prefixIgnorePattern(line, prefix))
        .whereType<String>()
        .toList();
    if (patterns.isNotEmpty) {
      ig.add(patterns);
    }
  }
}

String? _prefixIgnorePattern(String line, String prefix) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  if (trimmed.startsWith('#') && !trimmed.startsWith(r'\#')) {
    return null;
  }

  var pattern = line;
  var negated = false;
  if (pattern.startsWith('!')) {
    negated = true;
    pattern = pattern.substring(1);
  } else if (pattern.startsWith(r'\!')) {
    pattern = pattern.substring(1);
  }
  if (pattern.startsWith('/')) {
    pattern = pattern.substring(1);
  }
  final prefixed = prefix.isEmpty ? pattern : '$prefix$pattern';
  return negated ? '!$prefixed' : prefixed;
}

Future<({HarnessSkill? skill, List<SkillDiagnostic> diagnostics})>
_loadSkillFromFile(
  ExecutionEnv env,
  String filePath,
  String parentDirName,
) async {
  final diagnostics = <SkillDiagnostic>[];
  final isDeclaredSkill = filePath
          .replaceAll(RegExp(r'[\\/]+$'), '')
          .split(RegExp(r'[\\/]'))
          .last ==
      'SKILL.md';
  final rawContent = await env.readTextFile(filePath);
  final raw = rawContent.valueOrNull;
  if (raw == null) {
    diagnostics.add(
      SkillDiagnostic(
        code: SkillDiagnosticCode.readFailed,
        message: rawContent.errorOrNull!.message,
        path: filePath,
      ),
    );
    return (skill: null, diagnostics: diagnostics);
  }

  final parsed = _parseFrontmatter(raw);
  if (parsed == null) {
    if (isDeclaredSkill) {
      diagnostics.add(
        SkillDiagnostic(
          code: SkillDiagnosticCode.parseFailed,
          message: 'frontmatter is not valid YAML',
          path: filePath,
        ),
      );
    }
    return (skill: null, diagnostics: diagnostics);
  }

  final (frontmatter, body) = parsed;
  final description = frontmatter['description'] is String
      ? frontmatter['description'] as String
      : null;
  if (!isDeclaredSkill && (description == null || description.trim().isEmpty)) {
    return (skill: null, diagnostics: diagnostics);
  }

  for (final error in _validateDescription(description)) {
    diagnostics.add(
      SkillDiagnostic(
        code: SkillDiagnosticCode.invalidMetadata,
        message: error,
        path: filePath,
      ),
    );
  }

  final frontmatterName = frontmatter['name'] is String
      ? frontmatter['name'] as String
      : null;
  final name = frontmatterName ?? parentDirName;
  for (final error in _validateName(name, parentDirName)) {
    diagnostics.add(
      SkillDiagnostic(
        code: SkillDiagnosticCode.invalidMetadata,
        message: error,
        path: filePath,
      ),
    );
  }

  if (description == null || description.trim().isEmpty) {
    return (skill: null, diagnostics: diagnostics);
  }

  return (
    skill: HarnessSkill(
      name: name,
      description: description,
      content: body,
      filePath: filePath,
      disableModelInvocation:
          frontmatter['disable-model-invocation'] == true,
    ),
    diagnostics: diagnostics,
  );
}

List<String> _validateName(String name, String parentDirName) {
  final errors = <String>[];
  if (name != parentDirName) {
    errors.add('name "$name" does not match parent directory "$parentDirName"');
  }
  if (name.length > _maxNameLength) {
    errors.add(
      'name exceeds $_maxNameLength characters (${name.length})',
    );
  }
  if (!RegExp(r'^[a-z0-9-]+$').hasMatch(name)) {
    errors.add(
      'name contains invalid characters (must be lowercase a-z, 0-9, '
      'hyphens only)',
    );
  }
  if (name.startsWith('-') || name.endsWith('-')) {
    errors.add('name must not start or end with a hyphen');
  }
  if (name.contains('--')) {
    errors.add('name must not contain consecutive hyphens');
  }
  return errors;
}

List<String> _validateDescription(String? description) {
  final errors = <String>[];
  if (description == null || description.trim().isEmpty) {
    errors.add('description is required');
  } else if (description.length > _maxDescriptionLength) {
    errors.add(
      'description exceeds $_maxDescriptionLength characters '
      '(${description.length})',
    );
  }
  return errors;
}

/// 扁平 YAML frontmatter 子集解析（key: value）。
/// 返回 (frontmatter, body)；解析失败返回 null。
(Map<String, dynamic>, String)? _parseFrontmatter(String content) {
  try {
    final normalized = content
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    if (!normalized.startsWith('---')) {
      return (<String, dynamic>{}, normalized);
    }
    final endIndex = normalized.indexOf('\n---', 3);
    if (endIndex == -1) {
      return (<String, dynamic>{}, normalized);
    }
    final yamlString = normalized.substring(4, endIndex);
    final body = normalized.substring(endIndex + 4).trim();
    final frontmatter = <String, dynamic>{};
    for (final rawLine in yamlString.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) {
        continue;
      }
      final colon = line.indexOf(':');
      if (colon <= 0) {
        continue;
      }
      final key = line.substring(0, colon).trim();
      var value = line.substring(colon + 1).trim();
      if (value.length >= 2 &&
          ((value.startsWith('"') && value.endsWith('"')) ||
              (value.startsWith("'") && value.endsWith("'")))) {
        value = value.substring(1, value.length - 1);
      }
      if (value == 'true') {
        frontmatter[key] = true;
      } else if (value == 'false') {
        frontmatter[key] = false;
      } else {
        frontmatter[key] = value;
      }
    }
    return (frontmatter, body);
  } catch (_) {
    return null;
  }
}

Future<FileKind?> _resolveKind(
  ExecutionEnv env,
  FileInfo info,
  List<SkillDiagnostic> diagnostics,
) async {
  if (info.kind == FileKind.file || info.kind == FileKind.directory) {
    return info.kind;
  }
  final canonicalPath = await env.canonicalPath(info.path);
  final canonical = canonicalPath.valueOrNull;
  if (canonical == null) {
    final error = canonicalPath.errorOrNull;
    if (error != null && error.code != FileErrorCode.notFound) {
      diagnostics.add(
        SkillDiagnostic(
          code: SkillDiagnosticCode.fileInfoFailed,
          message: error.message,
          path: info.path,
        ),
      );
    }
    return null;
  }
  final target = await env.fileInfo(canonical);
  final targetValue = target.valueOrNull;
  if (targetValue == null) {
    final error = target.errorOrNull;
    if (error != null && error.code != FileErrorCode.notFound) {
      diagnostics.add(
        SkillDiagnostic(
          code: SkillDiagnosticCode.fileInfoFailed,
          message: error.message,
          path: info.path,
        ),
      );
    }
    return null;
  }
  return targetValue.kind == FileKind.file ||
          targetValue.kind == FileKind.directory
      ? targetValue.kind
      : null;
}

String _dirnameEnvPath(String path) {
  final normalized = path.replaceAll(RegExp(r'[\\/]+$'), '');
  final separatorIndex = normalized.lastIndexOf('/') >=
          normalized.lastIndexOf('\\')
      ? normalized.lastIndexOf('/')
      : normalized.lastIndexOf('\\');
  if (separatorIndex == 2 && normalized.length > 1 && normalized[1] == ':') {
    return normalized.substring(0, 3);
  }
  return separatorIndex <= 0 ? '/' : normalized.substring(0, separatorIndex);
}

String _relativeEnvPath(String root, String path) {
  final normalizedRoot = root.replaceAll('\\', '/').replaceAll(RegExp(r'/+$'), '');
  final normalizedPath = path
      .replaceAll('\\', '/')
      .replaceAll(RegExp(r'/+$'), '');
  if (normalizedPath == normalizedRoot) {
    return '';
  }
  return normalizedPath.startsWith('$normalizedRoot/')
      ? normalizedPath.substring(normalizedRoot.length + 1)
      : normalizedPath.replaceFirst(RegExp(r'^/+'), '');
}

/// gitignore 模式子集匹配器。
class _IgnoreMatcher {
  final List<({bool negated, RegExp pattern})> _rules = [];

  void add(List<String> patterns) {
    for (final pattern in patterns) {
      var negated = false;
      var source = pattern;
      if (source.startsWith('!')) {
        negated = true;
        source = source.substring(1);
      }
      if (source.startsWith('/')) {
        source = source.substring(1);
      }
      final dirOnly = source.endsWith('/');
      if (dirOnly) {
        source = source.substring(0, source.length - 1);
      }
      var regex = '';
      for (var i = 0; i < source.length; i++) {
        final char = source[i];
        if (char == '*') {
          regex += '[^/]*';
        } else if (char == '?') {
          regex += '[^/]';
        } else {
          regex += RegExp.escape(char);
        }
      }
      _rules.add((
        negated: negated,
        pattern: RegExp('^$regex\$|^$regex/'),
      ));
    }
  }

  bool ignores(String path) {
    if (path.isEmpty) {
      return false;
    }
    var ignored = false;
    for (final rule in _rules) {
      if (rule.pattern.hasMatch(path)) {
        ignored = !rule.negated;
      }
    }
    return ignored;
  }
}
