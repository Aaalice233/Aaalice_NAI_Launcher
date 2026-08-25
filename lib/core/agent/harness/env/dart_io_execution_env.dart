import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:path/path.dart' as p;

import '../../agent_types.dart';
import '../harness_types.dart';

/// 基于 dart:io 的默认 ExecutionEnv。
class DartIoExecutionEnv implements ExecutionEnv {
  DartIoExecutionEnv({
    String? workingDirectory,
    this.allowOutsideWorkingDirectory = false,
  }) : cwd = p.normalize(workingDirectory ?? io.Directory.current.path);

  @override
  final String cwd;

  /// 仅供用户明确选择“完全访问”或应用内部技能发现使用。
  final bool allowOutsideWorkingDirectory;

  FileError _fsError(io.FileSystemException e, String? path) {
    final osError = e.osError?.errorCode ?? 0;
    final code = osError == 2
        ? FileErrorCode.notFound
        : osError == 13 || osError == 5
        ? FileErrorCode.permissionDenied
        : osError == 20 || osError == 32
        ? FileErrorCode.notDirectory
        : osError == 21
        ? FileErrorCode.isDirectory
        : FileErrorCode.unknown;
    return FileError(code, e.message, path);
  }

  String _normalize(String path) {
    final normalized = path.replaceAll('/', io.Platform.pathSeparator);
    return p.normalize(normalized);
  }

  bool _samePath(String left, String right) {
    if (io.Platform.isWindows) {
      return left.toLowerCase() == right.toLowerCase();
    }
    return left == right;
  }

  bool _isWithin(String root, String candidate) {
    if (_samePath(root, candidate)) {
      return true;
    }
    if (io.Platform.isWindows) {
      return p.isWithin(root.toLowerCase(), candidate.toLowerCase());
    }
    return p.isWithin(root, candidate);
  }

  Future<String> _canonicalizeForBoundary(String path) async {
    var existing = p.normalize(path);
    final missingParts = <String>[];
    while (io.FileSystemEntity.typeSync(existing, followLinks: false) ==
        io.FileSystemEntityType.notFound) {
      final parent = p.dirname(existing);
      if (_samePath(parent, existing)) {
        break;
      }
      missingParts.add(p.basename(existing));
      existing = parent;
    }

    var canonical = await io.File(existing).resolveSymbolicLinks();
    for (final part in missingParts.reversed) {
      canonical = p.join(canonical, part);
    }
    return p.normalize(canonical);
  }

  @override
  Future<HarnessResult<String, FileError>> absolutePath(
    String path, [
    AbortSignal? abortSignal,
  ]) async {
    try {
      final normalized = _normalize(path);
      final absolute = p.isAbsolute(normalized)
          ? normalized
          : _normalize('$cwd${io.Platform.pathSeparator}$normalized');
      final resolved = p.normalize(absolute);
      if (!allowOutsideWorkingDirectory) {
        final canonicalRoot = await _canonicalizeForBoundary(cwd);
        final canonicalCandidate = await _canonicalizeForBoundary(resolved);
        if (!_isWithin(canonicalRoot, canonicalCandidate)) {
          return err(
            FileError(
              FileErrorCode.permissionDenied,
              'Path is outside the configured workspace',
              path,
            ),
          );
        }
      }
      return ok(resolved);
    } catch (e) {
      return err(FileError(FileErrorCode.invalid, e.toString(), path));
    }
  }

  @override
  Future<HarnessResult<String, FileError>> joinPath(
    List<String> parts, [
    AbortSignal? abortSignal,
  ]) async {
    try {
      return ok(_normalize(parts.join(io.Platform.pathSeparator)));
    } catch (e) {
      return err(FileError(FileErrorCode.invalid, e.toString()));
    }
  }

  @override
  Future<HarnessResult<String, FileError>> readTextFile(
    String path, [
    AbortSignal? abortSignal,
  ]) async {
    try {
      return ok(await io.File(path).readAsString());
    } on io.FileSystemException catch (e) {
      return err(_fsError(e, path));
    }
  }

  @override
  Future<HarnessResult<List<String>, FileError>> readTextLines(
    String path, {
    int? maxLines,
    AbortSignal? abortSignal,
  }) async {
    try {
      final lines = <String>[];
      final file = io.File(path);
      final stream = file
          .openRead()
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (final line in stream) {
        lines.add(line);
        if (maxLines != null && lines.length >= maxLines) {
          break;
        }
      }
      return ok(lines);
    } on io.FileSystemException catch (e) {
      return err(_fsError(e, path));
    }
  }

  @override
  Future<HarnessResult<List<int>, FileError>> readBinaryFile(
    String path, [
    AbortSignal? abortSignal,
  ]) async {
    try {
      return ok(await io.File(path).readAsBytes());
    } on io.FileSystemException catch (e) {
      return err(_fsError(e, path));
    }
  }

