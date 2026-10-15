import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/shortcuts/default_shortcuts.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/widgets/shortcuts/shortcut_aware_widget.dart';

class _ControlledShortcutConfigNotifier extends ShortcutConfigNotifier {
  final Completer<ShortcutConfig> _pendingLoad = Completer<ShortcutConfig>();

  @override
  Future<ShortcutConfig> build() => _pendingLoad.future;

  void emit(AsyncValue<ShortcutConfig> value) => state = value;
}

class _Probe extends StatefulWidget {
  const _Probe({required this.onInit});

  final VoidCallback onInit;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  final FocusNode textFocus = FocusNode(debugLabel: 'probe-text');

  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  void dispose() {
    textFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(child: TextField(focusNode: textFocus));
  }
}

class _Host extends StatefulWidget {
  const _Host({
    super.key,
    required this.contextType,
    required this.buildShortcuts,
    required this.child,
  });

  final ShortcutContext contextType;
  final Map<String, VoidCallback> Function() buildShortcuts;
  final Widget child;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  int _generation = 0;

  void rebuild() => setState(() => _generation++);

  @override
  Widget build(BuildContext context) {
    // 与真实调用方一致：每次 build 传入新的回调映射
    return ShortcutAwareWidget(
      key: const ValueKey('shortcut-aware'),
      contextType: widget.contextType,
      shortcuts: widget.buildShortcuts(),
      autofocus: true,
      child: widget.child,
    );
  }
}

class _Harness {
  _Harness(this.tester, this.notifier, this.hostKey);

  final WidgetTester tester;
  final _ControlledShortcutConfigNotifier notifier;
  final GlobalKey<_HostState> hostKey;
  int probeInits = 0;
  final Map<String, int> invocations = {};

  _ProbeState get probe => tester.state<_ProbeState>(find.byType(_Probe));

  Future<void> rebuildParent() async {
    hostKey.currentState!.rebuild();
    await tester.pump();
  }

  Future<void> emit(AsyncValue<ShortcutConfig> value) async {
    notifier.emit(value);
    await tester.pump();
  }

  Future<void> press(
    List<LogicalKeyboardKey> modifiers,
    LogicalKeyboardKey key,
  ) async {
    for (final modifier in modifiers) {
      await tester.sendKeyDownEvent(modifier);
    }
    await tester.sendKeyEvent(key);
    for (final modifier in modifiers.reversed) {
      await tester.sendKeyUpEvent(modifier);
    }
    await tester.pump();
  }

  int count(String shortcutId) => invocations[shortcutId] ?? 0;
}

Future<_Harness> _pumpHarness(
  WidgetTester tester, {
  ShortcutContext contextType = ShortcutContext.generation,
  List<String> shortcutIds = const [ShortcutIds.generateImage],
}) async {
  final notifier = _ControlledShortcutConfigNotifier();
  final hostKey = GlobalKey<_HostState>();
  late final _Harness harness;
  final probe = _Probe(onInit: () => harness.probeInits++);
  harness = _Harness(tester, notifier, hostKey);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [shortcutConfigNotifierProvider.overrideWith(() => notifier)],
      child: MaterialApp(
        home: _Host(
          key: hostKey,
          contextType: contextType,
          buildShortcuts: () => {
            for (final id in shortcutIds)
              id: () => harness.invocations[id] = harness.count(id) + 1,
          },
          child: probe,
        ),
      ),
    ),
  );
  await tester.pump();
  return harness;
}

class _DeferredMount extends StatefulWidget {
  const _DeferredMount({super.key, required this.child});

  final Widget child;

  @override
  State<_DeferredMount> createState() => _DeferredMountState();
}

class _DeferredMountState extends State<_DeferredMount> {
  bool _mounted = false;

  void mount() => setState(() => _mounted = true);

  @override
  Widget build(BuildContext context) =>
      _mounted ? widget.child : const SizedBox.shrink();
}

/// 配置先就绪再挂载 ShortcutAwareWidget，对应页面在应用启动完成后才打开的情形
Future<_ControlledShortcutConfigNotifier> _pumpMountedAfterReady(
  WidgetTester tester, {
  required ShortcutConfig config,
  required Widget Function(_ControlledShortcutConfigNotifier notifier) build,
}) async {
  final notifier = _ControlledShortcutConfigNotifier();
  final gateKey = GlobalKey<_DeferredMountState>();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [shortcutConfigNotifierProvider.overrideWith(() => notifier)],
      child: MaterialApp(
        home: _DeferredMount(key: gateKey, child: build(notifier)),
      ),
    ),
  );
  ProviderScope.containerOf(
    gateKey.currentContext!,
  ).read(shortcutConfigNotifierProvider);
  notifier.emit(_ready(config));
  gateKey.currentState!.mount();
  await tester.pump();
  await tester.pump();
  return notifier;
}

