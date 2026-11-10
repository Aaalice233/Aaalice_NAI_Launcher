import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/services/anlas_calculator.dart';
import 'package:nai_launcher/core/storage/replication_queue_blob_store.dart';
import 'package:nai_launcher/core/storage/replication_queue_blob_store_provider.dart';
import 'package:nai_launcher/core/utils/focused_inpaint_utils.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/queue/replication_task.dart';
import 'package:nai_launcher/data/models/queue/replication_task_generation_snapshot.dart';
import 'package:nai_launcher/data/models/user/user_subscription.dart';
import 'package:nai_launcher/presentation/agent_chat/services/queue_toolbox.dart';
import 'package:nai_launcher/presentation/providers/generation/image_workflow_controller.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/queue_execution_provider.dart';
import 'package:nai_launcher/presentation/providers/replication_queue_provider.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';

import '../../../helpers/memory_queue_blob_store.dart';

final _refProvider = Provider<Ref>((ref) => ref);
final _blobFiles = MemoryStorageFileSystem();
final _blobStore = memoryQueueBlobStore(_blobFiles);

/// 与入队后状态里的形态一致：图片已落盘，快照只存引用。
Future<Map<String, dynamic>> _stored(
  ImageParams params, {
  int? batchSize,
  QueuedFocusedInpaint? focused,
}) async {
  final interned = await ReplicationTaskGenerationSnapshot.intern([
    await ReplicationTaskGenerationSnapshot.encode(
      params,
      batchSize: batchSize,
      focused: focused,
    ),
  ], _blobStore);
  interned.release();
  return interned.snapshots.single!;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Map<String, dynamic> largeSnapshot;

  setUpAll(() async {
    largeSnapshot = await _stored(
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
    List<ReplicationTask> tasks, {
    int pageImagesPerRequest = 1,
    ImageWorkflowState pageWorkflow = const ImageWorkflowState(),
  }) {
    final queue = _SeededQueue(tasks);
    final container = ProviderContainer(
      overrides: [
        replicationQueueNotifierProvider.overrideWith(() => queue),
        replicationQueueBlobStoreProvider.overrideWithValue(_blobStore),
        queueExecutionNotifierProvider.overrideWith(_IdleQueueExecution.new),
        subscriptionNotifierProvider.overrideWith(_PaidSubscription.new),
        imagesPerRequestProvider.overrideWith(
          () => _FixedImagesPerRequest(pageImagesPerRequest),
        ),
        imageWorkflowControllerProvider.overrideWith(
          () => _FixedWorkflow(pageWorkflow),
        ),
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
        ..['sourceImage'] = base64Encode(Uint8List(8));
      final (_, _, toolbox) = build([
        largeTask('valid'),
        ReplicationTask.create(prompt: 'corrupt', generationSnapshot: corrupt),
      ]);

      final inspected = await execute(toolbox, 'inspect_generation_queue');

      final pending = (inspected['pending'] as List).cast<Map>();
      expect(
        pending[0]['generation_snapshot'],
        allOf(
          containsPair('index_valid', true),
          containsPair('images_verified', false),
          containsPair('action', 'img2img'),
          containsPair('has_source_image', true),
        ),
      );
      expect(pending[1]['generation_snapshot'], {
        'schema_version': 2,
        'index_valid': false,
        'images_verified': false,
        'error': 'FormatException: Invalid queued image reference',
      });
    },
  );

  test('completed tasks are summarized after their images are gone', () async {
    final files = MemoryStorageFileSystem();
    final store = memoryQueueBlobStore(files);
    final interned = await ReplicationTaskGenerationSnapshot.intern([
      await ReplicationTaskGenerationSnapshot.encode(
        ImageParams(
          prompt: 'done',
          action: ImageGenerationAction.img2img,
          sourceImage: Uint8List(64),
        ),
      ),
    ], store);
    interned.release();
    files.files.clear();
    final done = ReplicationTask.create(
      prompt: 'done',
      generationSnapshot: interned.snapshots.single,
    );
    final queue = _SeededQueue(const [], completed: [done]);
    final container = ProviderContainer(
      overrides: [
        replicationQueueNotifierProvider.overrideWith(() => queue),
        replicationQueueBlobStoreProvider.overrideWithValue(store),
        queueExecutionNotifierProvider.overrideWith(_IdleQueueExecution.new),
      ],
    );
    addTearDown(container.dispose);
    final toolbox = QueueToolbox(
      container.read(_refProvider),
      QueueControlRuntime(),
    );

    final inspected = await execute(toolbox, 'inspect_generation_queue_task', {
      'task_id': done.id,
    });

    expect(
      (inspected['task'] as Map)['generation_snapshot'],
      allOf(
        containsPair('index_valid', true),
        containsPair('has_source_image', true),
      ),
    );
  });

  test('estimation reports a missing image as an invalid snapshot', () async {
    final files = MemoryStorageFileSystem();
    final store = memoryQueueBlobStore(files);
    final interned = await ReplicationTaskGenerationSnapshot.intern([
      await ReplicationTaskGenerationSnapshot.encode(
        ImageParams(
          prompt: 'gone',
          action: ImageGenerationAction.img2img,
          sourceImage: Uint8List(64),
        ),
      ),
    ], store);
    interned.release();
    files.files.clear();
    final container = ProviderContainer(
      overrides: [
        replicationQueueNotifierProvider.overrideWith(
          () => _SeededQueue([
            ReplicationTask.create(
              prompt: 'gone',
              generationSnapshot: interned.snapshots.single,
            ),
          ]),
        ),
        replicationQueueBlobStoreProvider.overrideWithValue(store),
        queueExecutionNotifierProvider.overrideWith(_IdleQueueExecution.new),
        subscriptionNotifierProvider.overrideWith(_PaidSubscription.new),
      ],
    );
    addTearDown(container.dispose);
    final toolbox = QueueToolbox(
      container.read(_refProvider),
      QueueControlRuntime(),
    );

    final prepared = await execute(
      toolbox,
      'prepare_generation_queue_execution',
      {'action': 'start'},
    );

    expect(prepared['code'], 'invalid_queue_snapshot');
    expect(prepared['message'], contains('missing'));
  });

  test('estimation reports a locked image as retryable', () async {
    final files = _LockedReadFileSystem();
    final store = memoryQueueBlobStore(files);
    final interned = await ReplicationTaskGenerationSnapshot.intern([
      await ReplicationTaskGenerationSnapshot.encode(
        ImageParams(
          prompt: 'locked',
          action: ImageGenerationAction.img2img,
          sourceImage: Uint8List(64),
        ),
      ),
    ], store);
    interned.release();
    files.locked = true;
    final container = ProviderContainer(
      overrides: [
        replicationQueueNotifierProvider.overrideWith(
          () => _SeededQueue([
            ReplicationTask.create(
              prompt: 'locked',
              generationSnapshot: interned.snapshots.single,
            ),
          ]),
        ),
        replicationQueueBlobStoreProvider.overrideWithValue(store),
        queueExecutionNotifierProvider.overrideWith(_IdleQueueExecution.new),
        subscriptionNotifierProvider.overrideWith(_PaidSubscription.new),
      ],
    );
    addTearDown(container.dispose);
    final toolbox = QueueToolbox(
      container.read(_refProvider),
      QueueControlRuntime(),
    );

    final prepared = await execute(
      toolbox,
      'prepare_generation_queue_execution',
      {'action': 'start'},
    );

    expect(prepared['code'], 'queue_images_unavailable');
    expect(prepared['message'], contains('os error 32'));
  });

  group('estimation reads images without hashing them', () {
    const source = 64;

    Future<(MemoryStorageFileSystem, ReplicationTask)> storedTask(
      String prompt,
    ) async {
      final files = MemoryStorageFileSystem();
      final interned = await ReplicationTaskGenerationSnapshot.intern([
        await ReplicationTaskGenerationSnapshot.encode(
          ImageParams(
            prompt: prompt,
            action: ImageGenerationAction.img2img,
            sourceImage: Uint8List(source),
          ),
        ),
      ], memoryQueueBlobStore(files));
      interned.release();
      return (
        files,
        ReplicationTask.create(
          prompt: prompt,
          generationSnapshot: interned.snapshots.single,
        ),
      );
    }

    (_SeededQueue, QueueToolbox) toolboxFor(
      ReplicationTask task,
      ReplicationQueueBlobStore store,
    ) {
      final queue = _SeededQueue([task]);
      final container = ProviderContainer(
        overrides: [
          replicationQueueNotifierProvider.overrideWith(() => queue),
          replicationQueueBlobStoreProvider.overrideWithValue(store),
          queueExecutionNotifierProvider.overrideWith(_IdleQueueExecution.new),
          subscriptionNotifierProvider.overrideWith(_PaidSubscription.new),
        ],
      );
      addTearDown(container.dispose);
      return (
        queue,
        QueueToolbox(container.read(_refProvider), QueueControlRuntime()),
      );
    }

    test('same-length corrupt images still get an estimate', () async {
      final (files, task) = await storedTask('corrupt');
      files.files.updateAll(
        (_, bytes) => Uint8List(bytes.length)..fillRange(0, bytes.length, 7),
      );
      final (_, toolbox) = toolboxFor(task, memoryQueueBlobStore(files));

      final prepared = await execute(
        toolbox,
        'prepare_generation_queue_execution',
        {'action': 'start'},
      );

      expect(prepared['ok'], isTrue, reason: '$prepared');
      expect(files.files.values.single, everyElement(7));
    });

    test('a task deleted while its images load reports a change', () async {
      final (files, task) = await storedTask('deleted');
      final reading = Completer<void>();
      final release = Completer<void>();
      final store = ReplicationQueueBlobStore(
        resolveDirectory: () async => memoryQueueBlobDirectory,
        fileSystem: files,
        worker: <T>(FutureOr<T> Function() run, {String? debugName}) async {
          reading.complete();
          await release.future;
          return run();
        },
      );
      final (queue, toolbox) = toolboxFor(task, store);

      final preparing = execute(toolbox, 'prepare_generation_queue_execution', {
        'action': 'start',
      });
      await reading.future;
      queue.removeTaskForTest(task.id);
      files.files.clear();
      release.complete();

      expect((await preparing)['code'], 'queue_changed');
    });

    test('a locked read after the task was deleted reports a change', () async {
      // Windows 上读到正在删除的文件得到的是拒绝访问，不是文件不存在
      final (stored, task) = await storedTask('deleting');
      final files = _LockedReadFileSystem()..files.addAll(stored.files);
      final reading = Completer<void>();
      final release = Completer<void>();
      final store = ReplicationQueueBlobStore(
        resolveDirectory: () async => memoryQueueBlobDirectory,
        fileSystem: files,
        worker: <T>(FutureOr<T> Function() run, {String? debugName}) async {
          reading.complete();
          await release.future;
          return run();
        },
      );
      final (queue, toolbox) = toolboxFor(task, store);

      final preparing = execute(toolbox, 'prepare_generation_queue_execution', {
        'action': 'start',
      });
      await reading.future;
      queue.removeTaskForTest(task.id);
      files.locked = true;
      release.complete();

      expect((await preparing)['code'], 'queue_changed');
    });
  });

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
        generationSnapshot: ReplicationTaskGenerationSnapshot.withTaskText(
          largeSnapshot,
          prompt: 'changed',
          negativePrompt: '',
        ),
      ),
    );
    expect(await resume(beforeEdit), 'queue_changed');
  });

  group('queue estimate prices what execution submits', () {
    Future<int> estimate(
      ReplicationTask task, {
      int pageImagesPerRequest = 1,
      ImageWorkflowState pageWorkflow = const ImageWorkflowState(),
    }) async {
      final (_, _, toolbox) = build(
        [task],
        pageImagesPerRequest: pageImagesPerRequest,
        pageWorkflow: pageWorkflow,
      );
      final prepared = await execute(
        toolbox,
        'prepare_generation_queue_execution',
        {'action': 'start'},
      );
      expect(prepared['ok'], isTrue, reason: '$prepared');
      return prepared['estimated_anlas'] as int;
    }

    int price(ImageParams params, {required int batchSize}) =>
        AnlasCalculator.calculate(
          params.copyWith(nSamples: 1),
          batchSize: batchSize,
        );

    Future<ReplicationTask> queued(
      ImageParams params, {
      int? batchSize,
      QueuedFocusedInpaint? focused,
    }) async => ReplicationTask.create(
      prompt: params.prompt,
      generationSnapshot: await _stored(
        params,
        batchSize: batchSize,
        focused: focused,
      ),
    );

    const text = ImageParams(prompt: 'batch', steps: 28);

    test(
      'the batch size recorded in the snapshot wins over the page',
      () async {
        final expected = price(text, batchSize: 4);
        expect(expected, isNot(price(text, batchSize: 1)));

        expect(await estimate(await queued(text, batchSize: 4)), expected);
      },
    );

    test('snapshots without a batch size follow the page', () async {
      expect(
        await estimate(await queued(text), pageImagesPerRequest: 3),
        price(text, batchSize: 3),
      );
    });

    group('focused inpaint', () {
      Uint8List png(img.Image image) =>
          Uint8List.fromList(img.encodePng(image));
      final mask = img.fill(
        img.Image(width: 1600, height: 1200),
        color: img.ColorRgb8(0, 0, 0),
      );
      img.fillRect(
        mask,
        x1: 700,
        y1: 500,
        x2: 780,
        y2: 580,
        color: img.ColorRgb8(255, 255, 255),
      );
      final infill = ImageParams(
        prompt: 'focused',
        width: 1600,
        height: 1200,
        steps: 28,
        action: ImageGenerationAction.infill,
        sourceImage: png(img.Image(width: 1600, height: 1200)),
        maskImage: png(mask),
      );
      const enabled = QueuedFocusedInpaint(enabled: true, contextPadding: 88);

      // 期望值取自执行端真正调用的 prepareRequest，而不是估价自己的几何入口
      int focusedPrice() {
        final request = FocusedInpaintUtils.prepareRequest(
          sourceImage: infill.sourceImage!,
          maskImage: infill.maskImage!,
          minContextMegaPixels: enabled.contextPadding,
        )!;
        return price(
          infill.copyWith(
            width: request.targetWidth,
            height: request.targetHeight,
          ),
          batchSize: 1,
        );
      }

      test(
        'a focused snapshot is priced at the focused request size',
        () async {
          final expected = focusedPrice();
          expect(expected, isNot(price(infill, batchSize: 1)));

          expect(
            await estimate(await queued(infill, focused: enabled)),
            expected,
          );
        },
      );

      test(
        'snapshot focus wins; snapshots without it follow the page',
        () async {
          const pageFocused = ImageWorkflowState(
            focusedInpaintEnabled: true,
            minimumContextMegaPixels: 88,
          );

          expect(
            await estimate(
              await queued(
                infill,
                focused: const QueuedFocusedInpaint.disabled(),
              ),
              pageWorkflow: pageFocused,
            ),
            price(infill, batchSize: 1),
          );
          expect(
            await estimate(await queued(infill), pageWorkflow: pageFocused),
            focusedPrice(),
          );
        },
      );
    });
  });
}

