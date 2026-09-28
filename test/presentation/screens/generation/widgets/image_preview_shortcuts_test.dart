import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/shortcuts/default_shortcuts.dart';
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/presentation/providers/generation/preview_selection_provider.dart';
import 'package:nai_launcher/presentation/providers/history_click_behavior_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/image_preview.dart';

class _PreviewImageGenerationNotifier extends ImageGenerationNotifier {
  @override
  ImageGenerationState build() =>
      ImageGenerationState(currentImages: [_image('a'), _image('b')]);
}

class _PreviewHistoryBehaviorNotifier extends HistoryClickBehaviorNotifier {
  _PreviewHistoryBehaviorNotifier(this.behavior);

  final HistoryClickBehavior behavior;

  @override
  HistoryClickBehavior build() => behavior;

  @override
  Future<void> setBehavior(HistoryClickBehavior behavior) async {
    state = behavior;
  }
}

class _PreviewShortcutConfigNotifier extends ShortcutConfigNotifier {
  _PreviewShortcutConfigNotifier(this.loader);

  final Future<ShortcutConfig> Function() loader;

  @override
  Future<ShortcutConfig> build() => loader();
}

void main() {
  testWidgets('linked arrows stay inner while Escape and Ctrl+Enter bubble', (
    tester,
  ) async {
    var outerLeft = 0;
    var escaped = 0;
    var generated = 0;
    final container = _container(HistoryClickBehavior.selectPreview);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _app(
        container,
        CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
              outerLeft++;
            },
            const SingleActivator(LogicalKeyboardKey.escape): () {
              escaped++;
            },
            const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
              generated++;
            },
          },
          child: const PreviewNavShortcuts(child: SizedBox.expand()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    container.read(generationPreviewFocusNodeProvider).requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(container.read(generationPreviewSelectionProvider), 'a');
    expect(outerLeft, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(escaped, 1);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pump();
    expect(generated, 1);
  });

  testWidgets('classic mode registers no arrow binding', (tester) async {
    var outerRight = 0;
    final container = _container(HistoryClickBehavior.openDetail);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _app(
        container,
        CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowRight): () {
              outerRight++;
            },
          },
          child: const PreviewNavShortcuts(child: SizedBox.expand()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    container.read(generationPreviewFocusNodeProvider).requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(outerRight, 1);
    expect(container.read(generationPreviewSelectionProvider), isNull);
  });

  testWidgets('loading shortcut config falls back to default arrows', (
    tester,
  ) async {
    final pending = Completer<ShortcutConfig>();
    final container = _container(
      HistoryClickBehavior.selectPreview,
      loader: () => pending.future,
    );
    addTearDown(() {
      if (!pending.isCompleted) {
        pending.complete(ShortcutConfig.createDefault());
      }
      container.dispose();
    });

    await tester.pumpWidget(
      _app(container, const PreviewNavShortcuts(child: SizedBox.expand())),
    );
    await tester.pump();
    container.read(generationPreviewFocusNodeProvider).requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(container.read(generationPreviewSelectionProvider), 'a');
  });

  testWidgets('error shortcut config falls back to default arrows', (
    tester,
  ) async {
    final container = _container(
      HistoryClickBehavior.selectPreview,
      loader: () async => throw StateError('broken shortcut storage'),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _app(container, const PreviewNavShortcuts(child: SizedBox.expand())),
    );
    await tester.pumpAndSettle();
    container.read(generationPreviewFocusNodeProvider).requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(container.read(generationPreviewSelectionProvider), 'a');
  });

  testWidgets('custom binding replaces its default and rebuilds immediately', (
    tester,
  ) async {
    var outerLeft = 0;
    final container = _container(HistoryClickBehavior.selectPreview);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _app(
        container,
        CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
              outerLeft++;
            },
          },
          child: const PreviewNavShortcuts(child: SizedBox.expand()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    container.read(generationPreviewFocusNodeProvider).requestFocus();
    await tester.pump();

    await container
        .read(shortcutConfigNotifierProvider.notifier)
        .setCustomShortcut(ShortcutIds.generationPrevImage, 'pageup');
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.pageUp);
    await tester.pump();

    expect(outerLeft, 1);
    expect(container.read(generationPreviewSelectionProvider), 'a');
  });

  testWidgets(
    'disabled binding bubbles while the enabled sibling still works',
    (tester) async {
      var outerLeft = 0;
      final config = ShortcutConfig.createDefault().setEnabled(
        ShortcutIds.generationPrevImage,
        false,
      );
      final container = _container(
        HistoryClickBehavior.selectPreview,
        loader: () async => config,
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _app(
          container,
          CallbackShortcuts(
            bindings: {
              const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
                outerLeft++;
              },
            },
            child: const PreviewNavShortcuts(child: SizedBox.expand()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      container.read(generationPreviewFocusNodeProvider).requestFocus();
      await tester.pump();

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      expect(outerLeft, 1);
      expect(container.read(generationPreviewSelectionProvider), 'a');
    },
  );

  testWidgets('global disable leaves both arrows to the outer scope', (
    tester,
  ) async {
    var outerArrows = 0;
    final config = ShortcutConfig.createDefault().copyWith(
      enableShortcuts: false,
    );
    final container = _container(
      HistoryClickBehavior.selectPreview,
      loader: () async => config,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _app(
        container,
        CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
              outerArrows++;
            },
            const SingleActivator(LogicalKeyboardKey.arrowRight): () {
              outerArrows++;
            },
          },
          child: const PreviewNavShortcuts(child: SizedBox.expand()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    container.read(generationPreviewFocusNodeProvider).requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(outerArrows, 2);
    expect(container.read(generationPreviewSelectionProvider), isNull);
  });

  testWidgets('colliding actions deterministically keep the previous action', (
    tester,
  ) async {
    final defaults = ShortcutConfig.createDefault();
    final config = defaults.copyWith(
      bindings: {
        ...defaults.bindings,
        ShortcutIds.generationPrevImage: defaults
            .bindings[ShortcutIds.generationPrevImage]!
            .copyWith(customShortcut: 'f8'),
        ShortcutIds.generationNextImage: defaults
            .bindings[ShortcutIds.generationNextImage]!
            .copyWith(customShortcut: 'f8'),
      },
    );
    final container = _container(
      HistoryClickBehavior.selectPreview,
      loader: () async => config,
    );
    addTearDown(container.dispose);
    container.read(generationPreviewSelectionProvider.notifier).select('b');

    await tester.pumpWidget(
      _app(container, const PreviewNavShortcuts(child: SizedBox.expand())),
    );
    await tester.pumpAndSettle();
    container.read(generationPreviewFocusNodeProvider).requestFocus();
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.f8);
    await tester.pump();

    expect(container.read(generationPreviewSelectionProvider), 'a');
  });

  testWidgets('switching classic to linked mode rebuilds arrow registration', (
    tester,
  ) async {
    var outerRight = 0;
    final container = _container(HistoryClickBehavior.openDetail);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _app(
        container,
        CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.arrowRight): () {
              outerRight++;
            },
          },
          child: const PreviewNavShortcuts(child: SizedBox.expand()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    container.read(generationPreviewFocusNodeProvider).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(outerRight, 1);

    await container
        .read(historyClickBehaviorNotifierProvider.notifier)
        .setBehavior(HistoryClickBehavior.selectPreview);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    expect(outerRight, 1);
    expect(container.read(generationPreviewSelectionProvider), 'a');
  });

  testWidgets('a sibling TextField retains arrow-key caret movement', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'ab');
    addTearDown(controller.dispose);
    final container = _container(HistoryClickBehavior.selectPreview);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _app(
        container,
        Column(
          children: [
            const Expanded(
              child: PreviewNavShortcuts(child: SizedBox.expand()),
            ),
            TextField(controller: controller),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.pump();
    controller.selection = const TextSelection.collapsed(offset: 2);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();

    expect(controller.selection.baseOffset, 1);
    expect(container.read(generationPreviewSelectionProvider), isNull);
  });
}

ProviderContainer _container(
  HistoryClickBehavior behavior, {
  Future<ShortcutConfig> Function()? loader,
}) {
  return ProviderContainer(
    overrides: [
      imageGenerationNotifierProvider.overrideWith(
        _PreviewImageGenerationNotifier.new,
      ),
      historyClickBehaviorNotifierProvider.overrideWith(
        () => _PreviewHistoryBehaviorNotifier(behavior),
      ),
      shortcutConfigNotifierProvider.overrideWith(
        () => _PreviewShortcutConfigNotifier(
          loader ?? () async => ShortcutConfig.createDefault(),
        ),
      ),
    ],
  );
}

Widget _app(ProviderContainer container, Widget child) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

GeneratedImage _image(String id) {
  return GeneratedImage(
    id: id,
    bytes: Uint8List.fromList([1, 2, 3]),
    width: 1,
    height: 1,
  );
}
