import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../../../core/agent/harness/harness_types.dart';

/// Injectable boundary for exclusive image file writes.
typedef ResourceImageExclusiveWriter =
    Future<void> Function(String path, Uint8List bytes, String canonicalParent);

enum GeneratedImageExportFailureKind {
  invalidTarget,
  outsideScope,
  extensionMismatch,
  parentUnavailable,

  /// Parent directory exists but could not be canonicalized.
  parentUnresolvable,
  checkFailed,
  exists,

  /// Destination left the permitted scope after it was first resolved.
  unsafeChange,
  writeFailed,
}

final class GeneratedImageExportFailure {
  const GeneratedImageExportFailure(this.kind, {this.error});

  final GeneratedImageExportFailureKind kind;

  /// Set only when the caller should surface the concrete exception type.
  final Object? error;
}

final class GeneratedImageExportTarget {
  const GeneratedImageExportTarget({
    required this.absolutePath,
    required this.writePath,
    required this.canonicalParent,
  });

  /// Requested target resolved by the execution env, without symlink solving.
  final String absolutePath;

  /// Canonical parent joined with the requested basename.
  final String writePath;

  final String canonicalParent;
}

/// Validates explicit image export targets and writes them without overwriting.
final class GeneratedImageExportWriter {
  GeneratedImageExportWriter({
    required ExecutionEnv env,
    ResourceImageExclusiveWriter? exclusiveWriter,
  }) : _env = env,
       _exclusiveWriter = exclusiveWriter ?? _writeExclusive;

  final ExecutionEnv _env;
  final ResourceImageExclusiveWriter _exclusiveWriter;

  /// Checks basename, scope, extension and presence without touching disk.
  Future<HarnessResult<String, GeneratedImageExportFailure>> validate(
    String requestedPath, {
    required String mimeType,
  }) async {
    final resolved = await _resolveTarget(requestedPath, mimeType);
    if (resolved case HarnessErr<String, GeneratedImageExportFailure>()) {
      return resolved;
    }
    final absolutePath =
        (resolved as HarnessOk<String, GeneratedImageExportFailure>).value;

    final occupied = await _checkAbsent(absolutePath);
    return occupied == null ? ok(absolutePath) : err(occupied);
  }

  /// Runs the same checks as [validate], then creates and pins the parent.
  Future<HarnessResult<GeneratedImageExportTarget, GeneratedImageExportFailure>>
  prepareTarget(String requestedPath, {required String mimeType}) async {
    final resolved = await _resolveTarget(requestedPath, mimeType);
    if (resolved case HarnessErr<String, GeneratedImageExportFailure>(
      :final error,
    )) {
      return err(error);
    }
    final absolutePath =
        (resolved as HarnessOk<String, GeneratedImageExportFailure>).value;

    final parentResult = await _env.createDir(p.dirname(absolutePath));
    if (parentResult case HarnessErr<void, FileError>()) {
      return err(
        const GeneratedImageExportFailure(
          GeneratedImageExportFailureKind.parentUnavailable,
        ),
      );
    }

    final String writePath;
    final String canonicalParent;
    try {
      canonicalParent = await Directory(
        p.dirname(absolutePath),
      ).resolveSymbolicLinks();
      final canonicalTarget = p.join(canonicalParent, p.basename(absolutePath));
      final canonicalResult = await _env.absolutePath(
        p.relative(canonicalTarget, from: _env.cwd),
      );
      if (canonicalResult case HarnessErr<String, FileError>()) {
        return err(
          const GeneratedImageExportFailure(
            GeneratedImageExportFailureKind.unsafeChange,
          ),
        );
      }
      writePath = (canonicalResult as HarnessOk<String, FileError>).value;
    } on FileSystemException {
      return err(
        const GeneratedImageExportFailure(
          GeneratedImageExportFailureKind.parentUnresolvable,
        ),
      );
    }

    final occupied = await _checkAbsent(writePath);
    if (occupied != null) return err(occupied);

    return ok(
      GeneratedImageExportTarget(
        absolutePath: absolutePath,
        writePath: writePath,
        canonicalParent: canonicalParent,
      ),
    );
  }

