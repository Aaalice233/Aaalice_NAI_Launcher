import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/agent/resources/agent_chat_resource_reference.dart';
import '../../../core/agent/resources/agent_chat_resource_reference_codec.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/queue_execution_provider.dart';
import '../../providers/replication_queue_provider.dart';

class GenerationStatusService {
  GenerationStatusService(
    this._ref, {
    required AgentChatResourceReference Function(String imageId)
    generatedImageReference,
  }) : _generatedImageReference = generatedImageReference;
  final Ref _ref;
  final AgentChatResourceReference Function(String imageId)
  _generatedImageReference;
  String statusJson() {
    final gen = _ref.read(imageGenerationNotifierProvider);
    final queue = _ref.read(replicationQueueNotifierProvider);
    final execution = _ref.read(queueExecutionNotifierProvider);
    return jsonEncode({
      'generation': {
        'status': gen.status.name,
        'progress': (gen.progress * 100).round(),
        'image': '${gen.currentImage}/${gen.totalImages}',
        if (gen.errorMessage != null) 'error': gen.errorMessage,
        'recent_images': [
          for (final image in gen.history.take(5))
            if (image.filePath != null)
              AgentChatResourceReferenceCodec.encodeJsonMap(
                _generatedImageReference(image.id),
              ),
        ],
      },
      'queue': {
        'pending': queue.count,
        'completed': queue.completedCount,
        'failed': queue.failedCount,
        'execution': execution.status.name,
        'session_progress': (execution.progress * 100).round(),
      },
    });
  }

  // -------------------------------------------------------------------------
  // get/update_generation_settings
  // -------------------------------------------------------------------------
}
