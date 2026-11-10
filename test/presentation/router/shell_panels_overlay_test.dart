import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/core/storage/queue_state_storage.dart';
import 'package:nai_launcher/core/storage/replication_queue_blob_store_provider.dart';
import 'package:nai_launcher/core/storage/replication_queue_storage.dart';
import 'package:nai_launcher/data/models/prompt_assistant/prompt_assistant_models.dart';
import 'package:nai_launcher/data/models/queue/replication_task.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_chat/providers/agent_chat_notifier.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_chat_panel.dart';
import 'package:nai_launcher/presentation/agent_settings/providers/agent_settings_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/providers/prompt_assistant_config_provider.dart';
import 'package:nai_launcher/presentation/prompt_assistant/providers/web_access_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/queue_execution_provider.dart';
import 'package:nai_launcher/presentation/providers/replication_queue_provider.dart';
import 'package:nai_launcher/presentation/router/shell_panels_overlay.dart';
import 'package:nai_launcher/presentation/widgets/queue/queue_management_page.dart';

import '../../helpers/memory_queue_blob_store.dart';

final _queue = find.byType(QueueManagementPage, skipOffstage: false);
final _agent = find.byType(AgentChatPanel, skipOffstage: false);
final _transition = find.byKey(
  const ValueKey('shell-panel-visibility-transition'),
  skipOffstage: false,
);

