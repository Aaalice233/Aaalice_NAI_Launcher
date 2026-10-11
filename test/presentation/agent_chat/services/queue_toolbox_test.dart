import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/queue/replication_task.dart';
import 'package:nai_launcher/data/models/queue/replication_task_generation_snapshot.dart';
import 'package:nai_launcher/data/models/user/user_subscription.dart';
import 'package:nai_launcher/presentation/agent_chat/services/queue_toolbox.dart';
import 'package:nai_launcher/presentation/providers/queue_execution_provider.dart';
import 'package:nai_launcher/presentation/providers/replication_queue_provider.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';

final _refProvider = Provider<Ref>((ref) => ref);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> largeSnapshot;

  setUpAll(() async {
    largeSnapshot = await ReplicationTaskGenerationSnapshot.encode(
      ImageParams(
        prompt: 'large',
        action: ImageGenerationAction.img2img,
        sourceImage: Uint8List(128 * 1024),
      ),
    );
  });

  ReplicationTask largeTask(String prompt) =>
      ReplicationTask.create(prompt: prompt, generationSnapshot: largeSnapshot);

  (ProviderContainer, _SeededQueue, QueueToolbox) build(
    List<ReplicationTask> tasks,
  ) {
    final queue = _SeededQueue(tasks);
    final container = ProviderContainer(
      overrides: [
        replicationQueueNotifierProvider.overrideWith(() => queue),
        queueExecutionNotifierProvider.overrideWith(_IdleQueueExecution.new),
        subscriptionNotifierProvider.overrideWith(_OpusSubscription.new),
      ],
    );
    addTearDown(container.dispose);
    return (
      container,
      queue,
      QueueToolbox(container.read(_refProvider), QueueControlRuntime()),
    );
  }

  Future<Map<String, dynamic>> execute(
    QueueToolbox toolbox,
    String name, [
    Map<String, dynamic> params = const {},
  ]) async {
    final result = await toolbox
        .tools()
        .firstWhere((tool) => tool.name == name)
        .execute(name, params);
    return jsonDecode(
          result.content.whereType<ToolResultTextContent>().single.text,
        )
        as Map<String, dynamic>;
  }

  test(
    'inspection summarizes large snapshots and reports corrupt ones',
    () async {
      final corrupt = Map<String, dynamic>.of(largeSnapshot)
        ..['sourceImage'] = '${largeSnapshot['sourceImage']}!';
      final (_, _, toolbox) = build([
        largeTask('valid'),
        ReplicationTask.create(prompt: 'corrupt', generationSnapshot: corrupt),
      ]);

      final inspected = await execute(toolbox, 'inspect_generation_queue');

      final pending = (inspected['pending'] as List).cast<Map>();
      expect(
        pending[0]['generation_snapshot'],
        allOf(
          containsPair('valid', true),
          containsPair('action', 'img2img'),
          containsPair('has_source_image', true),
        ),
      );
      expect(pending[1]['generation_snapshot'], {
        'schema_version': 1,
        'valid': false,
        'error': 'FormatException: Invalid image data',
      });
    },
  );

  test('confirmation compares task content, not task instances', () async {
    final task = largeTask('queued');
    final (_, queue, toolbox) = build([task, largeTask('second')]);
    Future<Map<String, dynamic>> prepare() async {
      final prepared = await execute(
        toolbox,
        'prepare_generation_queue_execution',
        {'action': 'resume'},
      );
      expect(prepared['ok'], isTrue, reason: '$prepared');
      return prepared;
    }

    Future<String?> resume(Map<String, dynamic> prepared) async =>
        (await execute(toolbox, 'resume_generation_queue', {
              'queue_preparation_id': prepared['queue_preparation_id'],
              'confirmed': true,
            }))['code']
            as String?;

    // 指纹一致才会执行动作，空闲队列的恢复动作随即返回 not_paused
    expect(await resume(await prepare()), 'not_paused');

    final beforeReload = await prepare();
    queue.replaceTaskForTest(
      ReplicationTask.fromJson(
        jsonDecode(jsonEncode(task.toJson())) as Map<String, dynamic>,
      ),
    );
    expect(await resume(beforeReload), 'not_paused');

    final beforeEdit = await prepare();
    queue.replaceTaskForTest(
      task.copyWith(
        generationSnapshot:
            await ReplicationTaskGenerationSnapshot.withTaskText(
              largeSnapshot,
              prompt: 'changed',
              negativePrompt: '',
            ),
      ),
    );
    expect(await resume(beforeEdit), 'queue_changed');
  });
}

class _SeededQueue extends ReplicationQueueNotifier {
  _SeededQueue(this.tasks);

  final List<ReplicationTask> tasks;

  @override
  ReplicationQueueState build() => ReplicationQueueState(tasks: tasks);

  void replaceTaskForTest(ReplicationTask task) {
    state = state.copyWith(
      tasks: [
        for (final queued in state.tasks) queued.id == task.id ? task : queued,
      ],
    );
  }
}

class _IdleQueueExecution extends QueueExecutionNotifier {
  @override
  QueueExecutionState build() => const QueueExecutionState();
}

class _OpusSubscription extends SubscriptionNotifier {
  @override
  SubscriptionState build() =>
      const SubscriptionState.loaded(UserSubscription(tier: 3, active: true));
}
