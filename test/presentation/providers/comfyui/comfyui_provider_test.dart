import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/comfyui/comfyui_models.dart';
import 'package:nai_launcher/core/comfyui/workflow_template.dart';
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
