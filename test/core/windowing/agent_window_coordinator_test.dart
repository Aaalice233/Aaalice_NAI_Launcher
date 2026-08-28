import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/windowing/agent_window_coordinator.dart';
import 'package:nai_launcher/core/windowing/agent_window_protocol.dart';

void main() {
  late _FakeBackend backend;
  late _FakePreferences preferences;
  late AgentWindowCoordinator coordinator;
  late Future<AgentWindowBounds> Function(AgentWindowBounds bounds)
  correctBounds;

  setUp(() {
    backend = _FakeBackend();
    preferences = _FakePreferences();
    correctBounds = (bounds) async => bounds;
    coordinator = AgentWindowCoordinator(
      backend: backend,
      preferences: preferences,
      correctBounds: (bounds) => correctBounds(bounds),
    );
  });

  tearDown(() => coordinator.dispose());

  test('coalesces concurrent opens into one window creation', () async {
    final first = coordinator.open();
    final second = coordinator.open();

    expect(identical(first, second), isTrue);
    backend.creation.complete(_FakeHandle('agent-window'));
    await Future.wait([first, second]);

    expect(backend.createCalls, 1);
    expect(backend.handle.showCalls, 1);
    expect(backend.handle.focusCalls, 1);
    expect(coordinator.state, AgentWindowLifecycle.open);
  });

  test('docked singleton is restored instead of recreated', () async {
    backend.creation.complete(_FakeHandle('agent-window'));
    await coordinator.open();
    await coordinator.dock();
    await coordinator.open();

    expect(backend.createCalls, 1);
    expect(backend.handle.showCalls, 2);
    expect(backend.handle.focusCalls, 2);
    expect(coordinator.state, AgentWindowLifecycle.open);
  });

  test(
    'dock invalidates an in-flight open and remains authoritative',
    () async {
      final opening = coordinator.open();
      await Future<void>.delayed(Duration.zero);
      expect(backend.createCalls, 1);
      final docking = coordinator.dock();
      backend.creation.complete(_FakeHandle('agent-window'));

      await Future.wait([opening, docking]);

      expect(preferences.detached, isFalse);
      expect(backend.handle.hideCalls, 0);
      expect(backend.handle.abortCalls, 1);
      expect(coordinator.state, AgentWindowLifecycle.docked);
    },
  );

  test('dock retires an existing window found after cancellation', () async {
    final existingLookup = Completer<AgentWindowHandle?>();
    backend.existingLookup = existingLookup.future;
    final existing = _FakeHandle('existing-window');
    final opening = coordinator.open();
    await Future<void>.delayed(Duration.zero);

    final docking = coordinator.dock();
    existingLookup.complete(existing);
    await Future.wait([opening, docking]);

    expect(existing.showCalls, 0);
    expect(existing.abortCalls, 1);
    expect(coordinator.state, AgentWindowLifecycle.docked);
  });

  test('reopen does not reuse a handle aborted during show', () async {
    final openingHandle = _FakeHandle('opening-window')
      ..showBlocker = Completer<void>();
    backend.creation.complete(openingHandle);
    final opening = coordinator.open();
    while (openingHandle.showCalls == 0) {
      await Future<void>.delayed(Duration.zero);
    }

    await coordinator.dock();
    openingHandle.showBlocker!.complete();
    await opening;
    final replacement = _FakeHandle('replacement-window');
    backend.existing = replacement;
    await coordinator.open();

    expect(openingHandle.abortCalls, 1);
    expect(replacement.showCalls, 1);
    expect(coordinator.activeWindowId, replacement.id);
    expect(coordinator.state, AgentWindowLifecycle.open);
  });

  test('open requested during dock runs after the hide completes', () async {
    final handle = _FakeHandle('agent-window')..hideBlocker = Completer<void>();
    backend.creation.complete(handle);
    await coordinator.open();

    final docking = coordinator.dock();
    await Future<void>.delayed(Duration.zero);
    final reopening = coordinator.open();
    expect(coordinator.state, AgentWindowLifecycle.opening);

    handle.hideBlocker!.complete();
    await Future.wait([docking, reopening]);

    expect(handle.hideCalls, 1);
    expect(handle.showCalls, 2);
    expect(coordinator.state, AgentWindowLifecycle.open);
    expect(preferences.detached, isTrue);
  });

  test('a repeated dock cancels a reopen queued behind dock', () async {
    final handle = _FakeHandle('agent-window')..hideBlocker = Completer<void>();
    backend.creation.complete(handle);
    await coordinator.open();

    final docking = coordinator.dock();
    await Future<void>.delayed(Duration.zero);
    final reopening = coordinator.open();
    final repeatedDock = coordinator.dock();
    handle.hideBlocker!.complete();
    await Future.wait([docking, reopening, repeatedDock]);

    expect(handle.hideCalls, 1);
    expect(handle.showCalls, 1);
    expect(coordinator.state, AgentWindowLifecycle.docked);
    expect(preferences.detached, isFalse);
  });

  test(
    'main exit cancels a create that has not returned a handle yet',
    () async {
      final opening = coordinator.open();
      await Future<void>.delayed(Duration.zero);

      final closing = coordinator.closeForMainExit();
      var closeCompleted = false;
      unawaited(closing.then((_) => closeCompleted = true));
      await Future<void>.delayed(Duration.zero);
      expect(closeCompleted, isFalse);
      backend.creation.complete(_FakeHandle('agent-window'));
      await Future.wait([opening, closing]);

      expect(backend.handle.showCalls, 0);
      expect(backend.handle.abortCalls, 1);
      expect(coordinator.state, AgentWindowLifecycle.docked);
    },
  );

  test('main exit retires an existing window found during lookup', () async {
    final existingLookup = Completer<AgentWindowHandle?>();
    backend.existingLookup = existingLookup.future;
    final existing = _FakeHandle('existing-window');
    final opening = coordinator.open();
    await Future<void>.delayed(Duration.zero);

    final closing = coordinator.closeForMainExit();
    existingLookup.complete(existing);
    await Future.wait([opening, closing]);

    expect(existing.showCalls, 0);
    expect(existing.abortCalls, 1);
    expect(coordinator.state, AgentWindowLifecycle.docked);
  });

  test('creation failure is explicit and enters error state', () async {
    final opening = coordinator.open();
    final expectation = expectLater(
      opening,
      throwsA(isA<AgentWindowOpenException>()),
    );
    await Future<void>.delayed(Duration.zero);
    backend.creation.completeError(StateError('native create failed'));

    await expectation;

    expect(coordinator.state, AgentWindowLifecycle.error);
  });

  test(
    'reconciles corrected bounds in storage and the active window',
    () async {
      const corrected = AgentWindowBounds(x: 0, y: 0, width: 360, height: 480);
      correctBounds = (_) async => corrected;
      backend.creation.complete(_FakeHandle('agent-window'));
      await coordinator.open();

      await coordinator.reconcileBounds(
        const AgentWindowBounds(x: 5000, y: 5000, width: 560, height: 760),
      );

      expect(preferences.bounds?.toJson(), corrected.toJson());
      expect(backend.handle.bounds?.toJson(), corrected.toJson());
    },
  );

  test('does not apply stale display bounds to a replacement window', () async {
    final correction = Completer<AgentWindowBounds>();
    final original = _FakeHandle('agent-window');
    backend.creation.complete(original);
    await coordinator.open();

    var correctionCalls = 0;
    correctBounds = (bounds) {
      correctionCalls++;
      return correctionCalls == 1
          ? correction.future
          : Future<AgentWindowBounds>.value(bounds);
    };

    final reconciliation = coordinator.reconcileBounds(
      const AgentWindowBounds(x: 5000, y: 5000, width: 560, height: 760),
    );
    coordinator.markClosed(original.id);
    final replacement = _FakeHandle('replacement-window');
    backend.existing = replacement;
    await coordinator.open();
    const replacementBounds = AgentWindowBounds(
      x: 30,
      y: 40,
      width: 600,
      height: 700,
    );
    await coordinator.persistBounds(replacementBounds);
    correction.complete(
      const AgentWindowBounds(x: 0, y: 0, width: 360, height: 480),
    );
    await reconciliation;

    expect(original.bounds, isNull);
    expect(replacement.bounds, isNull);
    expect(preferences.bounds, replacementBounds);
  });

  test('does not reconcile a saved bound read for a replaced window', () async {
    final original = _FakeHandle('agent-window');
    backend.creation.complete(original);
    await coordinator.open();

    final savedRead = Completer<AgentWindowBounds?>();
    preferences.readBoundsOverride = () => savedRead.future;
    final reconciliation = coordinator.reconcileSavedBounds();
    preferences.readBoundsOverride = null;
    coordinator.markClosed(original.id);
    final replacement = _FakeHandle('replacement-window');
    backend.existing = replacement;
    await coordinator.open();
    const replacementBounds = AgentWindowBounds(
      x: 30,
      y: 40,
      width: 600,
      height: 700,
    );
    await coordinator.persistBounds(replacementBounds);
    savedRead.complete(
      const AgentWindowBounds(x: 5000, y: 5000, width: 560, height: 760),
    );
    await reconciliation;

    expect(replacement.bounds, isNull);
    expect(preferences.bounds, replacementBounds);
  });

  test(
    'new bounds win when an older preference write is in progress',
    () async {
      final handle = _FakeHandle('agent-window');
      backend.creation.complete(handle);
      await coordinator.open();
      const corrected = AgentWindowBounds(x: 0, y: 0, width: 360, height: 480);
      correctBounds = (_) async => corrected;
      final firstWriteStarted = Completer<void>();
      final releaseFirstWrite = Completer<void>();
      var writeCalls = 0;
      preferences.writeBoundsOverride = (bounds) async {
        writeCalls++;
        if (writeCalls == 1) {
          firstWriteStarted.complete();
          await releaseFirstWrite.future;
        }
        preferences.bounds = bounds;
      };

      final oldReconciliation = coordinator.reconcileBounds(
        const AgentWindowBounds(x: 5000, y: 5000, width: 560, height: 760),
      );
      await firstWriteStarted.future;
      const newest = AgentWindowBounds(x: 30, y: 40, width: 600, height: 700);
      final newestPersistence = coordinator.persistBounds(newest);
      releaseFirstWrite.complete();
      await Future.wait([oldReconciliation, newestPersistence]);

      expect(preferences.bounds, newest);
      expect(handle.bounds, isNull);
    },
  );

  test('main exit closes the secondary window once', () async {
    final handle = _FakeHandle('agent-window')
      ..closeBlocker = Completer<void>();
    backend.creation.complete(handle);
    await coordinator.open();

    final firstClose = coordinator.closeForMainExit();
    final secondClose = coordinator.closeForMainExit();
    expect(identical(firstClose, secondClose), isTrue);
    handle.closeBlocker!.complete();
    await Future.wait([firstClose, secondClose]);

    expect(backend.handle.closeCalls, 1);
    expect(coordinator.state, AgentWindowLifecycle.docked);
  });

  test('main exit does not wait for a ready handshake in progress', () async {
    final handle = _FakeHandle('agent-window')..showBlocker = Completer<void>();
    backend.creation.complete(handle);
    final opening = coordinator.open();
    await Future<void>.delayed(Duration.zero);
    expect(handle.showCalls, 1);

    await coordinator.closeForMainExit();

    expect(handle.abortCalls, 1);
    expect(handle.closeCalls, 0);
    expect(coordinator.state, AgentWindowLifecycle.docked);
    handle.showBlocker!.complete();
    await opening;
  });
}

