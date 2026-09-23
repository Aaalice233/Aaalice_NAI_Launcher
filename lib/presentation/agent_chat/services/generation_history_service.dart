import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/agent/agent_types.dart';
import '../../providers/image_generation_provider.dart';
import 'defined_agent_tool.dart';
import 'generation_image_read_contract.dart';

class GenerationHistoryService {
  GenerationHistoryService(
    this._ref, {
    required GenerationImageReadContract imageReadContract,
    required int maxRecentImageLimit,
  }) : _imageReadContract = imageReadContract,
       _maxRecentImageLimit = maxRecentImageLimit;
  final Ref _ref;
  final GenerationImageReadContract _imageReadContract;
  final int _maxRecentImageLimit;
  Future<AgentToolResult> recentImages(Map<String, dynamic> args) async {
    final rawLimit = args['limit'];
    if (rawLimit == null) {
      return agentToolError('missing_limit', 'Parameter "limit" is required.');
    }
    if (rawLimit is! num || rawLimit != rawLimit.roundToDouble()) {
      return agentToolError(
        'invalid_limit',
        'Parameter "limit" must be an integer.',
      );
    }
    final limit = rawLimit.toInt();
    if (limit < 1 || limit > _maxRecentImageLimit) {
      return agentToolError(
        'invalid_limit',
        'Parameter "limit" must be between 1 and $_maxRecentImageLimit.',
      );
    }
    await _ref
        .read(imageGenerationNotifierProvider.notifier)
        .ensureGenerationHistoryRestored();
    final history = _ref.read(imageGenerationNotifierProvider).history;
    final report = <Map<String, dynamic>>[];
    for (final image in history) {
      if (image.isFailedStreamSnapshot) continue;
      final descriptor = await _imageReadContract.describe(image);
      if (descriptor.readPath == null) continue;
      report.add(descriptor.toModelJson());
      if (report.length == limit) break;
    }
    if (report.isEmpty) {
      return agentToolError(
        'no_saved_images',
        'No saved images yet. generate_image results and queue outputs '
            'appear here after they are saved.',
      );
    }
    return agentToolJsonResult({'ok': true, 'images': report});
  }
}