  /// Writes the prepared target exclusively; null means the bytes landed.
  Future<GeneratedImageExportFailure?> write(
    GeneratedImageExportTarget target,
    Uint8List bytes,
  ) async {
    try {
      await _exclusiveWriter(target.writePath, bytes, target.canonicalParent);
    } on _UnsafeDestinationChanged {
      return const GeneratedImageExportFailure(
        GeneratedImageExportFailureKind.unsafeChange,
      );
    } on FileSystemException {
      if (await File(target.writePath).exists()) {
        return const GeneratedImageExportFailure(
          GeneratedImageExportFailureKind.exists,
        );
      }
      return const GeneratedImageExportFailure(
        GeneratedImageExportFailureKind.writeFailed,
      );
    } on Object catch (error) {
      return GeneratedImageExportFailure(
        GeneratedImageExportFailureKind.writeFailed,
        error: error,
      );
    }
    return null;
  }

  /// Workspace targets are described relatively; external ones by name only.
  Map<String, dynamic> describeDestination(String absolutePath) {
    final root = p.normalize(_env.cwd);
    final target = p.normalize(absolutePath);
    final relative = p.relative(target, from: root);
    final inside =
        relative != '..' &&
        !p.isAbsolute(relative) &&
        !relative.startsWith('..${p.separator}');
    return inside
        ? {
            'destination_path': relative.replaceAll(p.separator, '/'),
            'destination_scope': 'workspace',
          }
        : {'file_name': p.basename(target), 'destination_scope': 'external'};
  }

  Future<HarnessResult<String, GeneratedImageExportFailure>> _resolveTarget(
    String requestedPath,
    String mimeType,
  ) async {
    final normalizedRequest = requestedPath.trim();
    final basename = p.basename(normalizedRequest);
    if (basename.isEmpty || basename == '.' || basename == '..') {
      return err(
        const GeneratedImageExportFailure(
          GeneratedImageExportFailureKind.invalidTarget,
        ),
      );
    }

    final absoluteResult = await _env.absolutePath(normalizedRequest);
    if (absoluteResult case HarnessErr<String, FileError>()) {
      return err(
        const GeneratedImageExportFailure(
          GeneratedImageExportFailureKind.outsideScope,
        ),
      );
    }
    final absolutePath = (absoluteResult as HarnessOk<String, FileError>).value;

    if (!_matchesExtension(absolutePath, mimeType)) {
      return err(
        const GeneratedImageExportFailure(
          GeneratedImageExportFailureKind.extensionMismatch,
        ),
      );
    }
    return ok(absolutePath);
  }

  Future<GeneratedImageExportFailure?> _checkAbsent(String path) async {
    final existsResult = await _env.exists(path);
    if (existsResult case HarnessErr<bool, FileError>()) {
      return const GeneratedImageExportFailure(
        GeneratedImageExportFailureKind.checkFailed,
      );
    }
    return (existsResult as HarnessOk<bool, FileError>).value
        ? const GeneratedImageExportFailure(
            GeneratedImageExportFailureKind.exists,
          )
        : null;
  }

  static bool _matchesExtension(String path, String mimeType) {
    final extension = p.extension(path).toLowerCase();
    final expected = switch (mimeType) {
      'image/jpeg' => const {'.jpg', '.jpeg'},
      'image/png' => const {'.png'},
      'image/gif' => const {'.gif'},
      'image/webp' => const {'.webp'},
      'image/bmp' => const {'.bmp'},
      _ => const <String>{},
    };
    return expected.contains(extension);
  }

  static Future<void> _writeExclusive(
    String path,
    Uint8List bytes,
    String canonicalParent,
  ) async {
    final file = File(path);
    RandomAccessFile? output;
    String? openedPath;
    try {
      await file.create(exclusive: true);
      output = await file.open(mode: FileMode.writeOnly);
      openedPath = await file.resolveSymbolicLinks();
      if (!p.equals(p.dirname(openedPath), canonicalParent)) {
        throw const _UnsafeDestinationChanged();
      }
      await output.writeFrom(bytes);
      await output.flush();
    } on Object {
      await output?.close();
      output = null;
      if (openedPath != null) {
        try {
          await File(openedPath).delete();
        } on Object {
          // Preserve the original write or boundary failure.
        }
      }
      rethrow;
    } finally {
      await output?.close();
    }
  }
}

final class _UnsafeDestinationChanged implements Exception {
  const _UnsafeDestinationChanged();
}
