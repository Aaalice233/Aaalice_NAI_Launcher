import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/utils/app_logger.dart';
import '../../providers/image_generation_provider.dart';
import '../../services/image_workflow_launcher.dart';
import '../../widgets/image_editor/image_editor_types.dart';
import 'generation_image_workflow_service.dart';
import 'manual_inpaint_toolbox.dart';

/// Production adapter over the same launchers used by image preview actions.
/// It only needs the Ref available to the registry builder plus the root
/// navigator owned by the application shell.
final class ApplicationGenerationImageWorkflowLauncher
    implements GenerationImageWorkflowLauncherAdapter {
  ApplicationGenerationImageWorkflowLauncher({
    required Ref ref,
    required NavigatorState? Function() navigator,
    required Future<void> Function() openGeneration,
    required ManualInpaintToolbox manualInpaintToolbox,
  }) : _ref = ref,
       _navigator = navigator,
       _openGeneration = openGeneration,
       _manualInpaintToolbox = manualInpaintToolbox;

  final Ref _ref;
  final NavigatorState? Function() _navigator;
  final Future<void> Function() _openGeneration;
  final ManualInpaintToolbox _manualInpaintToolbox;

  BuildContext _rootContext() {
    final context = _navigator()?.context;
    if (context == null || !context.mounted) {
      throw StateError('Root navigator context is unavailable.');
    }
    return context;
  }

  @override
  Future<Map<String, dynamic>> open(
    GenerationImageWorkflowMode mode,
    AgentChatResourceReference reference,
    Uint8List imageBytes, {
    required bool Function() isCurrent,
  }) async {
    switch (mode) {
      case GenerationImageWorkflowMode.edit:
        await _launchUi(
          ImageWorkflowLauncher.openEditorFromRef(
            _rootContext(),
            _ref,
            imageBytes,
            mode: ImageEditorMode.edit,
            isCurrent: isCurrent,
          ).then((applied) async {
            if (applied && isCurrent()) await _openGeneration();
          }),
          mode,
          reference,
        );
        return const {'started': true, 'awaiting_user': true};
      case GenerationImageWorkflowMode.inpaint:
        final result = await _manualInpaintToolbox.createDraftFromResource(
          reference,
        );
        if (result.isError) {
          throw StateError(
            result.details['message']?.toString() ??
                'Unable to open inpaint draft.',
          );
        }
        return {'draft': result.details['draft']};
      case GenerationImageWorkflowMode.variations:
        await ImageWorkflowLauncher.prepareVariationsFromRef(
          _rootContext(),
          _ref,
          imageBytes,
          isCurrent: isCurrent,
        );
        if (!isCurrent()) return const {};
        await _openGeneration();
        return const {};
      case GenerationImageWorkflowMode.director:
        await _launchUi(
          ImageWorkflowLauncher.openDirectorToolsFromRef(
            _rootContext(),
            _ref,
            imageBytes,
            isCurrent: isCurrent,
          ).then((applied) async {
            if (applied && isCurrent()) await _openGeneration();
          }),
          mode,
          reference,
        );
        return const {'started': true, 'awaiting_user': true};
      case GenerationImageWorkflowMode.enhance:
        ImageWorkflowLauncher.openEnhanceFromRef(_ref, imageBytes);
        await _openGeneration();
        return const {};
      case GenerationImageWorkflowMode.upscale:
        ImageWorkflowLauncher.openUpscaleFromRef(_ref, imageBytes);
        await _openGeneration();
        return const {};
    }
  }

  Future<void> _launchUi(
    Future<void> future,
    GenerationImageWorkflowMode mode,
    AgentChatResourceReference reference,
  ) async {
    Object? startupError;
    StackTrace? startupStackTrace;
    var observingStartup = true;
    unawaited(
      future.catchError((Object error, StackTrace stackTrace) {
        if (observingStartup) {
          startupError = error;
          startupStackTrace = stackTrace;
          return;
        }
        AppLogger.e(
          'Agent image workflow UI failed: mode=${mode.name}, '
              'resourceId=${reference.resourceId}',
          error,
          stackTrace,
          'AgentImageWorkflow',
        );
      }),
    );
    await Future<void>.delayed(Duration.zero);
    observingStartup = false;
    if (startupError case final error?) {
      Error.throwWithStackTrace(error, startupStackTrace ?? StackTrace.current);
    }
  }
}

GenerationWorkflowResourceLoader generationWorkflowResourceLoader(Ref ref) {
  return (reference) async {
    await ref
        .read(imageGenerationNotifierProvider.notifier)
        .ensureGenerationHistoryRestored();
    final generation = ref.read(imageGenerationNotifierProvider);
    final image = generation.findImageById(reference.resourceId);
    if (image == null) {
      return const GenerationWorkflowResourceSnapshot(
        status: GenerationWorkflowResourceStatus.missing,
      );
    }
    if (!image.canUseAsGenerationInput) {
      return const GenerationWorkflowResourceSnapshot(
        status: GenerationWorkflowResourceStatus.failedSnapshot,
      );
    }
    return GenerationWorkflowResourceSnapshot(
      status: GenerationWorkflowResourceStatus.ready,
      bytes: image.bytes,
    );
  };
}
