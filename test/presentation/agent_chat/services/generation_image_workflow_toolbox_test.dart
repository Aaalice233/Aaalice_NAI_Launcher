import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference_codec.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_image_workflow_service.dart';
import 'package:nai_launcher/presentation/agent_chat/services/generation_image_workflow_toolbox.dart';

void main() {
  test('dispatches all six modes and only opens preparation UI', () async {
    final launcher = _RecordingLauncher();
    final service = GenerationImageWorkflowService(
      loadResource: (_) async => GenerationWorkflowResourceSnapshot(
        status: GenerationWorkflowResourceStatus.ready,
        bytes: Uint8List.fromList([1, 2, 3]),
      ),
      launcher: launcher,
    );
    final tool = GenerationImageWorkflowToolbox(service).tools().single;
    expect(tool.parameters['additionalProperties'], isFalse);

    for (final mode in GenerationImageWorkflowMode.values) {
      final result = await tool.execute('call-${mode.name}', {
        'resource_ref': _encodedRef(mode.name),
        'mode': mode.name,
      });

      expect(result.isError, isFalse, reason: mode.name);
      expect(result.details['mode'], mode.name);
      expect(result.details['submitted'], isFalse);
      expect(result.details['next_step'], isNotEmpty);
    }

    expect(launcher.opened, GenerationImageWorkflowMode.values);
    expect(launcher.submitCount, 0);
  });

  test(
    'rejects failed snapshot, missing resource, and generating resource',
    () async {
      for (final entry in <GenerationWorkflowResourceStatus, String>{
        GenerationWorkflowResourceStatus.failedSnapshot:
            'failed_stream_snapshot',
        GenerationWorkflowResourceStatus.missing: 'resource_unavailable',
        GenerationWorkflowResourceStatus.generating: 'resource_generating',
      }.entries) {
        final launcher = _RecordingLauncher();
        final service = GenerationImageWorkflowService(
          loadResource: (_) async =>
              GenerationWorkflowResourceSnapshot(status: entry.key),
          launcher: launcher,
        );

        final result = await service.open({
          'resource_ref': _encodedRef('image'),
          'mode': 'edit',
        });

        expect(result.isError, isTrue);
        expect(result.details['code'], entry.value);
        expect(launcher.opened, isEmpty);
      }
    },
  );

  test(
    'late resource resolution cannot open after a newer resource switch',
    () async {
      final first = Completer<GenerationWorkflowResourceSnapshot>();
      final launcher = _RecordingLauncher();
      final service = GenerationImageWorkflowService(
        loadResource: (reference) {
          if (reference.resourceId == 'first') return first.future;
          return Future.value(
            GenerationWorkflowResourceSnapshot(
              status: GenerationWorkflowResourceStatus.ready,
              bytes: Uint8List.fromList([2]),
            ),
          );
        },
        launcher: launcher,
      );

      final lateResult = service.open({
        'resource_ref': _encodedRef('first'),
        'mode': 'edit',
      });
      final currentResult = await service.open({
        'resource_ref': _encodedRef('second'),
        'mode': 'upscale',
      });
      first.complete(
        GenerationWorkflowResourceSnapshot(
          status: GenerationWorkflowResourceStatus.ready,
          bytes: Uint8List.fromList([1]),
        ),
      );

      final staleResult = await lateResult;
      expect(currentResult.isError, isFalse);
      expect(staleResult.isError, isTrue);
      expect(staleResult.details['code'], 'resource_switched');
      expect(launcher.opened, [GenerationImageWorkflowMode.upscale]);
    },
  );

  test('session switch invalidates late resource resolution', () async {
    var sessionId = 'session-a';
    final pending = Completer<GenerationWorkflowResourceSnapshot>();
    final launcher = _RecordingLauncher();
    final service = GenerationImageWorkflowService(
      loadResource: (_) => pending.future,
      launcher: launcher,
      activeSessionId: () => sessionId,
      isMounted: () => true,
    );

    final resultFuture = service.open({
      'resource_ref': _encodedRef('session-image'),
      'mode': 'edit',
    });
    sessionId = 'session-b';
    pending.complete(
      GenerationWorkflowResourceSnapshot(
        status: GenerationWorkflowResourceStatus.ready,
        bytes: Uint8List.fromList([1]),
      ),
    );

    final result = await resultFuture;
    expect(result.details['code'], 'resource_switched');
    expect(result.details['message'], contains('session changed'));
    expect(launcher.opened, isEmpty);
  });

  test(
    'late asynchronous launcher is invalidated by a newer resource',
    () async {
      final firstLaunch = Completer<void>();
      final launcher = _GuardedLauncher(firstLaunch);
      final service = GenerationImageWorkflowService(
        loadResource: (_) async => GenerationWorkflowResourceSnapshot(
          status: GenerationWorkflowResourceStatus.ready,
          bytes: Uint8List.fromList([1]),
        ),
        launcher: launcher,
      );

      final stale = service.open({
        'resource_ref': _encodedRef('first'),
        'mode': 'variations',
      });
      await launcher.firstStarted.future;
      final current = service.open({
        'resource_ref': _encodedRef('second'),
        'mode': 'enhance',
      });
      firstLaunch.complete();

      final results = await Future.wait([stale, current]);
      expect(results.first.details['code'], 'resource_switched');
      expect(results.last.isError, isFalse);
      expect(launcher.applied, [GenerationImageWorkflowMode.enhance]);
    },
  );

  test(
    'maps workflow UI startup failures to a structured safe error',
    () async {
      final service = GenerationImageWorkflowService(
        loadResource: (_) async => GenerationWorkflowResourceSnapshot(
          status: GenerationWorkflowResourceStatus.ready,
          bytes: Uint8List.fromList([1]),
        ),
        launcher: const _ThrowingLauncher(),
      );

      final result = await service.open({
        'resource_ref': _encodedRef('ui-broken'),
        'mode': 'edit',
      });

      expect(result.details['code'], 'workflow_open_failed');
      expect(result.details['message'], contains('ui-broken'));
      expect(
        result.details['message'],
        isNot(contains('private dialog state')),
      );
    },
  );

  test('maps resource loader failures to a structured safe error', () async {
    final launcher = _RecordingLauncher();
    final service = GenerationImageWorkflowService(
      loadResource: (_) => throw const FileSystemException(
        'private path',
        r'C:\private\secret.png',
      ),
      launcher: launcher,
    );

    final result = await service.open({
      'resource_ref': _encodedRef('broken'),
      'mode': 'edit',
    });

    expect(result.details['code'], 'resource_resolution_failed');
    expect(result.details['message'], contains('broken'));
    expect(result.details['message'], isNot(contains(r'C:\private')));
    expect(launcher.opened, isEmpty);
  });

  test('requires a generated image reference and valid mode', () async {
    final launcher = _RecordingLauncher();
    final service = GenerationImageWorkflowService(
      loadResource: (_) async => const GenerationWorkflowResourceSnapshot(
        status: GenerationWorkflowResourceStatus.missing,
      ),
      launcher: launcher,
    );
    final local = AgentChatResourceReference(
      kind: AgentChatResourceKind.localGalleryImage,
      source: 'local',
      resourceId: '1',
    );

    final wrongKind = await service.open({
      'resource_ref': AgentChatResourceReferenceCodec.encodeJsonMap(local),
      'mode': 'edit',
    });
    final wrongMode = await service.open({
      'resource_ref': _encodedRef('image'),
      'mode': 'generate',
    });

    expect(wrongKind.details['code'], 'wrong_resource_kind');
    expect(wrongMode.details['code'], 'invalid_mode');
    expect(launcher.opened, isEmpty);
  });
}