bool _isAnchor(FocusNode? node) =>
    node?.debugLabel?.startsWith('ShortcutAwareWidget') ?? false;

ShortcutConfig get _defaults => ShortcutConfig.createDefault();

AsyncValue<ShortcutConfig> _ready(ShortcutConfig config) =>
    AsyncValue.data(config);

AsyncValue<ShortcutConfig> _failed() =>
    AsyncValue.error(StateError('storage unavailable'), StackTrace.empty);

const _ctrl = [LogicalKeyboardKey.controlLeft];

void main() {
  group('子树稳定性', () {
    testWidgets('加载态下父级重建不重建 child State', (tester) async {
      final harness = await _pumpHarness(tester);
      final original = harness.probe;

      await harness.rebuildParent();
      await harness.rebuildParent();

      expect(harness.probeInits, 1);
      expect(identical(harness.probe, original), isTrue);
    });

    testWidgets('就绪态下父级重建不重建 child State', (tester) async {
      final harness = await _pumpHarness(tester);
      await harness.emit(_ready(_defaults));
      final original = harness.probe;
      final initsBeforeRebuild = harness.probeInits;

      await harness.rebuildParent();

      expect(harness.probeInits, initsBeforeRebuild);
      expect(identical(harness.probe, original), isTrue);
    });

    testWidgets('加载→就绪保留 child State', (tester) async {
      final harness = await _pumpHarness(tester);
      final original = harness.probe;

      await harness.emit(_ready(_defaults));

      expect(harness.probeInits, 1);
      expect(identical(harness.probe, original), isTrue);
    });

    testWidgets('就绪后修改绑定保留 child State', (tester) async {
      final harness = await _pumpHarness(tester);
      await harness.emit(_ready(_defaults));
      final original = harness.probe;

      await harness.emit(
        _ready(
          _defaults.setCustomShortcut(ShortcutIds.generateImage, 'ctrl+g'),
        ),
      );

      expect(harness.probeInits, 1);
      expect(identical(harness.probe, original), isTrue);
    });

    testWidgets('启用↔禁用快捷键保留 child State', (tester) async {
      final harness = await _pumpHarness(tester);
      await harness.emit(_ready(_defaults));
      final original = harness.probe;

      await harness.emit(_ready(_defaults.copyWith(enableShortcuts: false)));
      await harness.emit(_ready(_defaults));

      expect(harness.probeInits, 1);
      expect(identical(harness.probe, original), isTrue);
    });

    testWidgets('无可用快捷键与有快捷键之间切换保留 child State', (tester) async {
      final harness = await _pumpHarness(tester);
      await harness.emit(_ready(_defaults));
      final original = harness.probe;

      await harness.emit(
        _ready(_defaults.setEnabled(ShortcutIds.generateImage, false)),
      );
      await harness.emit(_ready(_defaults));

      expect(harness.probeInits, 1);
      expect(identical(harness.probe, original), isTrue);
    });

    testWidgets('加载→出错及出错态父级重建保留 child State', (tester) async {
      final harness = await _pumpHarness(tester);
      final original = harness.probe;

      await harness.emit(_failed());
      await harness.rebuildParent();
      await harness.emit(_ready(_defaults));

      expect(harness.probeInits, 1);
      expect(identical(harness.probe, original), isTrue);
    });
  });

  group('焦点', () {
    testWidgets('首次挂载时 autofocus 把焦点落在快捷键作用域内', (tester) async {
      await _pumpHarness(tester);

      final primary = FocusManager.instance.primaryFocus;
      expect(primary, isNotNull);
      expect(primary!.context, isNotNull);
      expect(
        primary.context!.findAncestorWidgetOfExactType<ShortcutAwareWidget>(),
        isNotNull,
      );
    });

    testWidgets('外部传入的 focusNode 作为锚点获得焦点且由调用方负责销毁', (tester) async {
      final external = FocusNode(debugLabel: 'external-anchor');
      addTearDown(external.dispose);
      final notifier = _ControlledShortcutConfigNotifier();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shortcutConfigNotifierProvider.overrideWith(() => notifier),
          ],
          child: MaterialApp(
            home: ShortcutAwareWidget(
              contextType: ShortcutContext.generation,
              shortcuts: {ShortcutIds.generateImage: () {}},
              autofocus: true,
              focusNode: external,
              child: const SizedBox.shrink(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(external.hasPrimaryFocus, isTrue);
      expect(external.skipTraversal, isFalse, reason: '外部节点按原样使用');

      await tester.pumpWidget(const SizedBox.shrink());
      expect(external.skipTraversal, isFalse);
      void listener() {}
      expect(() => external.addListener(listener), returnsNormally);
      external.removeListener(listener);
    });

    testWidgets('更换 focusNode 时锚点上的焦点转移到新节点', (tester) async {
      final first = FocusNode(debugLabel: 'external-first');
      final second = FocusNode(debugLabel: 'external-second');
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      final notifier = _ControlledShortcutConfigNotifier();
      FocusNode? current;
      late StateSetter setHostState;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shortcutConfigNotifierProvider.overrideWith(() => notifier),
          ],
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) {
                setHostState = setState;
                return ShortcutAwareWidget(
                  contextType: ShortcutContext.generation,
                  shortcuts: {ShortcutIds.generateImage: () {}},
                  autofocus: true,
                  focusNode: current,
                  child: const SizedBox.shrink(),
                );
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_isAnchor(FocusManager.instance.primaryFocus), isTrue);

      Future<void> switchTo(FocusNode? node) async {
        setHostState(() => current = node);
        await tester.pump();
        await tester.pump();
      }

      await switchTo(first);
      expect(first.hasPrimaryFocus, isTrue, reason: '自有节点 → 外部节点');

      await switchTo(second);
      expect(second.hasPrimaryFocus, isTrue, reason: '外部节点 → 外部节点');

      await switchTo(null);
      expect(
        _isAnchor(FocusManager.instance.primaryFocus),
        isTrue,
        reason: '外部节点 → 自有节点',
      );
      expect(first.skipTraversal, isFalse);
      expect(second.skipTraversal, isFalse);
    });

    final childFirstScenarios = <String, (ShortcutConfig, ShortcutContext)>{
      '快捷键全局关闭': (
        ShortcutConfig.createDefault().copyWith(enableShortcuts: false),
        ShortcutContext.generation,
      ),
      '当前页面没有可用快捷键': (ShortcutConfig.createDefault(), ShortcutContext.gallery),
    };
    for (final MapEntry(key: name, value: (config, contextType))
        in childFirstScenarios.entries) {
      testWidgets('$name时子组件自己的 autofocus 生效并能收到按键', (tester) async {
        final listenerFocus = FocusNode(debugLabel: 'child-listener');
        addTearDown(listenerFocus.dispose);
        var undoPresses = 0;

        await _pumpMountedAfterReady(
          tester,
          config: config,
          build: (_) => ShortcutAwareWidget(
            contextType: contextType,
            shortcuts: {ShortcutIds.generateImage: () {}},
            autofocus: true,
            child: KeyboardListener(
              focusNode: listenerFocus,
              autofocus: true,
              onKeyEvent: (event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.keyZ) {
                  undoPresses++;
                }
              },
              child: const SizedBox.shrink(),
            ),
          ),
        );

        expect(listenerFocus.hasPrimaryFocus, isTrue);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        expect(undoPresses, 1);
      });
    }

    testWidgets('挂载后再启用快捷键不抢走子组件已获得的焦点', (tester) async {
      final fieldFocus = FocusNode(debugLabel: 'child-field');
      addTearDown(fieldFocus.dispose);

      final notifier = await _pumpMountedAfterReady(
        tester,
        config: _defaults.copyWith(enableShortcuts: false),
        build: (_) => ShortcutAwareWidget(
          contextType: ShortcutContext.generation,
          shortcuts: {ShortcutIds.generateImage: () {}},
          autofocus: true,
          child: Material(
            child: TextField(focusNode: fieldFocus, autofocus: true),
          ),
        ),
      );
      expect(fieldFocus.hasPrimaryFocus, isTrue);

      notifier.emit(_ready(_defaults));
      await tester.pump();
      await tester.pump();

      expect(fieldFocus.hasPrimaryFocus, isTrue);
    });

    testWidgets('Tab 遍历不会停在锚点上', (tester) async {
      final fieldA = FocusNode(debugLabel: 'field-a');
      final fieldB = FocusNode(debugLabel: 'field-b');
      addTearDown(fieldA.dispose);
      addTearDown(fieldB.dispose);
      final notifier = _ControlledShortcutConfigNotifier();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shortcutConfigNotifierProvider.overrideWith(() => notifier),
          ],
          child: MaterialApp(
            home: ShortcutAwareWidget(
              contextType: ShortcutContext.generation,
              shortcuts: {ShortcutIds.generateImage: () {}},
              autofocus: true,
              child: Material(
                child: Column(
                  children: [
                    TextField(focusNode: fieldA),
                    TextField(focusNode: fieldB),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(_isAnchor(FocusManager.instance.primaryFocus), isTrue);

      final visited = <String?>[];
      for (var i = 0; i < 5; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        visited.add(FocusManager.instance.primaryFocus?.debugLabel);
      }

      expect(visited, ['field-a', 'field-b', 'field-a', 'field-b', 'field-a']);
    });

    testWidgets('已聚焦的输入框在重建与状态切换中保持焦点', (tester) async {
      final harness = await _pumpHarness(tester);
      harness.probe.textFocus.requestFocus();
      await tester.pump();
      expect(harness.probe.textFocus.hasFocus, isTrue);

      await harness.rebuildParent();
      expect(harness.probe.textFocus.hasFocus, isTrue, reason: '加载态重建');

      await harness.emit(_ready(_defaults));
      expect(harness.probe.textFocus.hasFocus, isTrue, reason: '加载→就绪');

      await harness.emit(
        _ready(
          _defaults.setCustomShortcut(ShortcutIds.generateImage, 'ctrl+g'),
        ),
      );
      expect(harness.probe.textFocus.hasFocus, isTrue, reason: '修改绑定');

      await harness.emit(_ready(_defaults.copyWith(enableShortcuts: false)));
      expect(harness.probe.textFocus.hasFocus, isTrue, reason: '禁用');

      await harness.emit(_ready(_defaults));
      expect(harness.probe.textFocus.hasFocus, isTrue, reason: '重新启用');

      await harness.emit(_failed());
      expect(harness.probe.textFocus.hasFocus, isTrue, reason: '出错');
    });
  });

  group('快捷键功能', () {
    testWidgets('加载态使用默认快捷键触发回调', (tester) async {
      final harness = await _pumpHarness(tester);

      await harness.press(_ctrl, LogicalKeyboardKey.enter);

      expect(harness.count(ShortcutIds.generateImage), 1);
    });

    testWidgets('出错态回退到默认快捷键', (tester) async {
      final harness = await _pumpHarness(tester);
      await harness.emit(_failed());

      await harness.press(_ctrl, LogicalKeyboardKey.enter);

      expect(harness.count(ShortcutIds.generateImage), 1);
    });

    testWidgets('就绪后按用户绑定触发，改绑后新键生效旧键失效', (tester) async {
      final harness = await _pumpHarness(tester);
      await harness.emit(
        _ready(
          _defaults.setCustomShortcut(ShortcutIds.generateImage, 'ctrl+g'),
        ),
      );

      await harness.press(_ctrl, LogicalKeyboardKey.enter);
      expect(harness.count(ShortcutIds.generateImage), 0);
      await harness.press(_ctrl, LogicalKeyboardKey.keyG);
      expect(harness.count(ShortcutIds.generateImage), 1);

      await harness.emit(
        _ready(
          _defaults.setCustomShortcut(ShortcutIds.generateImage, 'ctrl+h'),
        ),
      );

      await harness.press(_ctrl, LogicalKeyboardKey.keyG);
      expect(harness.count(ShortcutIds.generateImage), 1);
      await harness.press(_ctrl, LogicalKeyboardKey.keyH);
      expect(harness.count(ShortcutIds.generateImage), 2);
    });

    testWidgets('重新加载期间沿用上次配置，重新加载出错时回退默认绑定', (tester) async {
      final harness = await _pumpHarness(tester);
      final custom = _ready(
        _defaults.setCustomShortcut(ShortcutIds.generateImage, 'ctrl+g'),
      );
      await harness.emit(custom);

      await harness.emit(
        const AsyncLoading<ShortcutConfig>().copyWithPrevious(custom),
      );
      await harness.press(_ctrl, LogicalKeyboardKey.keyG);
      expect(harness.count(ShortcutIds.generateImage), 1, reason: '刷新中');

      await harness.emit(_failed().copyWithPrevious(custom));
      await harness.press(_ctrl, LogicalKeyboardKey.keyG);
      expect(harness.count(ShortcutIds.generateImage), 1, reason: '出错旧键失效');
      await harness.press(_ctrl, LogicalKeyboardKey.enter);
      expect(harness.count(ShortcutIds.generateImage), 2, reason: '出错用默认键');
    });

    testWidgets('子树内输入框持有焦点时改绑后的快捷键冒泡触发', (tester) async {
      final harness = await _pumpHarness(tester);
      await harness.emit(
        _ready(
          _defaults.setCustomShortcut(ShortcutIds.generateImage, 'ctrl+g'),
        ),
      );
      harness.probe.textFocus.requestFocus();
      await tester.pump();

      await harness.press(_ctrl, LogicalKeyboardKey.keyG);

      expect(harness.count(ShortcutIds.generateImage), 1);
      expect(harness.probe.textFocus.hasPrimaryFocus, isTrue);
    });

    testWidgets('父级重建后回调使用最新传入的映射', (tester) async {
      final harness = await _pumpHarness(tester);
      await harness.emit(_ready(_defaults));
      await harness.rebuildParent();

      await harness.press(_ctrl, LogicalKeyboardKey.enter);

      expect(harness.count(ShortcutIds.generateImage), 1);
    });

    testWidgets('全局禁用或单项禁用后不触发，重新启用后恢复', (tester) async {
      final harness = await _pumpHarness(tester);

      await harness.emit(_ready(_defaults.copyWith(enableShortcuts: false)));
      await harness.press(_ctrl, LogicalKeyboardKey.enter);
      expect(harness.count(ShortcutIds.generateImage), 0);

      await harness.emit(
        _ready(_defaults.setEnabled(ShortcutIds.generateImage, false)),
      );
      await harness.press(_ctrl, LogicalKeyboardKey.enter);
      expect(harness.count(ShortcutIds.generateImage), 0);

      await harness.emit(_ready(_defaults));
      await harness.press(_ctrl, LogicalKeyboardKey.enter);
      expect(harness.count(ShortcutIds.generateImage), 1);
    });

    testWidgets('绑定上下文与页面不匹配时不触发', (tester) async {
      final harness = await _pumpHarness(
        tester,
        contextType: ShortcutContext.gallery,
      );

      await harness.press(_ctrl, LogicalKeyboardKey.enter);
      expect(harness.count(ShortcutIds.generateImage), 0, reason: '加载态');

      await harness.emit(_ready(_defaults));
      await harness.press(_ctrl, LogicalKeyboardKey.enter);
      expect(harness.count(ShortcutIds.generateImage), 0, reason: '就绪态');
    });

    testWidgets('global 绑定在任意页面上下文中触发', (tester) async {
      final harness = await _pumpHarness(
        tester,
        contextType: ShortcutContext.viewer,
        shortcutIds: const [ShortcutIds.navigateToGeneration],
      );

      await harness.press(_ctrl, LogicalKeyboardKey.digit1);
      expect(harness.count(ShortcutIds.navigateToGeneration), 1, reason: '加载态');

      await harness.emit(_ready(_defaults));
      await harness.press(_ctrl, LogicalKeyboardKey.digit1);
      expect(harness.count(ShortcutIds.navigateToGeneration), 2, reason: '就绪态');
    });

    testWidgets('内层没有可用快捷键时外层包装器的快捷键照常触发', (tester) async {
      final fieldFocus = FocusNode(debugLabel: 'inner-field');
      addTearDown(fieldFocus.dispose);
      final notifier = _ControlledShortcutConfigNotifier();
      var outerPresses = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            shortcutConfigNotifierProvider.overrideWith(() => notifier),
          ],
          child: MaterialApp(
            home: ShortcutAwareWidget(
              contextType: ShortcutContext.global,
              shortcuts: {
                ShortcutIds.navigateToGeneration: () => outerPresses++,
              },
              child: ShortcutAwareWidget(
                contextType: ShortcutContext.gallery,
                shortcuts: {ShortcutIds.generateImage: () {}},
                child: Material(child: TextField(focusNode: fieldFocus)),
              ),
            ),
          ),
        ),
      );
      fieldFocus.requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.digit1);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(outerPresses, 1);
    });
  });
}
