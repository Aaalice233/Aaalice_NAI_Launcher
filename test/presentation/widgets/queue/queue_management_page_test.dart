import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/queue/replication_task.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/adaptive/interaction_policy.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/queue_execution_provider.dart';
import 'package:nai_launcher/presentation/providers/replication_queue_provider.dart';
import 'package:nai_launcher/presentation/widgets/common/adaptive_dialog_frame.dart';
import 'package:nai_launcher/presentation/widgets/queue/queue_management_page.dart';
import 'package:nai_launcher/presentation/widgets/queue/task_edit_dialog.dart';
import 'package:nai_launcher/presentation/widgets/queue/task_list_item.dart';

void main() {
  Widget buildApp({double textScale = 1}) {
    return ProviderScope(
      overrides: [
        replicationQueueNotifierProvider.overrideWith(_EmptyQueueNotifier.new),
        queueExecutionNotifierProvider.overrideWith(_IdleExecutionNotifier.new),
        generationParamsNotifierProvider.overrideWith(
          _EmptyGenerationParamsNotifier.new,
        ),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const QueueManagementPage(),
      ),
    );
  }

  testWidgets('空队列在软键盘压缩后的高度内不会溢出', (tester) async {
    await tester.binding.setSurfaceSize(const Size(460, 485));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildApp());
    await tester.pump();

    expect(find.text('队列为空'), findsOneWidget);
    expect(find.byType(SingleChildScrollView), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('窄屏 3x 字号下统计与操作改为纵向布局', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(buildApp(textScale: 3));
    await tester.pump();

    expect(find.text('执行进度'), findsOneWidget);
    expect(find.byKey(const Key('queue-add-current-task')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('触屏任务详情与显式菜单可达并执行选择、编辑和删除', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildTouchQueueApp());
    await tester.pumpAndSettle();

    expect(find.byTooltip('调整任务顺序').hitTestable(), findsOneWidget);
    expect(find.byTooltip('更多任务操作').hitTestable(), findsOneWidget);

    await tester.tap(find.text('touch-detail-prompt'));
    await tester.pumpAndSettle();
    expect(find.byType(QueueTaskDetailView), findsOneWidget);
    expect(find.text('任务详情'), findsOneWidget);
    expect(find.textContaining('nai-diffusion-3-full'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多任务操作'));
    await tester.pumpAndSettle();
    expect(find.text('选择任务'), findsOneWidget);
    expect(find.text('编辑'), findsOneWidget);
    expect(find.text('删除'), findsOneWidget);
    await tester.tap(find.text('选择任务'));
    await tester.pumpAndSettle();
    expect(find.text('已选 1 个'), findsOneWidget);
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多任务操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditDialog), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('更多任务操作'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();

    expect(find.text('touch-detail-prompt'), findsNothing);
    expect(find.text('队列为空'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('任务编辑真实入口在 320、3x、SafeArea 和 IME 下全屏且操作可达', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _buildTaskDialogLauncher(
        textScale: 3,
        padding: const EdgeInsets.fromLTRB(8, 18, 8, 6),
        viewInsets: const EdgeInsets.only(bottom: 180),
      ),
    );
    await tester.tap(find.byKey(const Key('open-task-edit')));
    await tester.pumpAndSettle();

    expect(find.byType(TaskEditDialog), findsOneWidget);
    expect(find.byType(AdaptiveDialogFrame), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('task-edit-dialog-scroll'))).width,
      304,
    );

    final scrollable = find
        .descendant(
          of: find.byKey(const Key('task-edit-dialog-scroll')),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const Key('task-edit-parameters-toggle')),
      120,
      scrollable: scrollable,
    );
    await tester.tap(find.byKey(const Key('task-edit-parameters-toggle')));
    await tester.pump();
    expect(find.text('nai-diffusion-3-full'), findsOneWidget);

    for (final key in const [
      Key('task-edit-duplicate'),
      Key('task-edit-cancel'),
      Key('task-edit-save'),
    ]) {
      await tester.scrollUntilVisible(
        find.byKey(key),
        120,
        scrollable: scrollable,
      );
      expect(find.byKey(key).hitTestable(), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('任务编辑真实入口在 Medium 和 Expanded 保持有界', (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final size in const [Size(700, 900), Size(1600, 900)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(_buildTaskDialogLauncher());
      await tester.tap(find.byKey(const Key('open-task-edit')));
      await tester.pumpAndSettle();

      expect(find.byType(AdaptiveDialogFrame), findsOneWidget);
      expect(
        tester.getSize(find.byType(AdaptiveDialogFrame)).width,
        lessThanOrEqualTo(560),
      );
      expect(
        tester.getSize(find.byType(AdaptiveDialogFrame)).height,
        lessThanOrEqualTo(720),
      );
      expect(tester.takeException(), isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('任务编辑取消和系统返回均不保存并关闭', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_buildTaskDialogLauncher());
    await tester.tap(find.byKey(const Key('open-task-edit')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('task-edit-cancel')),
      100,
      scrollable: find
          .descendant(
            of: find.byKey(const Key('task-edit-dialog-scroll')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const Key('task-edit-cancel')));
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditDialog), findsNothing);

    await tester.tap(find.byKey(const Key('open-task-edit')));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

Widget _buildTouchQueueApp() {
  return ProviderScope(
    overrides: [
      replicationQueueNotifierProvider.overrideWith(_TouchQueueNotifier.new),
      queueExecutionNotifierProvider.overrideWith(_IdleExecutionNotifier.new),
      generationParamsNotifierProvider.overrideWith(
        _EmptyGenerationParamsNotifier.new,
      ),
    ],
    child: const InteractionPolicyScope(
      initialPolicy: InteractionPolicy.touchFirst,
      child: MaterialApp(
        locale: Locale('zh'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: QueueManagementPage(),
      ),
    ),
  );
}

Widget _buildTaskDialogLauncher({
  double textScale = 1,
  EdgeInsets padding = EdgeInsets.zero,
  EdgeInsets viewInsets = EdgeInsets.zero,
}) {
  final task = ReplicationTask(
    id: 'responsive-task',
    prompt: '1girl, landscape',
    createdAt: DateTime(2026),
    seed: 42,
    sampler: 'k_euler',
    steps: 28,
    cfgScale: 5,
    model: 'nai-diffusion-3-full',
    width: 832,
    height: 1216,
  );

  return ProviderScope(
    overrides: [
      replicationQueueNotifierProvider.overrideWith(_EmptyQueueNotifier.new),
    ],
    child: MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          padding: padding,
          viewInsets: viewInsets,
        ),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              key: const Key('open-task-edit'),
              onPressed: () =>
                  TaskEditDialog.show(context: context, task: task),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
}

class _EmptyQueueNotifier extends ReplicationQueueNotifier {
  @override
  ReplicationQueueState build() => const ReplicationQueueState();
}

class _TouchQueueNotifier extends ReplicationQueueNotifier {
  @override
  ReplicationQueueState build() => ReplicationQueueState(
    tasks: [
      ReplicationTask(
        id: 'touch-task',
        prompt: 'touch-detail-prompt',
        negativePrompt: 'lowres',
        applyNegativePrompt: true,
        createdAt: DateTime(2026),
        seed: 42,
        sampler: 'k_euler',
        steps: 28,
        cfgScale: 5,
        model: 'nai-diffusion-3-full',
        width: 832,
        height: 1216,
      ),
    ],
  );

  @override
  Future<bool> remove(String taskId) async {
    state = state.copyWith(
      tasks: state.tasks.where((task) => task.id != taskId).toList(),
    );
    return true;
  }
}

class _IdleExecutionNotifier extends QueueExecutionNotifier {
  @override
  QueueExecutionState build() => const QueueExecutionState();
}

class _EmptyGenerationParamsNotifier extends GenerationParamsNotifier {
  @override
  ImageParams build() => const ImageParams();
}
