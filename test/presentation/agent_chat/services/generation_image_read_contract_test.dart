import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/presentation/agent_chat/services/execution_toolbox.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_image_read_contract.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_preparation_runtime.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_workspace_path_resolver.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:path/path.dart' as p;

void main() {
  test('returned Windows path is the exact first-call read argument', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'generation-read-contract-',
    );
    addTearDown(() => workspace.delete(recursive: true));
    final bytes = Uint8List.fromList(
      image_lib.encodePng(image_lib.Image(width: 1, height: 1)),
    );
    final file = File(
      '${workspace.path}${Platform.pathSeparator}2026-08-30'
      '${Platform.pathSeparator}real-seed-name.png',
    );
    await file.create(recursive: true);
    await file.writeAsBytes(bytes);
    final image = GeneratedImage(
      id: '7df4051f-3b9b-4a4c-91f3-ebc4517c8df1',
      bytes: bytes,
      width: 832,
      height: 1216,
      filePath: file.path,
    );
    final contract = GenerationImageReadContract(
      GenerationWorkspacePathResolver(workspaceDir: workspace.path),
    );

    final descriptor = await contract.describe(image);
    final json = descriptor.toModelJson();

    expect(
      json['path'],
      '2026-08-30${Platform.pathSeparator}real-seed-name.png',
    );
    expect(json['path'], isNot(contains(image.id)));
    expect(json.toString(), isNot(contains(workspace.path)));
    expect(json['resource_ref']['resourceId'], image.id);

    final result = await ExecutionToolbox(
      workspace.path,
    ).tools().single.execute('read-image', {'path': json['path']});
    expect(result.isError, isFalse);
    expect(result.content.whereType<ToolResultImageContent>(), hasLength(1));
  });

  test(
    'restored history keeps identity and read path without relocation',
    () async {
      final workspace = await Directory.systemTemp.createTemp(
        'generation-read-restore-',
      );
      addTearDown(() => workspace.delete(recursive: true));
      final file = File(
        '${workspace.path}${Platform.pathSeparator}archive'
        '${Platform.pathSeparator}restored.webp',
      );
      await file.create(recursive: true);
      await file.writeAsBytes(const [0x52, 0x49, 0x46, 0x46]);
      final restored = GeneratedImage(
        id: 'persisted-resource-id',
        bytes: Uint8List.fromList(const [0x52, 0x49, 0x46, 0x46]),
        width: 640,
        height: 640,
        filePath: file.path,
      );

      final relativeWorkspace = p.relative(
        workspace.path,
        from: Directory.current.path,
      );
      final descriptor = await GenerationImageReadContract(
        GenerationWorkspacePathResolver(workspaceDir: relativeWorkspace),
      ).describe(restored);

      expect(descriptor.resourceReference.resourceId, 'persisted-resource-id');
      expect(
        descriptor.readPath,
        'archive${Platform.pathSeparator}restored.webp',
      );
    },
  );

  test('an export outcome reports either a saved path or an error', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'generation-read-export-',
    );
    addTearDown(() => workspace.delete(recursive: true));
    final image = GeneratedImage(
      id: 'exported-resource-id',
      bytes: Uint8List.fromList(const [1, 2, 3]),
      width: 1,
      height: 1,
    );
    final contract = GenerationImageReadContract(
      GenerationWorkspacePathResolver(workspaceDir: workspace.path),
    );

    const saved = GeneratedImageExportOutcome.saved(
      'C:/art/out-1.png',
      source: GenerationSavePathSource.caller,
    );
    expect(saved.toModelJson(), {
      'saved_path': 'C:/art/out-1.png',
      'saved_path_source': 'caller',
    });
    expect(
      (await contract.describe(image, export: saved)).toModelJson(),
      containsPair('saved_path', 'C:/art/out-1.png'),
    );

    // 模型侧的来源值始终是 snake_case，不跟随 Dart 枚举名。
    expect(
      {
        for (final source in GenerationSavePathSource.values)
          source: GeneratedImageExportOutcome.saved(
            'C:/art/out-1.png',
            source: source,
          ).toModelJson()['saved_path_source'],
      },
      {
        GenerationSavePathSource.caller: 'caller',
        GenerationSavePathSource.galleryOriginal: 'gallery_original',
      },
    );

    const failed = GeneratedImageExportOutcome.failed(
      errorCode: 'destination_exists',
      errorMessage: 'The save_path destination already exists.',
    );
    expect(failed.toModelJson(), {
      'save_error': {
        'code': 'destination_exists',
        'message': 'The save_path destination already exists.',
      },
    });
    final failedJson = (await contract.describe(
      image,
      export: failed,
    )).toModelJson();
    expect(failedJson['save_error'], failed.toModelJson()['save_error']);
    expect(failedJson.containsKey('saved_path'), isFalse);

    expect(
      (await contract.describe(image)).toModelJson().keys,
      isNot(anyElement(anyOf('saved_path', 'save_error'))),
    );
  });

  test('does not expose or guess a path outside the read workspace', () async {
    final workspace = await Directory.systemTemp.createTemp(
      'generation-read-boundary-',
    );
    final outside = await Directory.systemTemp.createTemp(
      'generation-read-outside-',
    );
    addTearDown(() async {
      await workspace.delete(recursive: true);
      await outside.delete(recursive: true);
    });
    final file = await File(
      '${outside.path}${Platform.pathSeparator}resource-id.png',
    ).writeAsBytes(const [1, 2, 3]);
    final image = GeneratedImage(
      id: 'resource-id',
      bytes: Uint8List.fromList(const [1, 2, 3]),
      width: 1,
      height: 1,
      filePath: file.path,
    );
    final descriptor = await GenerationImageReadContract(
      GenerationWorkspacePathResolver(workspaceDir: workspace.path),
    ).describe(image);

    expect(descriptor.saved, isTrue);
    expect(descriptor.readPath, isNull);
    expect(descriptor.toModelJson(), isNot(contains('path')));
  });
}
