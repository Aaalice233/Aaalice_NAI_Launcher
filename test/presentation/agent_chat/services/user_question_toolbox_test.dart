import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/permissions/permissions.dart';
import 'package:nai_launcher/data/models/interaction/user_question.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_user_question_controller.dart';
import 'package:nai_launcher/presentation/agent_chat/services/user_question_toolbox.dart';
import 'package:nai_launcher/presentation/agent_chat/models/agent_user_question_request.dart';

import '../../../fixtures/user_questions.dart';

void main() {
  test(
    'default deadline submits every recommendation exactly after two minutes',
    () {
      fakeAsync((async) {
        AgentUserQuestionRequest? request;
        final controller = AgentUserQuestionController(
          onChanged: (value) => request = value,
        );
        final tool = UserQuestionToolbox(controller).tools().single;
        AgentToolResult? result;
        tool
            .execute('timeout', {
              'questions': [questionJson('one'), questionJson('two')],
            })
            .then((value) => result = value);
        expect(request?.expiresAt, isNotNull);
        async.elapse(const Duration(seconds: 119));
        expect(result, isNull);
        async.elapse(const Duration(seconds: 1));
        expect(request, isNull);
        final answers = result!.details['answers'] as List;
        expect(answers, hasLength(2));
        for (final answer in answers) {
          expect(answer['option_id'], 'classic');
          expect(answer['source'], 'timeout_recommendation');
        }
        expect(controller.resolve('timeout', const []), isFalse);
        expect(async.pendingTimers, isEmpty);
      });
    },
  );

  test('custom timeout and manual cancellation clean up their timers', () {
    fakeAsync((async) {
      final controller = AgentUserQuestionController(onChanged: (_) {});
      final tool = UserQuestionToolbox(controller).tools().single;
      AgentToolResult? result;
      tool
          .execute('short', {
            'questions': [questionJson('one')],
            'timeout_seconds': 5,
          })
          .then((value) => result = value);
      async.elapse(const Duration(seconds: 5));
      expect(result?.details['cancelled'], isFalse);
      expect(async.pendingTimers, isEmpty);
      tool.execute('cancel', {
        'questions': [questionJson('one')],
      });
      controller.cancel();
      async.flushMicrotasks();
      expect(async.pendingTimers, isEmpty);
    });
  });

  test(
    'tool waits for all answers and rejects stale or incomplete replies',
    () async {
      AgentUserQuestionRequest? request;
      final controller = AgentUserQuestionController(
        onChanged: (value) => request = value,
      );
      final tool = UserQuestionToolbox(controller).tools().single;
      final future = tool.execute('current', {
        'questions': [questionJson('one'), questionJson('two')],
      });
      expect(request?.questions.length, 2);
      expect(tool.executionMode, ToolExecutionMode.sequential);
      const answers = [
        UserQuestionAnswer.option('classic'),
        UserQuestionAnswer.custom('现代制服'),
      ];
      expect(controller.resolve('stale', answers), isFalse);
      expect(controller.resolve('current', answers.take(1).toList()), isFalse);
      expect(
        controller.resolve('current', [
          const UserQuestionAnswer.option('missing'),
          answers.last,
        ]),
        isFalse,
      );
      expect(controller.resolve('current', answers), isTrue);
      expect(controller.resolve('current', answers), isFalse);
      final result = await future;
      expect(result.isError, isFalse);
      expect(result.details['cancelled'], isFalse);
      expect((result.details['answers'] as List).last, {
        'question_id': 'two',
        'question': '你希望采用哪种角色呈现方向？',
        'option_id': null,
        'answer': '现代制服',
        'custom': true,
      });
      expect(request, isNull);
    },
  );

  test(
    'cancel and abort release pending calls without fabricating an answer',
    () async {
      AgentUserQuestionRequest? request;
      final controller = AgentUserQuestionController(
        onChanged: (value) => request = value,
      );
      final tool = UserQuestionToolbox(controller).tools().single;
      final cancelled = tool.execute('cancel', {
        'questions': [questionJson('one')],
      });
      controller.cancel();
      expect((await cancelled).details, {'cancelled': true, 'answers': []});
      final abort = AbortController();
      final pending = tool.execute('abort', {
        'questions': [questionJson('one')],
      }, abort.signal);
      final assertion = expectLater(pending, throwsStateError);
      abort.abort();
      await assertion;
      expect(request, isNull);
      final next = tool.execute('next', {
        'questions': [questionJson('one')],
      });
      controller.cancel();
      await next;
    },
  );

  test(
    'invalid options, recommendation and duplicate question IDs never open UI',
    () async {
      var opened = false;
      final tool = UserQuestionToolbox(
        AgentUserQuestionController(onChanged: (_) => opened = true),
      ).tools().single;
      for (final questions in [
        [],
        [
          {...questionJson('one'), 'recommended_option_id': 'unknown'},
        ],
        [
          {...questionJson('one'), 'options': []},
        ],
        [questionJson('same'), questionJson('same')],
      ]) {
        final result = await tool.execute('invalid', {'questions': questions});
        expect(result.isError, isTrue);
      }
      expect(opened, isFalse);
    },
  );

  test(
    'clarification is available in safe mode without a permission request',
    () {
      final catalog = AgentToolPermissionCatalog(
        toolNames: ['ask_user_question'],
        descriptors: [describeAgentToolPermission('ask_user_question')],
      );
      expect(
        catalog.decide(
          toolName: 'ask_user_question',
          policy: agentPermissionPolicy(safeMode: true, fullAccess: false),
        ),
        AgentPermissionDecision.allow,
      );
    },
  );
}