  @override
  Future<HarnessResult<void, FileError>> writeFile(
    String path,
    Object content, [
    AbortSignal? abortSignal,
  ]) async {
    try {
      final file = io.File(path);
      await file.parent.create(recursive: true);
      if (content is String) {
        await file.writeAsString(content);
      } else if (content is List<int>) {
        await file.writeAsBytes(content);
      } else {
        return err(
          FileError(FileErrorCode.invalid, 'Unsupported content', path),
        );
      }
      return ok(null);
    } on io.FileSystemException catch (e) {
      return err(_fsError(e, path));
    }
  }

  @override
  Future<HarnessResult<void, FileError>> appendFile(
    String path,
    Object content, [
    AbortSignal? abortSignal,
  ]) async {
    try {
      final file = io.File(path);
      await file.parent.create(recursive: true);
      if (content is String) {
        await file.writeAsString(content, mode: io.FileMode.append);
      } else if (content is List<int>) {
        await file.writeAsBytes(content, mode: io.FileMode.append);
      } else {
        return err(
          FileError(FileErrorCode.invalid, 'Unsupported content', path),
        );
      }
      return ok(null);
    } on io.FileSystemException catch (e) {
      return err(_fsError(e, path));
    }
  }

  @override
  Future<HarnessResult<void, FileError>> renameFile(
    String sourcePath,
    String destinationPath, [
    AbortSignal? abortSignal,
  ]) async {
    try {
      await io.File(sourcePath).rename(destinationPath);
      return ok(null);
    } on io.FileSystemException catch (e) {
      return err(_fsError(e, sourcePath));
    }
  }

  @override
  Future<HarnessResult<FileInfo, FileError>> fileInfo(
    String path, [
    AbortSignal? abortSignal,
  ]) async {
    try {
      final type = io.FileSystemEntity.typeSync(path, followLinks: false);
      final stat = io.FileStat.statSync(path);
      if (type == io.FileSystemEntityType.notFound) {
        return err(FileError(FileErrorCode.notFound, 'Not found', path));
      }
      final kind = switch (type) {
        io.FileSystemEntityType.file => FileKind.file,
        io.FileSystemEntityType.directory => FileKind.directory,
        io.FileSystemEntityType.link => FileKind.symlink,
        _ => FileKind.file,
      };
      return ok(
        FileInfo(
          name: path.split(io.Platform.pathSeparator).last,
          path: path,
          kind: kind,
          size: stat.size,
          mtimeMs: stat.modified.millisecondsSinceEpoch,
        ),
      );
    } on io.FileSystemException catch (e) {
      return err(_fsError(e, path));
    }
  }

  @override
  Future<HarnessResult<List<FileInfo>, FileError>> listDir(
    String path, [
    AbortSignal? abortSignal,
  ]) async {
    try {
      final dir = io.Directory(path);
      final results = <FileInfo>[];
      await for (final entity in dir.list(followLinks: false)) {
        final type = io.FileSystemEntity.typeSync(
          entity.path,
          followLinks: false,
        );
        final kind = switch (type) {
          io.FileSystemEntityType.file => FileKind.file,
          io.FileSystemEntityType.directory => FileKind.directory,
          io.FileSystemEntityType.link => FileKind.symlink,
          _ => FileKind.file,
        };
        final stat = io.FileStat.statSync(entity.path);
        results.add(
          FileInfo(
            name: entity.path.split(io.Platform.pathSeparator).last,
            path: entity.path,
            kind: kind,
            size: stat.size,
            mtimeMs: stat.modified.millisecondsSinceEpoch,
          ),
        );
      }
      return ok(results);
    } on io.FileSystemException catch (e) {
      return err(_fsError(e, path));
    }
  }

  @override
  Future<HarnessResult<String, FileError>> canonicalPath(
    String path, [
    AbortSignal? abortSignal,
  ]) async {
    try {
      // 不存在的路径（write 新建文件场景）必须显式返回 notFound，
      // 供 mutation queue 回退到 absolutePath；resolveSymbolicLinks 在
      // Windows 上对缺失路径抛出的异常缺少 errno，无法靠 _fsError 判别。
      final type = io.FileSystemEntity.typeSync(path, followLinks: false);
      if (type == io.FileSystemEntityType.notFound) {
        return err(
          FileError(FileErrorCode.notFound, 'Path does not exist', path),
        );
      }
      return ok(await io.File(path).resolveSymbolicLinks());
    } on io.FileSystemException catch (e) {
      return err(_fsError(e, path));
    }
  }

  @override
  Future<HarnessResult<bool, FileError>> exists(
    String path, [
    AbortSignal? abortSignal,
  ]) async {
    try {
      return ok(
        io.FileSystemEntity.typeSync(path, followLinks: false) !=
            io.FileSystemEntityType.notFound,
      );
    } on io.FileSystemException catch (e) {
      return err(_fsError(e, path));
    }
  }