class _SeededQueue extends ReplicationQueueNotifier {
  _SeededQueue(this.tasks, {this.completed = const []});

  final List<ReplicationTask> tasks;
  final List<ReplicationTask> completed;

  @override
  ReplicationQueueState build() =>
      ReplicationQueueState(tasks: tasks, completedTasks: completed);

  void removeTaskForTest(String taskId) {
    state = state.copyWith(
      tasks: [
        for (final queued in state.tasks)
          if (queued.id != taskId) queued,
      ],
    );
  }

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

// 非 Opus 档：各尺寸、各批量的价格都非零，估价差异不会被免费额度抹平
class _PaidSubscription extends SubscriptionNotifier {
  @override
  SubscriptionState build() =>
      const SubscriptionState.loaded(UserSubscription(tier: 1, active: true));
}

class _FixedImagesPerRequest extends ImagesPerRequest {
  _FixedImagesPerRequest(this.value);

  final int value;

  @override
  int build() => value;
}

class _FixedWorkflow extends ImageWorkflowController {
  _FixedWorkflow(this.fixed);

  final ImageWorkflowState fixed;

  @override
  ImageWorkflowState build() => fixed;
}

class _LockedReadFileSystem extends MemoryStorageFileSystem {
  bool locked = false;

  @override
  Future<Uint8List> readBytes(String path) async {
    if (locked) {
      throw FileSystemException(
        'injected sharing violation',
        path,
        const OSError('locked', 32),
      );
    }
    return super.readBytes(path);
  }
}