class _FakeBackend implements AgentWindowBackend {
  final creation = Completer<_FakeHandle>();
  int createCalls = 0;
  _FakeHandle? existing;
  Future<AgentWindowHandle?>? existingLookup;
  late _FakeHandle handle;

  @override
  Future<AgentWindowHandle> create(AgentWindowLaunchArguments arguments) async {
    createCalls++;
    handle = await creation.future;
    return handle;
  }

  @override
  Future<AgentWindowHandle?> findExisting() async =>
      existingLookup == null ? existing : existingLookup!;
}

class _FakeHandle implements AgentWindowHandle {
  _FakeHandle(this.id);

  @override
  final String id;
  int showCalls = 0;
  int focusCalls = 0;
  int hideCalls = 0;
  int closeCalls = 0;
  int abortCalls = 0;
  bool alwaysOnTop = false;
  AgentWindowBounds? bounds;
  Completer<void>? showBlocker;
  Completer<void>? hideBlocker;
  Completer<void>? closeBlocker;

  @override
  Future<void> show() async {
    showCalls++;
    await showBlocker?.future;
  }

  @override
  Future<void> focusAndRestore() async => focusCalls++;

  @override
  Future<void> hide() async {
    hideCalls++;
    await hideBlocker?.future;
  }

  @override
  Future<void> close() async {
    closeCalls++;
    await closeBlocker?.future;
  }

  @override
  Future<void> abortOpen() async => abortCalls++;

  @override
  Future<void> setAlwaysOnTop(bool value) async => alwaysOnTop = value;

  @override
  Future<void> setBounds(AgentWindowBounds bounds) async {
    this.bounds = bounds;
  }
}

class _FakePreferences implements AgentWindowPreferences {
  AgentWindowBounds? bounds;
  bool alwaysOnTop = false;
  bool detached = false;
  Future<AgentWindowBounds?> Function()? readBoundsOverride;
  Future<void> Function(AgentWindowBounds bounds)? writeBoundsOverride;

  @override
  Future<AgentWindowBounds?> readBounds() async =>
      readBoundsOverride == null ? bounds : readBoundsOverride!();

  @override
  Future<bool> readAlwaysOnTop() async => alwaysOnTop;

  @override
  Future<bool> readDetached() async => detached;

  @override
  Future<void> writeBounds(AgentWindowBounds bounds) async {
    final override = writeBoundsOverride;
    if (override != null) {
      await override(bounds);
      return;
    }
    this.bounds = bounds;
  }

  @override
  Future<void> writeAlwaysOnTop(bool value) async => alwaysOnTop = value;

  @override
  Future<void> writeDetached(bool value) async => detached = value;
}
