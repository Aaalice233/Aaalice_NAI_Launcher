import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/app.dart';
import 'package:nai_launcher/data/models/image/image_params.dart'
    show ImageParams;
import 'package:nai_launcher/presentation/providers/generation/generation_params_notifier.dart';
import 'package:nai_launcher/presentation/providers/queue_execution_provider.dart';

// AppBootstrapEffects 生命周期测试共用：进出后台时队列与参数保存都是空操作。

class IdleQueueExecutionNotifier extends QueueExecutionNotifier {
  @override
  QueueExecutionState build() => const QueueExecutionState();
}

class InertGenerationParamsNotifier extends GenerationParamsNotifier {
  @override
  ImageParams build() => const ImageParams();

  @override
  Future<void> saveGenerationState() async {}
}

List<Override> appBackgroundLifecycleOverrides({
  QueueExecutionNotifier Function() queue = IdleQueueExecutionNotifier.new,
}) => [
  queueExecutionNotifierProvider.overrideWith(queue),
  generationParamsNotifierProvider.overrideWith(
    InertGenerationParamsNotifier.new,
  ),
];

/// 挂上只带生命周期副作用的 [AppBootstrapEffects]，测试结束后把绑定的生命周期还原为 resumed。
Future<ProviderContainer> pumpAppBootstrapEffects(
  WidgetTester tester, {
  QueueExecutionNotifier Function() queue = IdleQueueExecutionNotifier.new,
  List<Override> overrides = const [],
}) async {
  final inert = Provider<int>((ref) => 0);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...appBackgroundLifecycleOverrides(queue: queue),
        ...overrides,
      ],
      child: MaterialApp(
        home: AppBootstrapEffects(
          anlasWatcher: inert,
          kritaBridge: inert,
          mcpServer: inert,
          cooccurrenceDataPack: inert,
          cloudSyncLifecycle: () async {},
          child: const SizedBox.shrink(),
        ),
      ),
    ),
  );
  addTearDown(
    () => tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    ),
  );
  return ProviderScope.containerOf(
    tester.element(find.byType(AppBootstrapEffects)),
  );
}
