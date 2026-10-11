import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/harness/env/dart_io_execution_env.dart';
import 'package:nai_launcher/core/agent/harness/harness_types.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generated_image_export_writer.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('image-export-');
  });

  tearDown(() async {
    if (await workspace.exists()) {
      await workspace.delete(recursive: true);
    }
  });

  test('validate rejects targets that do not name a file', () async {
    final writer = _writer(workspace);

    for (final requested in ['', '   ', '.', '..', 'exports/..']) {
      final result = await writer.validate(requested, mimeType: 'image/png');
      expect(
        result.errorOrNull?.kind,
        GeneratedImageExportFailureKind.invalidTarget,
        reason: 'requested: "$requested"',
      );
    }
  });

  test('validate rejects traversal outside the workspace', () async {
    final result = await _writer(
      workspace,
    ).validate('../private-result.png', mimeType: 'image/png');

    expect(
      result.errorOrNull?.kind,
      GeneratedImageExportFailureKind.outsideScope,
    );
  });

  test('validate matches the extension against the image format', () async {
    final writer = _writer(workspace);

    final mismatch = await writer.validate('result.jpg', mimeType: 'image/png');
    expect(
      mismatch.errorOrNull?.kind,
      GeneratedImageExportFailureKind.extensionMismatch,
    );

    for (final accepted in ['result.jpg', 'result.JPEG']) {
      final result = await writer.validate(accepted, mimeType: 'image/jpeg');
      expect(result.errorOrNull, isNull, reason: 'accepted: $accepted');
    }
  });

  test('validate reports an existing destination', () async {
    await File(p.join(workspace.path, 'result.png')).writeAsString('user data');

    final result = await _writer(
      workspace,
    ).validate('result.png', mimeType: 'image/png');

    expect(result.errorOrNull?.kind, GeneratedImageExportFailureKind.exists);
  });

  test('validate returns the absolute target without touching disk', () async {
    final result = await _writer(
      workspace,
    ).validate('exports/result.png', mimeType: 'image/png');

    expect(result.valueOrNull, p.join(workspace.path, 'exports', 'result.png'));
    expect(
      await Directory(p.join(workspace.path, 'exports')).exists(),
      isFalse,
    );
  });

  test('validate surfaces a failed existence check', () async {
    final writer = GeneratedImageExportWriter(
      env: _ExistsFailureEnv(workingDirectory: workspace.path),
    );

    final result = await writer.validate('result.png', mimeType: 'image/png');

    expect(
      result.errorOrNull?.kind,
      GeneratedImageExportFailureKind.checkFailed,
    );
  });

  test('prepareTarget creates the parent and pins the write path', () async {
    final parent = Directory(p.join(workspace.path, 'exports'));

    final result = await _writer(
      workspace,
    ).prepareTarget('exports/result.png', mimeType: 'image/png');

    final target = result.valueOrNull!;
    expect(await parent.exists(), isTrue);
    expect(target.absolutePath, p.join(parent.path, 'result.png'));
    expect(target.canonicalParent, await parent.resolveSymbolicLinks());
    expect(target.writePath, p.join(target.canonicalParent, 'result.png'));
  });

  test('prepareTarget keeps the checks performed by validate', () async {
    final writer = _writer(workspace);

    final invalid = await writer.prepareTarget('..', mimeType: 'image/png');
    expect(
      invalid.errorOrNull?.kind,
      GeneratedImageExportFailureKind.invalidTarget,
    );
    expect(await workspace.list().isEmpty, isTrue);
  });

  test('prepareTarget reports a parent that cannot be created', () async {
    await File(p.join(workspace.path, 'blocker')).writeAsString('user data');

    final result = await _writer(
      workspace,
    ).prepareTarget('blocker/result.png', mimeType: 'image/png');

    expect(
      result.errorOrNull?.kind,
      GeneratedImageExportFailureKind.parentUnavailable,
    );
  });

  test('prepareTarget reports a parent that cannot be resolved', () async {
    final writer = GeneratedImageExportWriter(
      env: _SkippedCreateDirEnv(workingDirectory: workspace.path),
    );

    final result = await writer.prepareTarget(
      'exports/result.png',
      mimeType: 'image/png',
    );

    expect(
      result.errorOrNull?.kind,
      GeneratedImageExportFailureKind.parentUnresolvable,
    );
  });

  test('write stores the bytes at the prepared target', () async {
    final writer = _writer(workspace);
    final target = (await writer.prepareTarget(
      'exports/result.png',
      mimeType: 'image/png',
    )).valueOrNull!;

    final failure = await writer.write(target, _bytes);

    expect(failure, isNull);
    expect(await File(target.writePath).readAsBytes(), _bytes);
  });

  test('write rejects a parent that no longer matches the target', () async {
    final elsewhere = await Directory.systemTemp.createTemp(
      'image-export-alt-',
    );
    addTearDown(() async {
      if (await elsewhere.exists()) await elsewhere.delete(recursive: true);
    });
    final writer = _writer(workspace);
    final prepared = (await writer.prepareTarget(
      'result.png',
      mimeType: 'image/png',
    )).valueOrNull!;

    final failure = await writer.write(
      GeneratedImageExportTarget(
        absolutePath: prepared.absolutePath,
        writePath: prepared.writePath,
        canonicalParent: elsewhere.path,
      ),
      _bytes,
    );

    expect(failure?.kind, GeneratedImageExportFailureKind.unsafeChange);
    expect(await File(prepared.writePath).exists(), isFalse);
  });

  test('write refuses a destination holding data when it is opened', () async {
    final writer = _writer(
      workspace,
      exclusiveWriter: _swapping(
        (path) => File(path).writeAsString('user data'),
      ),
    );
    final target = (await writer.prepareTarget(
      'result.png',
      mimeType: 'image/png',
    )).valueOrNull!;

    final failure = await writer.write(target, _bytes);

    expect(failure?.kind, GeneratedImageExportFailureKind.unsafeChange);
    expect(await File(target.writePath).readAsString(), 'user data');
  });

  test(
    'write refuses a destination swapped for a link to another file',
    () async {
      final victim = File(p.join(workspace.path, 'victim.png'));
      await victim.writeAsString('user data');
      final writer = _writer(
        workspace,
        exclusiveWriter: _swapping((path) async {
          await File(path).delete();
          await Link(path).create(victim.path);
        }),
      );
      final target = (await writer.prepareTarget(
        'result.png',
        mimeType: 'image/png',
      )).valueOrNull!;

      final failure = await writer.write(target, _bytes);

      expect(failure?.kind, GeneratedImageExportFailureKind.unsafeChange);
      expect(await victim.readAsString(), 'user data');
      expect(await FileSystemEntity.isLink(target.writePath), isTrue);
    },
    skip: _symbolicLinkSkip,
  );

  test('write refuses a link swapped in over an empty file', () async {
    final victim = File(p.join(workspace.path, 'victim.png'));
    await victim.create();
    final writer = _writer(
      workspace,
      exclusiveWriter: _swapping((path) async {
        await File(path).delete();
        await Link(path).create(victim.path);
      }),
    );
    final target = (await writer.prepareTarget(
      'result.png',
      mimeType: 'image/png',
    )).valueOrNull!;

    final failure = await writer.write(target, _bytes);

    expect(failure?.kind, GeneratedImageExportFailureKind.unsafeChange);
    expect(await victim.exists(), isTrue);
    expect(await victim.length(), 0);
  }, skip: _symbolicLinkSkip);

  test(
    'write never deletes the file a swapped link resolves to',
    () async {
      final elsewhere = await Directory.systemTemp.createTemp(
        'image-export-victim-',
      );
      addTearDown(() async {
        if (await elsewhere.exists()) await elsewhere.delete(recursive: true);
      });
      final victim = File(p.join(elsewhere.path, 'victim.png'));
      await victim.writeAsString('user data');
      final writer = _writer(
        workspace,
        exclusiveWriter: _swapping((path) async {
          await File(path).delete();
          await Link(path).create(victim.path);
        }),
      );
      final target = (await writer.prepareTarget(
        'result.png',
        mimeType: 'image/png',
      )).valueOrNull!;

      final failure = await writer.write(target, _bytes);

      expect(failure?.kind, GeneratedImageExportFailureKind.unsafeChange);
      expect(await victim.readAsString(), 'user data');
    },
    skip: _symbolicLinkSkip,
  );

  test('write maps a destination created after preparation', () async {
    final occupied = File(p.join(workspace.path, 'raced.png'));
    final writer = _writer(
      workspace,
      exclusiveWriter: (_, _, _) async {
        await occupied.writeAsString('other writer');
        throw FileSystemException('exclusive create failed', occupied.path);
      },
    );
    final target = (await writer.prepareTarget(
      'raced.png',
      mimeType: 'image/png',
    )).valueOrNull!;

    final failure = await writer.write(target, _bytes);

    expect(failure?.kind, GeneratedImageExportFailureKind.exists);
    expect(await occupied.readAsString(), 'other writer');
  });

  test('write reports a file system failure without a target', () async {
    final writer = _writer(
      workspace,
      exclusiveWriter: (path, _, _) async =>
          throw FileSystemException('write failed', path),
    );
    final target = (await writer.prepareTarget(
      'result.png',
      mimeType: 'image/png',
    )).valueOrNull!;

    final failure = await writer.write(target, _bytes);

    expect(failure?.kind, GeneratedImageExportFailureKind.writeFailed);
    expect(failure?.error, isNull);
  });

  test('write keeps the original error for other failures', () async {
    final writer = _writer(
      workspace,
      exclusiveWriter: (_, _, _) async => throw StateError('secret path'),
    );
    final target = (await writer.prepareTarget(
      'result.png',
      mimeType: 'image/png',
    )).valueOrNull!;

    final failure = await writer.write(target, _bytes);

    expect(failure?.kind, GeneratedImageExportFailureKind.writeFailed);
    expect(failure?.error, isA<StateError>());
  });

  test('describeDestination hides targets outside the workspace', () async {
    final external = await Directory.systemTemp.createTemp(
      'image-export-external-',
    );
    addTearDown(() async {
      if (await external.exists()) await external.delete(recursive: true);
    });

    expect(
      _writer(
        workspace,
      ).describeDestination(p.join(workspace.path, 'exports', 'result.png')),
      {
        'destination_path': 'exports/result.png',
        'destination_scope': 'workspace',
      },
    );
    expect(
      GeneratedImageExportWriter(
        env: DartIoExecutionEnv(
          workingDirectory: workspace.path,
          allowOutsideWorkingDirectory: true,
        ),
      ).describeDestination(p.join(external.path, 'external.png')),
      {'file_name': 'external.png', 'destination_scope': 'external'},
    );
  });
}

