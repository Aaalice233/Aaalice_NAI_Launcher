import 'dart:async';

import '../../../core/agent/agent_types.dart';
import '../../../data/models/interaction/user_question.dart';
import '../models/agent_user_question_request.dart';

/// Owns the pending tool call independently of the mounted question widget.
class AgentUserQuestionController {
  AgentUserQuestionController({required this.onChanged});

  final void Function(AgentUserQuestionRequest?) onChanged;
  AgentUserQuestionRequest? _request;
  Completer<List<UserQuestionAnswer>?>? _pending;

  Future<List<UserQuestionAnswer>?> ask(
    AgentUserQuestionRequest request,
    AbortSignal? signal, {
    Duration timeout = const Duration(minutes: 2),
  }) async {
    if (timeout <= Duration.zero) {
      throw ArgumentError.value(timeout, "timeout", "Must be positive.");
    }
    throwIfAborted(signal);
    if (_pending != null) {
      throw StateError('A user question request is already pending.');
    }
    final pending = Completer<List<UserQuestionAnswer>?>();
    _pending = pending;
    final activeRequest = AgentUserQuestionRequest(
      toolCallId: request.toolCallId,
      questions: request.questions,
      expiresAt: DateTime.now().add(timeout),
    );
    _request = activeRequest;
    final timer = Timer(timeout, () {
      resolve(request.toolCallId, [
        for (final question in request.questions)
          UserQuestionAnswer.option(
            question.recommendedOptionId,
            automaticallySelected: true,
          ),
      ]);
    });
    void onAbort(String? _) {
      if (!pending.isCompleted) pending.complete(null);
    }

    signal?.addListener(onAbort);
    try {
      onChanged(activeRequest);
      final answers = await pending.future;
      throwIfAborted(signal);
      return answers;
    } finally {
      timer.cancel();
      signal?.removeListener(onAbort);
      _pending = null;
      _request = null;
      onChanged(null);
    }
  }

  bool resolve(String toolCallId, List<UserQuestionAnswer>? answers) {
    final request = _request;
    final pending = _pending;
    if (request == null ||
        request.toolCallId != toolCallId ||
        pending == null ||
        pending.isCompleted) {
      return false;
    }
    if (answers != null) {
      if (answers.length != request.questions.length) return false;
      for (var index = 0; index < answers.length; index++) {
        if (!answers[index].isValidFor(request.questions[index])) return false;
      }
    }
    pending.complete(answers == null ? null : List.unmodifiable(answers));
    return true;
  }

  void cancel() {
    final request = _request;
    if (request != null) resolve(request.toolCallId, null);
  }
}
