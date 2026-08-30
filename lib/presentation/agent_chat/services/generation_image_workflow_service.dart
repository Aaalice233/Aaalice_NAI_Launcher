import 'dart:typed_data';

import '../../../core/agent/agent_types.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import 'defined_agent_tool.dart';
import 'generation_image_resource.dart';

enum GenerationImageWorkflowMode {
  edit,
  inpaint,
  variations,
  director,
  enhance,
  upscale;

  static GenerationImageWorkflowMode? parse(Object? value) {
    if (value is! String) return null;
    for (final mode in values) {
      if (mode.name == value) return mode;
    }
    return null;
  }
}

enum GenerationWorkflowResourceStatus {
  ready,
  missing,
  generating,
  failedSnapshot,
}

final class GenerationWorkflowResourceSnapshot {
  const GenerationWorkflowResourceSnapshot({required this.status, this.bytes});

  final GenerationWorkflowResourceStatus status;
  final Uint8List? bytes;
}

typedef GenerationWorkflowResourceLoader =
    Future<GenerationWorkflowResourceSnapshot> Function(
      AgentChatResourceReference reference,
    );

abstract interface class GenerationImageWorkflowLauncherAdapter {
  Future<Map<String, dynamic>> open(
    GenerationImageWorkflowMode mode,
    AgentChatResourceReference reference,
    Uint8List imageBytes, {
    required bool Function() isCurrent,
  });
}

/// Resolves one stable generation image and prepares the selected real UI
/// workflow. It never invokes a generation submitter.
final class GenerationImageWorkflowService {
  GenerationImageWorkflowService({
    required GenerationWorkflowResourceLoader loadResource,
    required GenerationImageWorkflowLauncherAdapter launcher,
    String Function()? activeSessionId,
    bool Function()? isMounted,
  }) : _loadResource = loadResource,
       _launcher = launcher,
       _activeSessionId = activeSessionId,
       _isMounted = isMounted;

  final GenerationWorkflowResourceLoader _loadResource;
  final GenerationImageWorkflowLauncherAdapter _launcher;
  final String Function()? _activeSessionId;
  final bool Function()? _isMounted;
  int _resourceSwitchEpoch = 0;

  Future<AgentToolResult> open(Map<String, dynamic> args) async {
    final mode = GenerationImageWorkflowMode.parse(args['mode']);
    if (mode == null) {
      return agentToolError(
        'invalid_mode',
        'mode must be edit, inpaint, variations, director, enhance, or upscale.',
      );
    }

    final AgentChatResourceReference reference;
    try {
      reference = parseGenerationImageResource(args);
    } on GenerationImageResourceException catch (error) {
      return agentToolError(
        error.code,
        'open_generation_image_workflow: ${error.message}',
      );
    }

    final epoch = ++_resourceSwitchEpoch;
    final sessionId = _activeSessionId?.call();
    bool isCurrent() =>
        epoch == _resourceSwitchEpoch &&
        (_isMounted?.call() ?? true) &&
        _activeSessionId?.call() == sessionId;

    final GenerationWorkflowResourceSnapshot snapshot;
    try {
      snapshot = await _loadResource(reference);
    } on Object catch (error) {
      if (!isCurrent()) return _switchedError(reference);
      return agentToolError(
        'resource_resolution_failed',
        'open_generation_image_workflow: generated image '
            '${reference.resourceId} failed during resource resolution '
            '(${error.runtimeType}).',
      );
    }
    if (!isCurrent()) {
      return _switchedError(reference);
    }

    switch (snapshot.status) {
      case GenerationWorkflowResourceStatus.missing:
        return agentToolError(
          'resource_unavailable',
          'open_generation_image_workflow: generated image '
              '${reference.resourceId} is unavailable.',
        );
      case GenerationWorkflowResourceStatus.generating:
        return agentToolError(
          'resource_generating',
          'open_generation_image_workflow: generated image '
              '${reference.resourceId} is not complete yet.',
        );
      case GenerationWorkflowResourceStatus.failedSnapshot:
        return agentToolError(
          'failed_stream_snapshot',
          'open_generation_image_workflow: generated image '
              '${reference.resourceId} is a failed stream snapshot.',
        );
      case GenerationWorkflowResourceStatus.ready:
        break;
    }

    final bytes = snapshot.bytes;
    if (bytes == null || bytes.isEmpty) {
      return agentToolError(
        'resource_unavailable',
        'open_generation_image_workflow: generated image '
            '${reference.resourceId} has no available bytes.',
      );
    }

    final Map<String, dynamic> launchDetails;
    try {
      launchDetails = await _launcher.open(
        mode,
        reference,
        bytes,
        isCurrent: isCurrent,
      );
    } on Object catch (error) {
      if (!isCurrent()) {
        return _switchedError(reference);
      }
      return agentToolError(
        'workflow_open_failed',
        'open_generation_image_workflow: mode=${mode.name}, generated image '
            '${reference.resourceId} failed while opening the real workflow '
            'UI (${error.runtimeType}).',
      );
    }
    if (!isCurrent()) {
      return _switchedError(reference);
    }
    return agentToolJsonResult({
      'ok': true,
      'mode': mode.name,
      'resource_ref': AgentChatResourceReferenceCodec.encodeJsonMap(reference),
      'submitted': false,
      ...launchDetails,
      'next_step': _nextStep(mode),
    });
  }
}

AgentToolResult _switchedError(AgentChatResourceReference reference) {
  return agentToolError(
    'resource_switched',
    'open_generation_image_workflow: generated image '
        '${reference.resourceId} is no longer current because the image '
        'request or Agent session changed.',
  );
}

String _nextStep(GenerationImageWorkflowMode mode) => switch (mode) {
  GenerationImageWorkflowMode.edit =>
    'Complete edits in the image editor, then review generation settings.',
  GenerationImageWorkflowMode.inpaint =>
    'Draw and confirm the manual inpaint mask, then explicitly submit the draft when ready.',
  GenerationImageWorkflowMode.variations =>
    'Review the prepared variation settings on Generation, then start manually.',
  GenerationImageWorkflowMode.director =>
    'Complete Director Tools, then review the resulting generation input.',
  GenerationImageWorkflowMode.enhance =>
    'Review the prepared Enhance workflow on Generation, then start manually.',
  GenerationImageWorkflowMode.upscale =>
    'Review the prepared Upscale workflow on Generation, then start manually.',
};
