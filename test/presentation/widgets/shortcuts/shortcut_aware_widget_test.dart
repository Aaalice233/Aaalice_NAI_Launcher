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
  final Map<String, VoidCallback> Function(int generation) buildShortcuts;
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
      shortcuts: widget.buildShortcuts(_generation),
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
  int? lastInvokedGeneration;
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

  Future<void> press(LogicalKeyboardKey key) => _pressCtrl(tester, key);

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
          buildShortcuts: (generation) => {
            for (final id in shortcutIds)
              id: () {
                harness.invocations[id] = harness.count(id) + 1;
                harness.lastInvokedGeneration = generation;
              },
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
  required Widget child,
}) async {
  final notifier = _ControlledShortcutConfigNotifier();
  final gateKey = GlobalKey<_DeferredMountState>();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [shortcutConfigNotifierProvider.overrideWith(() => notifier)],
      child: MaterialApp(
        home: _DeferredMount(key: gateKey, child: child),
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

Widget _app(_ControlledShortcutConfigNotifier notifier, Widget home) {
  return ProviderScope(
    overrides: [shortcutConfigNotifierProvider.overrideWith(() => notifier)],
    child: MaterialApp(home: home),
  );
}

Future<void> _pressCtrl(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

bool _isAnchor(FocusNode? node) =>
    node?.debugLabel?.startsWith('ShortcutAwareWidget') ?? false;

ShortcutConfig get _defaults => ShortcutConfig.createDefault();

AsyncValue<ShortcutConfig> _ready(ShortcutConfig config) =>
    AsyncValue.data(config);

AsyncValue<ShortcutConfig> _failed() =>
    AsyncValue.error(StateError('storage unavailable'), StackTrace.empty);

void main() {
  testWidgets('配置各状态切换与父级重建都保留 child State 和输入框焦点', (tester) async {
    final harness = await _pumpHarness(tester);
    final original = harness.probe;
    harness.probe.textFocus.requestFocus();
    await tester.pump();

    final steps = <String, Future<void> Function()>{
      '加载态重建': harness.rebuildParent,
      '加载→就绪': () => harness.emit(_ready(_defaults)),
      '就绪态重建': harness.rebuildParent,
      '修改绑定': () => harness.emit(
        _ready(
          _defaults.setCustomShortcut(ShortcutIds.generateImage, 'ctrl+g'),
        ),
      ),
      '全局禁用': () =>
          harness.emit(_ready(_defaults.copyWith(enableShortcuts: false))),
      '重新启用': () => harness.emit(_ready(_defaults)),
      '无可用快捷键': () => harness.emit(
        _ready(_defaults.setEnabled(ShortcutIds.generateImage, false)),
      ),
      '恢复可用': () => harness.emit(_ready(_defaults)),
      '出错': () => harness.emit(_failed()),
      '出错态重建': harness.rebuildParent,
    };
    for (final MapEntry(key: step, value: run) in steps.entries) {
      await run();
      expect(harness.probeInits, 1, reason: step);
      expect(identical(harness.probe, original), isTrue, reason: step);
      expect(harness.probe.textFocus.hasFocus, isTrue, reason: step);
    }
  });

  group('焦点', () {
    testWidgets('首次挂载时 autofocus 把焦点落在快捷键作用域内', (tester) async {
      await _pumpHarness(tester);

      final primary = FocusManager.instance.primaryFocus;
      expect(
        primary?.context?.findAncestorWidgetOfExactType<ShortcutAwareWidget>(),
        isNotNull,
      );
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
          child: ShortcutAwareWidget(
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
        await _pressCtrl(tester, LogicalKeyboardKey.keyZ);
        expect(undoPresses, 1);
      });
    }

    testWidgets('挂载后再启用快捷键不抢走子组件已获得的焦点', (tester) async {
      final fieldFocus = FocusNode(debugLabel: 'child-field');
      addTearDown(fieldFocus.dispose);

      final notifier = await _pumpMountedAfterReady(
        tester,
        config: _defaults.copyWith(enableShortcuts: false),
        child: ShortcutAwareWidget(
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
      await tester.pumpWidget(
        _app(
          _ControlledShortcutConfigNotifier(),
          ShortcutAwareWidget(
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
  });

  group('快捷键功能', () {
    testWidgets('加载态与出错态使用默认快捷键', (tester) async {
      final harness = await _pumpHarness(tester);

      await harness.press(LogicalKeyboardKey.enter);
      expect(harness.count(ShortcutIds.generateImage), 1, reason: '加载态');

      await harness.emit(_failed());
      await harness.press(LogicalKeyboardKey.enter);
      expect(harness.count(ShortcutIds.generateImage), 2, reason: '出错态');
    });

    testWidgets('就绪后按用户绑定触发，改绑后新键生效旧键失效', (tester) async {
      final harness = await _pumpHarness(tester);
      await harness.emit(
        _ready(
          _defaults.setCustomShortcut(ShortcutIds.generateImage, 'ctrl+g'),
        ),
      );

      await harness.press(LogicalKeyboardKey.enter);
      expect(harness.count(ShortcutIds.generateImage), 0);
      await harness.press(LogicalKeyboardKey.keyG);
      expect(harness.count(ShortcutIds.generateImage), 1);

      await harness.emit(
        _ready(
          _defaults.setCustomShortcut(ShortcutIds.generateImage, 'ctrl+h'),
        ),
      );

      await harness.press(LogicalKeyboardKey.keyG);
      expect(harness.count(ShortcutIds.generateImage), 1);
      await harness.press(LogicalKeyboardKey.keyH);
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
      await harness.press(LogicalKeyboardKey.keyG);
      expect(harness.count(ShortcutIds.generateImage), 1, reason: '刷新中');

      await harness.emit(_failed().copyWithPrevious(custom));
      await harness.press(LogicalKeyboardKey.keyG);
      expect(harness.count(ShortcutIds.generateImage), 1, reason: '出错旧键失效');
      await harness.press(LogicalKeyboardKey.enter);
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

      await harness.press(LogicalKeyboardKey.keyG);

      expect(harness.count(ShortcutIds.generateImage), 1);
      expect(harness.probe.textFocus.hasPrimaryFocus, isTrue);
    });

    testWidgets('父级重建后调用最新传入的回调', (tester) async {
      final harness = await _pumpHarness(tester);
      await harness.emit(_ready(_defaults));
      await harness.rebuildParent();

      await harness.press(LogicalKeyboardKey.enter);

      expect(harness.lastInvokedGeneration, 1);
    });

    testWidgets('全局禁用或单项禁用后不触发，重新启用后恢复', (tester) async {
      final harness = await _pumpHarness(tester);

      await harness.emit(_ready(_defaults.copyWith(enableShortcuts: false)));
      await harness.press(LogicalKeyboardKey.enter);
      expect(harness.count(ShortcutIds.generateImage), 0);

      await harness.emit(
        _ready(_defaults.setEnabled(ShortcutIds.generateImage, false)),
      );
      await harness.press(LogicalKeyboardKey.enter);
      expect(harness.count(ShortcutIds.generateImage), 0);

      await harness.emit(_ready(_defaults));
      await harness.press(LogicalKeyboardKey.enter);
      expect(harness.count(ShortcutIds.generateImage), 1);
    });

    testWidgets('绑定上下文与页面不匹配时不触发', (tester) async {
      final harness = await _pumpHarness(
        tester,
        contextType: ShortcutContext.gallery,
      );

      await harness.press(LogicalKeyboardKey.enter);
      expect(harness.count(ShortcutIds.generateImage), 0, reason: '加载态');

      await harness.emit(_ready(_defaults));
      await harness.press(LogicalKeyboardKey.enter);
      expect(harness.count(ShortcutIds.generateImage), 0, reason: '就绪态');
    });

    testWidgets('global 绑定在任意页面上下文中触发', (tester) async {
      final harness = await _pumpHarness(
        tester,
        contextType: ShortcutContext.viewer,
        shortcutIds: const [ShortcutIds.navigateToGeneration],
      );

      await harness.press(LogicalKeyboardKey.digit1);
      expect(harness.count(ShortcutIds.navigateToGeneration), 1, reason: '加载态');

      await harness.emit(_ready(_defaults));
      await harness.press(LogicalKeyboardKey.digit1);
      expect(harness.count(ShortcutIds.navigateToGeneration), 2, reason: '就绪态');
    });

    testWidgets('内层没有可用快捷键时外层包装器的快捷键照常触发', (tester) async {
      final fieldFocus = FocusNode(debugLabel: 'inner-field');
      addTearDown(fieldFocus.dispose);
      var outerPresses = 0;
      await tester.pumpWidget(
        _app(
          _ControlledShortcutConfigNotifier(),
          ShortcutAwareWidget(
            contextType: ShortcutContext.global,
            shortcuts: {ShortcutIds.navigateToGeneration: () => outerPresses++},
            child: ShortcutAwareWidget(
              contextType: ShortcutContext.gallery,
              shortcuts: {ShortcutIds.generateImage: () {}},
              child: Material(child: TextField(focusNode: fieldFocus)),
            ),
          ),
        ),
      );
      fieldFocus.requestFocus();
      await tester.pump();

      await _pressCtrl(tester, LogicalKeyboardKey.digit1);

      expect(outerPresses, 1);
    });
  });
}
