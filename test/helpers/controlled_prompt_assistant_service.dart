import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/prompt_assistant/prompt_assistant_models.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/prompt_assistant_service.dart';

class ControlledPromptAssistantService extends Fake
    implements PromptAssistantService {
  final stream = StreamController<StreamingChunk>(onCancel: () async {});
  final requests = <String>[];
  final cancellations = <String?>[];

  @override
  Stream<StreamingChunk> translatePrompt(
    String input, {
    required String sessionId,
    String? targetLanguage,
  }) {
    requests.add(sessionId);
    return stream.stream;
  }

  @override
  Future<void> cancelCurrentTask({String? sessionId}) async {
    cancellations.add(sessionId);
  }

  void respond(String text) {
    stream.add(StreamingChunk(delta: text));
    dispose();
  }

  @override
  void dispose() => unawaited(stream.close());
}