void main() {
  testWidgets('手机启动后先加入待办，首次打开队列仍显示上轮 1/1', (tester) async {
    final harness = await _pumpOverlay(
      tester,
      desktop: false,
      reduceMotion: true,
      queueOverrides: [
        queueStateStorageProvider.overrideWithValue(_CompletedQueueStorage()),
        replicationQueueBlobStoreProvider.overrideWithValue(
          memoryQueueBlobStore(),
        ),
        replicationQueueStorageProvider.overrideWithValue(
          _MemoryQueueStorage(),
        ),
        imageGenerationNotifierProvider.overrideWith(_IdleGeneration.new),
      ],
    );
    expect(_queue, findsNothing);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ShellPanelsOverlay)),
    );
    final pending = ReplicationTask.create(prompt: 'new pending task');
    final result = await container
        .read(replicationQueueNotifierProvider.notifier)
        .add(pending);
    expect(result.queuedTaskIds, [pending.id]);
    await tester.pump();
    expect(_queue, findsNothing);

    harness.show(ShellPanel.queue);
    await tester.pump();

    final execution = container.read(queueExecutionNotifierProvider);
    expect((execution.completedCount, execution.totalTasksInSession), (1, 1));
    expect(find.text('100.0%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final desktop in [false, true]) {
    testWidgets('${desktop ? '桌面' : '手机'}队列首次打开才挂载，淡出后静音且重开保留 Tab', (
      tester,
    ) async {
      final harness = await _pumpOverlay(tester, desktop: desktop);
      expect(_queue, findsNothing);
      expect(_agent, findsNothing);

      harness.show(ShellPanel.queue);
      await tester.pump();
      _expectActivity(tester, _queue, enabled: true, offstage: false);
      await _finishTransition(tester);
      final queueState = tester.state(_queue);
      final tabs = tester.widget<TabBar>(find.byType(TabBar)).controller!;
      tabs.index = 1;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      harness.show(null);
      await tester.pump();
      await tester.pump(_duration(tester) ~/ 2);
      _expectActivity(tester, _queue, enabled: true, offstage: false);
      final opacity = tester
          .widget<FadeTransition>(
            find
                .descendant(
                  of: _transition,
                  matching: find.byType(FadeTransition, skipOffstage: false),
                )
                .first,
          )
          .opacity
          .value;
      expect(opacity, greaterThan(0));
      expect(opacity, lessThan(1));
      final pointer = tester.widget<IgnorePointer>(
        find
            .ancestor(
              of: _queue,
              matching: find.byType(IgnorePointer, skipOffstage: false),
            )
            .first,
      );
      final semantics = tester.widget<ExcludeSemantics>(
        find
            .ancestor(
              of: _queue,
              matching: find.byType(ExcludeSemantics, skipOffstage: false),
            )
            .first,
      );
      expect(pointer.ignoring, isTrue);
      expect(semantics.excluding, isTrue);
      expect(find.byKey(const ValueKey('shell-panel-scrim')), findsNothing);

      await _finishTransition(tester);
      _expectActivity(tester, _queue, enabled: false, offstage: true);

      harness.show(ShellPanel.queue);
      await tester.pump();
      _expectActivity(tester, _queue, enabled: true, offstage: false);
      expect(tester.state(_queue), same(queueState));
      expect(tester.widget<TabBar>(find.byType(TabBar)).controller, same(tabs));
      expect(tabs.index, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('队列与 Agent 切换时仅当前面板启用 Ticker，关闭 Agent 后整块静音', (tester) async {
    final harness = await _pumpOverlay(tester);
    harness.show(ShellPanel.queue);
    await tester.pump();
    await _finishTransition(tester);
    final queueState = tester.state(_queue);

    harness.show(ShellPanel.agent);
    await tester.pump();
    _expectActivity(tester, _queue, enabled: false, offstage: false);
    _expectActivity(tester, _agent, enabled: true, offstage: false);
    final agentState = tester.state(_agent);

    harness.show(null);
    await tester.pump();
    _expectActivity(tester, _agent, enabled: true, offstage: false);
    await _finishTransition(tester);
    _expectActivity(tester, _queue, enabled: false, offstage: true);
    _expectActivity(tester, _agent, enabled: false, offstage: true);

    harness.show(ShellPanel.queue);
    await tester.pump();
    _expectActivity(tester, _queue, enabled: true, offstage: false);
    _expectActivity(tester, _agent, enabled: false, offstage: false);
    expect(tester.state(_queue), same(queueState));

    harness.show(ShellPanel.agent);
    await tester.pump();
    _expectActivity(tester, _agent, enabled: true, offstage: false);
    expect(tester.state(_agent), same(agentState));
    expect(tester.takeException(), isNull);
  });

  testWidgets('首次只打开 Agent 不挂载队列', (tester) async {
    final harness = await _pumpOverlay(tester);
    harness.show(ShellPanel.agent);
    await tester.pump();

    expect(_queue, findsNothing);
    _expectActivity(tester, _agent, enabled: true, offstage: false);
    expect(tester.takeException(), isNull);
  });

  testWidgets('减少动态效果时关闭立即 Offstage 并静音，重开保留状态', (tester) async {
    final harness = await _pumpOverlay(tester, reduceMotion: true);
    harness.show(ShellPanel.queue);
    await tester.pump();
    final queueState = tester.state(_queue);
    _expectActivity(tester, _queue, enabled: true, offstage: false);
    expect(_duration(tester), Duration.zero);

    harness.show(null);
    await tester.pump();
    _expectActivity(tester, _queue, enabled: false, offstage: true);
    harness.setReduceMotion(false);
    await tester.pump();
    _expectActivity(tester, _queue, enabled: false, offstage: true);

    harness.show(ShellPanel.queue);
    await tester.pump();
    _expectActivity(tester, _queue, enabled: true, offstage: false);
    expect(tester.state(_queue), same(queueState));
    expect(tester.takeException(), isNull);
  });

  testWidgets('淡出中开启减少动态效果立即静音，关闭该设置不重新激活隐藏面板', (tester) async {
    final harness = await _pumpOverlay(tester);
    harness.show(ShellPanel.queue);
    await tester.pump();
    await _finishTransition(tester);
    harness.show(null);
    await tester.pump();
    await tester.pump(_duration(tester) ~/ 2);
    _expectActivity(tester, _queue, enabled: true, offstage: false);

    harness.setReduceMotion(true);
    await tester.pump();
    _expectActivity(tester, _queue, enabled: false, offstage: true);
    harness.setReduceMotion(false);
    await tester.pump();
    _expectActivity(tester, _queue, enabled: false, offstage: true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('淡出中重新打开不会被淡入的 onEnd 隐藏', (tester) async {
    final harness = await _pumpOverlay(tester);
    harness.show(ShellPanel.queue);
    await tester.pump();
    await _finishTransition(tester);
    harness.show(null);
    await tester.pump();
    await tester.pump(_duration(tester) ~/ 2);

    harness.show(ShellPanel.queue);
    await tester.pump();
    _expectActivity(tester, _queue, enabled: true, offstage: false);
    await _finishTransition(tester);
    _expectActivity(tester, _queue, enabled: true, offstage: false);
    expect(tester.takeException(), isNull);
  });
}

Duration _duration(WidgetTester tester) =>
    tester.widget<AnimatedOpacity>(_transition).duration;

Future<void> _finishTransition(WidgetTester tester) async {
  await tester.pump(_duration(tester) + const Duration(milliseconds: 1));
  await tester.pump();
}

void _expectActivity(
  WidgetTester tester,
  Finder panel, {
  required bool enabled,
  required bool offstage,
}) {
  expect(panel, findsOneWidget);
  expect(TickerMode.valuesOf(tester.element(panel)).enabled, enabled);
  final offstages = tester.widgetList<Offstage>(
    find.ancestor(
      of: panel,
      matching: find.byType(Offstage, skipOffstage: false),
    ),
  );
  expect(offstages.any((widget) => widget.offstage), offstage);
}

Future<_OverlayHarness> _pumpOverlay(
  WidgetTester tester, {
  bool desktop = true,
  bool reduceMotion = false,
  List<Override>? queueOverrides,
}) async {
  final harness = _OverlayHarness(reduceMotion);
  addTearDown(harness.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(_MemoryStorage()),
        ...(queueOverrides ??
            [
              queueExecutionNotifierProvider.overrideWith(_IdleQueue.new),
              replicationQueueNotifierProvider.overrideWith(_EmptyQueue.new),
            ]),
        agentChatNotifierProvider.overrideWith(_IdleAgent.new),
        agentSettingsProvider.overrideWith(_AgentSettings.new),
        promptAssistantConfigProvider.overrideWith(_AssistantConfig.new),
        webAccessConfigProvider.overrideWith(_WebAccessConfig.new),
      ],
      child: MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ValueListenableBuilder<bool>(
          valueListenable: harness.reduceMotion,
          builder: (context, reduceMotion, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion),
            child: child!,
          ),
          child: ListenableBuilder(
            listenable: harness,
            builder: (context, _) => ShellPanelsOverlay(
              activePanel: harness.activePanel,
              desktop: desktop,
              onClose: () => harness.show(null),
              onQueueStarted: () {},
              onOpenAgentSettings: () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return harness;
}

class _OverlayHarness extends ChangeNotifier {
  _OverlayHarness(bool reduceMotion)
    : reduceMotion = ValueNotifier(reduceMotion);

  ShellPanel? activePanel;
  final ValueNotifier<bool> reduceMotion;

  void show(ShellPanel? panel) {
    activePanel = panel;
    notifyListeners();
  }

  void setReduceMotion(bool value) {
    reduceMotion.value = value;
  }

  @override
  void dispose() {
    reduceMotion.dispose();
    super.dispose();
  }
}

class _MemoryStorage extends LocalStorageService {
  @override
  T? getSetting<T>(String key, {T? defaultValue}) => defaultValue;
}

class _IdleQueue extends QueueExecutionNotifier {
  @override
  QueueExecutionState build() => const QueueExecutionState();
}

class _EmptyQueue extends ReplicationQueueNotifier {
  @override
  ReplicationQueueState build() => const ReplicationQueueState();
}

class _CompletedQueueStorage extends QueueStateStorage {
  @override
  QueueExecutionStateData loadExecutionState() =>
      const QueueExecutionStateData(completedCount: 1);

  @override
  List<ReplicationTask> loadFailedTasks() => const [];
}

class _MemoryQueueStorage extends ReplicationQueueStorage {
  @override
  List<ReplicationTask> load() => const [];

  @override
  Future<void> save(List<ReplicationTask> tasks) async {}
}

class _IdleGeneration extends ImageGenerationNotifier {
  @override
  ImageGenerationState build() => const ImageGenerationState();
}

class _IdleAgent extends AgentChatNotifier {
  @override
  AgentChatState build() => const AgentChatState(initialized: true);

  @override
  Future<void> ensureInitialized() async {}
}

class _AgentSettings extends AgentSettingsNotifier {
  @override
  AgentSettingsState build() => const AgentSettingsState(initialized: true);
}

class _AssistantConfig extends PromptAssistantConfigNotifier {
  @override
  PromptAssistantConfigState build() => PromptAssistantConfigState.defaults();
}

class _WebAccessConfig extends WebAccessConfigNotifier {
  @override
  WebAccessConfigState build() => const WebAccessConfigState(initialized: true);
}
