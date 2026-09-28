import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as image_lib;
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/harness/env/dart_io_execution_env.dart';
import 'package:nai_launcher/core/agent/harness/harness_types.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference_codec.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_image_resource.dart';
import 'package:nai_launcher/presentation/agent_chat/services/image_resource_action_service.dart';
import 'package:nai_launcher/presentation/agent_chat/services/image_resource_action_toolbox.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory workspace;

  setUp(() async {
    workspace = await Directory.systemTemp.createTemp('image-actions-');
  });

  tearDown(() async {
    if (await workspace.exists()) {
      await workspace.delete(recursive: true);
    }
  });

  test('tool schemas put resource_ref first and require explicit target', () {
    final toolbox = ImageResourceActionToolbox(_service(workspace));
    final tools = toolbox.tools();

    expect(tools.map((tool) => tool.name), [
      'save_generated_image',
      'copy_generated_image_to_clipboard',
      'send_generated_image_to_krita',
    ]);
    for (final tool in tools) {
      expect((tool.parameters['properties'] as Map).keys.first, 'resource_ref');
      expect(tool.parameters['additionalProperties'], isFalse);
    }
    expect(tools.first.parameters['required'], [
      'resource_ref',
      'destination_path',
    ]);
  });

  test(
    'save uses a safe explicit workspace target without overwriting',
    () async {
      final service = _service(workspace);
      final arguments = {
        ..._resourceArgument,
        'destination_path': 'exports/result.png',
      };

      final first = await service.save(arguments);
      final output = File(
        '${workspace.path}${Platform.pathSeparator}exports'
        '${Platform.pathSeparator}result.png',
      );
      expect(first.isError, isFalse);
      expect(await output.readAsBytes(), _pngBytes);
      expect(first.details['destination_path'], 'exports/result.png');

      await output.writeAsString('user data');
      final second = await service.save(arguments);
      expect(second.isError, isTrue);
      expect(second.details['code'], 'destination_exists');
      expect(await output.readAsString(), 'user data');
    },
  );

  test(
    'exclusive write rejects a destination created after preflight',
    () async {
      final target = File(
        '${workspace.path}${Platform.pathSeparator}raced.png',
      );
      final service = _service(
        workspace,
        exclusiveWriter: (_, _, _) async {
          await target.writeAsString('other writer');
          throw FileSystemException('exclusive create failed', target.path);
        },
      );

      final result = await service.save({
        ..._resourceArgument,
        'destination_path': 'raced.png',
      });

      expect(result.details['code'], 'destination_exists');
      expect(await target.readAsString(), 'other writer');
      expect(_text(result), isNot(contains(target.path)));
    },
  );

  test('save rejects a parent replaced by an external symlink', () async {
    final external = await Directory.systemTemp.createTemp(
      'image-actions-symlink-target-',
    );
    addTearDown(() async {
      if (await external.exists()) await external.delete(recursive: true);
    });
    final service = ImageResourceActionService(
      resolve: (reference) async => _resolved(reference),
      env: _ParentSwapExecutionEnv(
        workingDirectory: workspace.path,
        externalDirectory: external.path,
      ),
      clipboardWriter: (_) async {},
    );

    final result = await service.save({
      ..._resourceArgument,
      'destination_path': 'exports/result.png',
    });

    expect(result.details['code'], 'unsafe_destination');
    expect(await File('${external.path}/result.png').exists(), isFalse);
  });

  test('full access permits an explicit external target safely', () async {
    final externalDirectory = await Directory.systemTemp.createTemp(
      'image-actions-external-',
    );
    addTearDown(() async {
      if (await externalDirectory.exists()) {
        await externalDirectory.delete(recursive: true);
      }
    });
    final target = File(
      '${externalDirectory.path}${Platform.pathSeparator}external.png',
    );
    final service = ImageResourceActionService(
      resolve: (reference) async => _resolved(reference),
      env: DartIoExecutionEnv(
        workingDirectory: workspace.path,
        allowOutsideWorkingDirectory: true,
      ),
      clipboardWriter: (_) async {},
    );

    final result = await service.save({
      ..._resourceArgument,
      'destination_path': target.path,
    });

    expect(result.isError, isFalse);
    expect(await target.readAsBytes(), _pngBytes);
    expect(result.details['destination_scope'], 'external');
    expect(result.details['file_name'], 'external.png');
    expect(_text(result), isNot(contains(externalDirectory.path)));
  });

  test(
    'save rejects traversal and does not disclose an absolute path',
    () async {
      final outside = File(
        '${workspace.parent.path}${Platform.pathSeparator}private-result.png',
      );
      final service = _service(workspace);

      final result = await service.save({
        ..._resourceArgument,
        'destination_path': '../private-result.png',
      });

      expect(result.isError, isTrue);
      expect(result.details['code'], 'unsafe_destination');
      expect(_text(result), isNot(contains(outside.path)));
      expect(await outside.exists(), isFalse);
    },
  );

  test('resource lifecycle failures keep their structured code', () async {
    final service = ImageResourceActionService(
      resolve: (_) async => throw const GenerationImageResourceException(
        'failed_stream_snapshot',
        'generated image generated-1 is a failed stream snapshot.',
      ),
      env: DartIoExecutionEnv(workingDirectory: workspace.path),
      clipboardWriter: (_) async {},
    );

    final result = await service.copy(_resourceArgument);

    expect(result.details['code'], 'failed_stream_snapshot');
    expect(_text(result), contains('generated-1'));
  });

  test('copy reports injected clipboard failure explicitly', () async {
    final service = _service(
      workspace,
      clipboardWriter: (_) async => throw StateError('secret clipboard path'),
    );

    final result = await service.copy(_resourceArgument);

    expect(result.isError, isTrue);
    expect(result.details['code'], 'clipboard_write_failed');
    expect(_text(result), isNot(contains('secret clipboard path')));
  });

  test('Krita checks platform capability before resolving resource', () async {
    var resolveCount = 0;
    final service = ImageResourceActionService(
      resolve: (reference) async {
        resolveCount += 1;
        return _resolved(reference);
      },
      env: DartIoExecutionEnv(workingDirectory: workspace.path),
      clipboardWriter: (_) async {},
      supportsKritaBridge: () => false,
      readKritaBridgeState: () => const ImageResourceKritaBridgeState(
        configured: true,
        connected: true,
      ),
      sendToKrita: (_, {required name}) => true,
    );

    final result = await service.sendKrita(_resourceArgument);

    expect(result.details['code'], 'krita_unsupported');
    expect(resolveCount, 0);
  });

  test('Krita reports disabled and disconnected bridge states', () async {
    var state = const ImageResourceKritaBridgeState(
      configured: false,
      connected: false,
    );
    final service = _service(
      workspace,
      supportsKritaBridge: () => true,
      readKritaBridgeState: () => state,
      sendToKrita: (_, {required name}) => true,
    );

    final disabled = await service.sendKrita(_resourceArgument);
    expect(disabled.details['code'], 'krita_not_configured');

    state = const ImageResourceKritaBridgeState(
      configured: true,
      connected: false,
    );
    final disconnected = await service.sendKrita(_resourceArgument);
    expect(disconnected.details['code'], 'krita_not_connected');
  });

  test('Krita prepares and sends through the injected bridge', () async {
    Uint8List? sentBytes;
    String? sentName;
    final service = _service(
      workspace,
      supportsKritaBridge: () => true,
      readKritaBridgeState: () => const ImageResourceKritaBridgeState(
        configured: true,
        connected: true,
      ),
      sendToKrita: (bytes, {required name}) {
        sentBytes = bytes;
        sentName = name;
        return true;
      },
    );

    final result = await service.sendKrita(_resourceArgument);

    expect(result.isError, isFalse);
    expect(sentBytes, _pngBytes);
    expect(sentName, 'generated.png');
  });
}

