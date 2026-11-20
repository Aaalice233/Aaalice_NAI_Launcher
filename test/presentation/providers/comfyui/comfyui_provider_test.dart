import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/comfyui/comfyui.dart';
import 'package:nai_launcher/presentation/providers/comfyui/comfyui_provider.dart';

void main() {
  test('发起界面关闭后，执行中的任务仍跑完并写回状态', () async {
    final connected = Completer<bool>();
    final container = ProviderContainer(
      overrides: [
        comfyUIConnectionProvider.overrideWith(
          () => _GatedConnection(connected.future),
        ),
        comfyUIWorkflowsProvider.overrideWith(_EmptyWorkflows.new),
      ],
    );
    addTearDown(container.dispose);

    final dialog = container.listen(comfyUITaskProvider, (_, _) {});
    final execution = container
        .read(comfyUITaskProvider.notifier)
        .execute(templateId: 'img2img');
    dialog.close();
    // 让无订阅者时排队的回收任务先执行，再放行连接结果
    await Future<void>.delayed(Duration.zero);
    connected.complete(false);

    expect(await execution, isNull);
    final state = container.read(comfyUITaskProvider);
    expect(state.status, ComfyUITaskStatus.failed);
    expect(state.errorCode, ComfyUITaskErrorCode.connectionFailed);
  });

  test('任务结束且无人订阅后照常回收', () async {
    final container = ProviderContainer(
      overrides: [
        comfyUIConnectionProvider.overrideWith(
          () => _GatedConnection(Future.value(false)),
        ),
        comfyUIWorkflowsProvider.overrideWith(_EmptyWorkflows.new),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(comfyUITaskProvider.notifier);
    await notifier.execute(templateId: 'img2img');

    await container.pump();
    expect(container.read(comfyUITaskProvider.exists), isFalse);
  });

  test('上传中只关闭对话框，上传完成后提交一次', () async {
    final fixture = _ConnectedTaskFixture();
    final upload = Completer<String>();
    final dialog = fixture.container.listen(comfyUITaskProvider, (_, _) {});
    final execution = fixture.execute(upload.future);
    dialog.close();

    await fixture.container.pump();
    upload.complete('input.png');

    expect(await execution, fixture.outputImages);
    expect(fixture.submittedPrompts, 1);
  });

  test('上传中取消后关闭对话框，不提交工作流且保持取消状态', () async {
    final fixture = _ConnectedTaskFixture();
    final upload = Completer<String>();
    final dialog = fixture.container.listen(comfyUITaskProvider, (_, _) {});
    final execution = fixture.execute(upload.future);
    fixture.notifier.cancel();
    dialog.close();

    await fixture.container.pump();
    upload.complete('discarded.png');

    expect(await execution, isNull);
    expect(fixture.submittedPrompts, 0);
    expect(fixture.observer.statuses, [
      ComfyUITaskStatus.uploading,
      ComfyUITaskStatus.cancelled,
    ]);
    verify(fixture.api.interrupt).called(1);
    verifyNever(() => fixture.api.getObjectInfo());
  });

  test('下一次执行可以在已取消的上传返回前开始', () async {
    final fixture = _ConnectedTaskFixture();
    final firstUpload = Completer<String>();
    final nextUpload = Completer<String>();
    final dialog = fixture.container.listen(comfyUITaskProvider, (_, _) {});
    addTearDown(dialog.close);
    final firstExecution = fixture.execute(firstUpload.future);
    fixture.notifier.cancel();
    final nextExecution = fixture.execute(nextUpload.future);

    firstUpload.complete('discarded.png');
    nextUpload.complete('new.png');
    final results = await Future.wait([firstExecution, nextExecution]);

    expect(results, [null, fixture.outputImages]);
    expect(fixture.submittedPrompts, 1);
    expect(dialog.read().status, ComfyUITaskStatus.completed);
  });

  test('上传失败返回时保留已经取消的状态', () async {
    final fixture = _ConnectedTaskFixture();
    final upload = Completer<String>();
    final dialog = fixture.container.listen(comfyUITaskProvider, (_, _) {});
    addTearDown(dialog.close);
    final execution = fixture.execute(upload.future);
    fixture.notifier.cancel();

    upload.completeError(const ComfyUIApiException('upload failed'));

    expect(await execution, isNull);
    expect(fixture.submittedPrompts, 0);
    expect(dialog.read().status, ComfyUITaskStatus.cancelled);
  });

  test('等待节点校验时取消，校验返回后不提交工作流', () async {
    final fixture = _ConnectedTaskFixture();
    final validating = Completer<void>();
    final validation = Completer<Map<String, dynamic>>();
    when(() => fixture.api.getObjectInfo()).thenAnswer((_) {
      validating.complete();
      return validation.future;
    });
    final dialog = fixture.container.listen(comfyUITaskProvider, (_, _) {});
    addTearDown(dialog.close);
    final execution = fixture.execute(Future.value('input.png'));
    await validating.future;
    fixture.notifier.cancel();

    validation.complete(_objectInfo);

    expect(await execution, isNull);
    expect(fixture.submittedPrompts, 0);
    expect(dialog.read().status, ComfyUITaskStatus.cancelled);
  });
}

final class _GatedConnection extends ComfyUIConnection {
  _GatedConnection(this._result);

  final Future<bool> _result;

  @override
  ComfyUIConnectionStatus build() => ComfyUIConnectionStatus.disconnected;

  @override
  Future<bool> connect() => _result;
}

final class _EmptyWorkflows extends ComfyUIWorkflows {
  @override
  List<WorkflowTemplate> build() => const [];
}

const _objectInfo = <String, dynamic>{'LoadImage': <String, dynamic>{}};

final class _ConnectedTaskFixture {
  _ConnectedTaskFixture() {
    final ws = _MockWebSocket();
    final manager = _MockConnectionManager();
    when(() => manager.api).thenReturn(api);
    when(() => manager.ws).thenReturn(ws);
    when(() => manager.clientId).thenReturn('test-client');
    when(() => ws.imageStream).thenAnswer((_) => const Stream.empty());
    when(() => ws.progressStream).thenAnswer(
      (_) => Stream.value(
        const ComfyUIProgress(
          promptId: 'test-prompt',
          status: ComfyUITaskStatus.completed,
        ),
      ),
    );
    when(() => api.getObjectInfo()).thenAnswer((_) async => _objectInfo);
    when(
      () => api.queuePrompt(
        workflow: any(named: 'workflow'),
        clientId: 'test-client',
      ),
    ).thenAnswer((_) async {
      submittedPrompts++;
      return const ComfyUIPromptResult(promptId: 'test-prompt');
    });
    when(
      () => api.getOutputImages('test-prompt', allowedNodeIds: {}),
    ).thenAnswer((_) async => outputImages);
    when(api.interrupt).thenAnswer((_) async {});
    container = ProviderContainer(
      overrides: [
        comfyUIConnectionProvider.overrideWith(() => _Connected(manager)),
        comfyUIWorkflowsProvider.overrideWith(_TestWorkflows.new),
      ],
      observers: [observer],
    );
    addTearDown(container.dispose);
  }

  late final ProviderContainer container;
  final api = _MockApi();
  final observer = _TaskObserver();
  final outputImages = [
    Uint8List.fromList([42]),
  ];
  int submittedPrompts = 0;

  ComfyUITask get notifier => container.read(comfyUITaskProvider.notifier);

  Future<List<Uint8List>?> execute(Future<String> upload) {
    final image = Uint8List(1);
    when(
      () => api.uploadImage(
        imageBytes: image,
        filename: any(named: 'filename'),
      ),
    ).thenAnswer((_) => upload);
    return notifier.execute(
      templateId: _TemplateManager.template.id,
      inputImages: {'image': image},
    );
  }
}

final class _TaskObserver extends ProviderObserver {
  final statuses = <ComfyUITaskStatus>[];

  @override
  void didUpdateProvider(
    ProviderObserverContext context,
    Object? previousValue,
    Object? newValue,
  ) {
    if (context.provider == comfyUITaskProvider &&
        newValue is ComfyUITaskState &&
        newValue.status != (previousValue as ComfyUITaskState).status) {
      statuses.add(newValue.status);
    }
  }
}

final class _MockApi extends Mock implements ComfyUIApiService {}

final class _MockWebSocket extends Mock implements ComfyUIWebSocketService {}

final class _MockConnectionManager extends Mock
    implements ComfyUIConnectionManager {}

final class _Connected extends ComfyUIConnection {
  _Connected(this.manager);

  @override
  final ComfyUIConnectionManager manager;

  @override
  ComfyUIConnectionStatus build() => ComfyUIConnectionStatus.connected;
}

final class _TestWorkflows extends ComfyUIWorkflows {
  @override
  final WorkflowTemplateManager manager = _TemplateManager();

  @override
  List<WorkflowTemplate> build() => const [_TemplateManager.template];
}

final class _TemplateManager extends WorkflowTemplateManager {
  static const template = WorkflowTemplate(
    id: 'img2img',
    name: 'Img2Img',
    description: '',
    slots: [
      WorkflowSlot(
        id: 'image',
        direction: SlotDirection.input,
        dataType: SlotDataType.image,
        nodeId: '1',
        field: 'image',
        label: 'Input',
        required: true,
      ),
    ],
    workflowJson: {
      '1': {
        'class_type': 'LoadImage',
        'inputs': {'image': ''},
      },
    },
  );

  @override
  WorkflowTemplate? getById(String id) => id == template.id ? template : null;
}
