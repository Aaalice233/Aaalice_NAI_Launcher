import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
import 'package:nai_launcher/core/agent/harness/env/dart_io_execution_env.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generated_image_export_writer.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_preparation_runtime.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_save_path_exporter.dart';
import 'package:nai_launcher/presentation/agent_chat/services/image_resource_action_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory workspace;
  late Uint8List png;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('save-path-export-');
    png = _png(1);
  });

  tearDown(() async {
    if (await workspace.exists()) await workspace.delete(recursive: true);
  });

  test('expands the target and reports the written file', () async {
    final outcome = await _exporter(workspace).export(
      source: GenerationSavePathSource.caller,
      template: p.join(workspace.path, 'exports', 'shot-{index}.png'),
      id: 'image-id',
      index: 2,
      total: 4,
      seed: 99,
      bytes: png,
      label: 'image.png',
    );

    final written = File(p.join(workspace.path, 'exports', 'shot-2.png'));
    expect(outcome.savedPath, p.absolute(written.path).replaceAll(r'\', '/'));
    expect(outcome.toModelJson(), {
      'saved_path': outcome.savedPath,
      'saved_path_source': 'caller',
    });
    expect(await written.readAsBytes(), png);
  });

  test('a caller template is expanded with the image id', () async {
    final outcome = await _exporter(workspace).export(
      source: GenerationSavePathSource.caller,
      template: p.join(workspace.path, 'exports', '{id}.png'),
      id: 'ca6b9b4e-6b0e-4d2f-9a0c-0f3d5a4c7e11',
      index: 1,
      total: 3,
      seed: null,
      bytes: png,
      label: 'image.png',
    );

    final written = File(
      p.join(
        workspace.path,
        'exports',
        'ca6b9b4e-6b0e-4d2f-9a0c-0f3d5a4c7e11.png',
      ),
    );
    expect(outcome.savedPath, p.absolute(written.path).replaceAll(r'\', '/'));
    expect(outcome.toModelJson()['saved_path_source'], 'caller');
    expect(await written.readAsBytes(), png);
  });

  test('a gallery original is referenced without writing anything', () async {
    final original = File(p.join(workspace.path, 'gallery', 'saved.png'));
    await original.create(recursive: true);
    await original.writeAsBytes(png);

    final outcome = await _exporter(workspace).export(
      source: GenerationSavePathSource.galleryOriginal,
      originalPath: original.path,
      id: 'image-id',
      index: 1,
      total: 1,
      seed: 7,
      bytes: png,
      label: 'image.png',
    );

    expect(outcome.savedPath, original.path.replaceAll(r'\', '/'));
    expect(outcome.toModelJson(), {
      'saved_path': outcome.savedPath,
      'saved_path_source': 'gallery_original',
    });
    expect(
      await workspace.list(recursive: true).map((entry) => entry.path).toList(),
      [original.parent.path, original.path],
    );
  });

  test('a missing gallery original is reported, not written', () async {
    final outcome = await _exporter(workspace).export(
      source: GenerationSavePathSource.galleryOriginal,
      originalPath: null,
      id: 'image-id',
      index: 1,
      total: 1,
      seed: 7,
      bytes: png,
      label: 'image.png',
    );

    expect(outcome.errorCode, 'original_unavailable');
    expect(outcome.savedPath, isNull);
    expect(outcome.errorMessage, contains('save_path'));
    expect(await workspace.list().isEmpty, isTrue);
  });

  test('reports a missing seed without writing anything', () async {
    final outcome = await _exporter(workspace).export(
      source: GenerationSavePathSource.caller,
      template: p.join(workspace.path, 'shot-{seed}.png'),
      id: 'image-id',
      index: 1,
      total: 1,
      seed: null,
      bytes: png,
      label: 'image.png',
    );

    expect(outcome.savedPath, isNull);
    expect(outcome.errorCode, 'seed_unavailable');
    expect(outcome.toModelJson()['save_error'], {
      'code': 'seed_unavailable',
      'message': outcome.errorMessage,
    });
    expect(await workspace.list().isEmpty, isTrue);
  });

  test('never overwrites an existing destination', () async {
    final occupied = File(p.join(workspace.path, 'shot.png'));
    await occupied.writeAsString('user data');

    final outcome = await _exporter(workspace).export(
      source: GenerationSavePathSource.caller,
      template: occupied.path,
      id: 'image-id',
      index: 1,
      total: 1,
      seed: 7,
      bytes: png,
      label: 'image.png',
    );

    expect(outcome.errorCode, 'destination_exists');
    expect(await occupied.readAsString(), 'user data');
  });

  test('refuses a target outside the permitted scope', () async {
    final outside = await Directory.systemTemp.createTemp('save-path-outside-');
    addTearDown(() async {
      if (await outside.exists()) await outside.delete(recursive: true);
    });

    final outcome = await _exporter(workspace).export(
      source: GenerationSavePathSource.caller,
      template: p.join(outside.path, 'shot.png'),
      id: 'image-id',
      index: 1,
      total: 1,
      seed: 7,
      bytes: png,
      label: 'image.png',
    );

    expect(outcome.errorCode, 'save_path_not_permitted');
    expect(await outside.list().isEmpty, isTrue);
  });

  test('a failed preparation writes nothing and keeps no fallback', () async {
    final outcome =
        await _exporter(
          workspace,
          prepareExport: (_) async => throw StateError('sharing policy'),
        ).export(
          source: GenerationSavePathSource.caller,
          template: p.join(workspace.path, 'shot.png'),
          id: 'image-id',
          index: 1,
          total: 1,
          seed: 7,
          bytes: png,
          label: 'image.png',
        );

    expect(outcome.errorCode, 'image_export_preparation_failed');
    expect(await workspace.list().isEmpty, isTrue);
  });

  test('writes the prepared bytes rather than the original ones', () async {
    final sanitized = _png(2);

    final outcome =
        await _exporter(
          workspace,
          prepareExport: (source) async => ResolvedImageResourceActionSource(
            label: source.label,
            bytes: sanitized,
          ),
        ).export(
          source: GenerationSavePathSource.caller,
          template: p.join(workspace.path, 'shot.png'),
          id: 'image-id',
          index: 1,
          total: 1,
          seed: 7,
          bytes: png,
          label: 'image.png',
        );

    expect(outcome.savedPath, isNotNull);
    expect(await File(p.join(workspace.path, 'shot.png')).readAsBytes(), [
      ...sanitized,
    ]);
  });

  test('reports an image without bytes instead of throwing', () async {
    final outcome = await _exporter(workspace).export(
      source: GenerationSavePathSource.caller,
      template: p.join(workspace.path, 'shot.png'),
      id: 'image-id',
      index: 1,
      total: 1,
      seed: 7,
      bytes: null,
      label: 'image.png',
    );

    expect(outcome.errorCode, 'image_unavailable');
    expect(await workspace.list().isEmpty, isTrue);
  });
}

GenerationSavePathExporter _exporter(
  Directory workspace, {
  ImageResourceExportPreparer? prepareExport,
}) => GenerationSavePathExporter(
  writer: GeneratedImageExportWriter(
    env: DartIoExecutionEnv(workingDirectory: workspace.path),
  ),
  prepareExport: prepareExport,
);

Uint8List _png(int size) => Uint8List.fromList(
  image_lib.encodePng(image_lib.Image(width: size, height: size)),
);