Map<String, dynamic> _encodedRef(String id) =>
    AgentChatResourceReferenceCodec.encodeJsonMap(
      AgentChatResourceReference(
        kind: AgentChatResourceKind.generatedImage,
        source: 'generation_history',
        resourceId: id,
      ),
    );

final class _GuardedLauncher implements GenerationImageWorkflowLauncherAdapter {
  _GuardedLauncher(this.releaseFirst);

  final Completer<void> releaseFirst;
  final Completer<void> firstStarted = Completer<void>();
  final List<GenerationImageWorkflowMode> applied = [];

  @override
  Future<Map<String, dynamic>> open(
    GenerationImageWorkflowMode mode,
    AgentChatResourceReference reference,
    Uint8List imageBytes, {
    required bool Function() isCurrent,
  }) async {
    if (reference.resourceId == 'first') {
      firstStarted.complete();
      await releaseFirst.future;
    }
    if (isCurrent()) applied.add(mode);
    return const {};
  }
}

final class _ThrowingLauncher
    implements GenerationImageWorkflowLauncherAdapter {
  const _ThrowingLauncher();

  @override
  Future<Map<String, dynamic>> open(
    GenerationImageWorkflowMode mode,
    AgentChatResourceReference reference,
    Uint8List imageBytes, {
    required bool Function() isCurrent,
  }) => throw StateError('private dialog state');
}

final class _RecordingLauncher
    implements GenerationImageWorkflowLauncherAdapter {
  final List<GenerationImageWorkflowMode> opened = [];
  int submitCount = 0;

  @override
  Future<Map<String, dynamic>> open(
    GenerationImageWorkflowMode mode,
    AgentChatResourceReference reference,
    Uint8List imageBytes, {
    required bool Function() isCurrent,
  }) async {
    opened.add(mode);
    return const {};
  }
}