ImageResourceActionService _service(
  Directory workspace, {
  ResourceImageClipboardWriter? clipboardWriter,
  bool Function()? supportsKritaBridge,
  ImageResourceKritaBridgeState Function()? readKritaBridgeState,
  ResourceImageKritaSender? sendToKrita,
  ResourceImageExclusiveWriter? exclusiveWriter,
}) => ImageResourceActionService(
  resolve: (reference) async => _resolved(reference),
  env: DartIoExecutionEnv(workingDirectory: workspace.path),
  clipboardWriter: clipboardWriter ?? (_) async {},
  supportsKritaBridge: supportsKritaBridge,
  readKritaBridgeState: readKritaBridgeState,
  sendToKrita: sendToKrita,
  exclusiveWriter: exclusiveWriter,
);

final class _ParentSwapExecutionEnv extends DartIoExecutionEnv {
  _ParentSwapExecutionEnv({
    required super.workingDirectory,
    required this.externalDirectory,
  });

  final String externalDirectory;
  bool _swapped = false;

  @override
  Future<HarnessResult<bool, FileError>> exists(
    String path, [
    AbortSignal? abortSignal,
  ]) async {
    final result = await super.exists(path, abortSignal);
    if (!_swapped && p.basename(path) == 'result.png') {
      _swapped = true;
      final parent = Directory(p.dirname(path));
      await parent.delete(recursive: true);
      await Link(parent.path).create(externalDirectory);
    }
    return result;
  }
}

ResolvedImageResourceActionSource _resolved(
  AgentChatResourceReference reference,
) => ResolvedImageResourceActionSource(
  label: 'generated.webp',
  bytes: _pngBytes,
);

final AgentChatResourceReference _reference = AgentChatResourceReference(
  kind: AgentChatResourceKind.generatedImage,
  source: 'generation_history',
  resourceId: 'generated-1',
);

final Map<String, dynamic> _resourceArgument = {
  'resource_ref': AgentChatResourceReferenceCodec.encodeJsonMap(_reference),
};

String _text(AgentToolResult result) =>
    result.content.whereType<ToolResultTextContent>().single.text;

final Uint8List _pngBytes = Uint8List.fromList(
  image_lib.encodePng(image_lib.Image(width: 1, height: 1)),
);