  @override
  Future<HarnessResult<void, FileError>> createDir(
    String path, {
    bool recursive = true,
    AbortSignal? abortSignal,
  }) async {
    try {
      await io.Directory(path).create(recursive: recursive);
      return ok(null);
    } on io.FileSystemException catch (e) {
      return err(_fsError(e, path));
    }
  }

  @override
  Future<HarnessResult<void, FileError>> remove(
    String path, {
    bool recursive = false,
    bool force = false,
    AbortSignal? abortSignal,
  }) async {
    try {
      final type = io.FileSystemEntity.typeSync(path, followLinks: false);
      if (type == io.FileSystemEntityType.notFound) {
        if (force) {
          return ok(null);
        }
        return err(FileError(FileErrorCode.notFound, 'Not found', path));
      }
      if (type == io.FileSystemEntityType.directory) {
        await io.Directory(path).delete(recursive: recursive);
      } else {
        await io.File(path).delete();
      }
      return ok(null);
    } on io.FileSystemException catch (e) {
      return err(_fsError(e, path));
    }
  }

  @override
  Future<HarnessResult<String, FileError>> createTempDir([
    String? prefix,
    AbortSignal? abortSignal,
  ]) async {
    try {
      final dir = await io.Directory.systemTemp.createTemp(prefix ?? 'tmp-');
      return ok(dir.path);
    } on io.FileSystemException catch (e) {
      return err(_fsError(e, null));
    }
  }

  @override
  Future<HarnessResult<String, FileError>> createTempFile({
    String? prefix,
    String? suffix,
    AbortSignal? abortSignal,
  }) async {
    try {
      final dir = await io.Directory.systemTemp.createTemp(prefix ?? '');
      final name =
          '${dir.path}${io.Platform.pathSeparator}output'
          '${suffix ?? ''}';
      await io.File(name).create();
      return ok(name);
    } on io.FileSystemException catch (e) {
      return err(_fsError(e, null));
    }
  }

  @override
  Future<void> cleanup() async {}

  // -------------------------------------------------------------------------
  // Shell
  // -------------------------------------------------------------------------

  @override
  Future<HarnessResult<ShellExecResult, ExecutionError>> exec(
    String command, [
    ShellExecOptions? options,
  ]) async {
    final opts = options ?? const ShellExecOptions();
    final isWindows = io.Platform.isWindows;
    final executable = isWindows ? 'cmd.exe' : '/bin/bash';
    // Windows cmd 默认输出系统 ANSI 代码页（如中文系统的 GBK），先切到
    // UTF-8 再执行用户命令，保证下游 UTF-8 解码不乱码；`&` 保证 chcp
    // 失败也不影响命令本身执行。
    final shellCommand = isWindows ? 'chcp 65001 > nul & $command' : command;
    final arguments = isWindows ? ['/c', shellCommand] : ['-c', command];

    final environment = <String, String>{};
    if (opts.inheritEnv) {
      environment.addAll(io.Platform.environment);
    }
    environment.addAll(opts.env ?? const {});

    try {
      final process = await io.Process.start(
        executable,
        arguments,
        workingDirectory: opts.cwd ?? cwd,
        environment: environment,
      );

      var timedOut = false;
      Timer? timeoutTimer;
      if (opts.timeout != null) {
        timeoutTimer = Timer(Duration(seconds: opts.timeout!), () {
          timedOut = true;
          process.kill(io.ProcessSignal.sigkill);
        });
      }
      opts.abortSignal?.addListener((_) {
        process.kill(io.ProcessSignal.sigkill);
      });

      // allowMalformed：非 UTF-8 字节（未切码页的本地化输出）降级为替换
      // 字符而不是抛 FormatException 丢掉整条流。
      const decoder = Utf8Decoder(allowMalformed: true);
      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();
      final stdoutSub = process.stdout
          .transform(decoder)
          .transform(const LineSplitter())
          .listen((line) {
            stdoutBuffer.writeln(line);
            opts.onStdout?.call('$line\n');
          });
      final stderrSub = process.stderr
          .transform(decoder)
          .transform(const LineSplitter())
          .listen((line) {
            stderrBuffer.writeln(line);
            opts.onStderr?.call('$line\n');
          });

      final exitCode = await process.exitCode;
      timeoutTimer?.cancel();
      await stdoutSub.cancel();
      await stderrSub.cancel();

      if (timedOut) {
        return err(
          ExecutionError(
            ExecutionErrorCode.timeout,
            'Command timed out after ${opts.timeout} seconds',
          ),
        );
      }
      if (opts.abortSignal?.aborted == true) {
        return err(
          ExecutionError(ExecutionErrorCode.aborted, 'Command aborted'),
        );
      }
      return ok(
        ShellExecResult(
          stdout: stdoutBuffer.toString(),
          stderr: stderrBuffer.toString(),
          exitCode: exitCode,
        ),
      );
    } on io.ProcessException catch (e) {
      return err(ExecutionError(ExecutionErrorCode.spawnError, e.toString()));
    } catch (e) {
      return err(ExecutionError(ExecutionErrorCode.unknown, e.toString()));
    }
  }
}