GeneratedImageExportWriter _writer(
  Directory workspace, {
  ResourceImageExclusiveWriter? exclusiveWriter,
}) => GeneratedImageExportWriter(
  env: DartIoExecutionEnv(workingDirectory: workspace.path),
  exclusiveWriter: exclusiveWriter,
);

ResourceImageExclusiveWriter _swapping(
  Future<void> Function(String path) swap,
) =>
    (path, bytes, canonicalParent) =>
        GeneratedImageExportWriter.writeExclusiveWithSwap(
          path,
          bytes,
          canonicalParent,
          () => swap(path),
        );

final Object? _symbolicLinkSkip = _supportsSymbolicLinks()
    ? null
    : 'creating symbolic links requires elevated permissions';

bool _supportsSymbolicLinks() {
  final probe = Directory.systemTemp.createTempSync('image-export-link-probe-');
  try {
    final target = File(p.join(probe.path, 'target'))
      ..writeAsStringSync('probe');
    Link(p.join(probe.path, 'link')).createSync(target.path);
    return true;
  } on FileSystemException {
    return false;
  } finally {
    probe.deleteSync(recursive: true);
  }
}

final class _ExistsFailureEnv extends DartIoExecutionEnv {
  _ExistsFailureEnv({required super.workingDirectory});

  @override
  Future<HarnessResult<bool, FileError>> exists(
    String path, [
    AbortSignal? abortSignal,
  ]) async => err(FileError(FileErrorCode.permissionDenied, 'denied', path));
}

final class _SkippedCreateDirEnv extends DartIoExecutionEnv {
  _SkippedCreateDirEnv({required super.workingDirectory});

  @override
  Future<HarnessResult<void, FileError>> createDir(
    String path, {
    bool recursive = true,
    AbortSignal? abortSignal,
  }) async => ok(null);
}

final Uint8List _bytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
