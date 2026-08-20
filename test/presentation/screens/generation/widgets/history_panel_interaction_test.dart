import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nai_launcher/core/shortcuts/shortcut_config.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/providers/generation/preview_selection_provider.dart';
import 'package:nai_launcher/presentation/providers/history_click_behavior_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/shortcuts_provider.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/history_panel.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/components/detail_top_bar.dart';
import 'package:nai_launcher/presentation/widgets/common/image_detail/image_detail_viewer.dart';
import 'package:nai_launcher/presentation/widgets/common/selectable_image_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('classic single click opens one image detail', (tester) async {
    final container = _createContainer([_image('classic')]);
    addTearDown(container.dispose);

    await tester.pumpWidget(_historyApp(container));
    await _pumpRoute(tester);
    await tester.tap(find.byKey(const ValueKey('classic')));
    await _pumpRoute(tester);

    final viewer = tester.widget<ImageDetailViewer>(
      find.byType(ImageDetailViewer),
    );
    expect(viewer.images, hasLength(1));
    expect(viewer.initialIndex, 0);
    expect(viewer.showThumbnails, isFalse);
  });

  testWidgets('classic detail browses history with left and right arrows', (
    tester,
  ) async {
    final container = _createContainer([
      _image('first'),
      _image('second'),
      _image('third'),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(_historyApp(container));
    await _pumpRoute(tester);
    final second = find.byKey(const ValueKey('second'));
    await tester.ensureVisible(second);
    await tester.tap(second);
    await _pumpRoute(tester);

    final viewer = tester.widget<ImageDetailViewer>(
      find.byType(ImageDetailViewer),
    );
    expect(viewer.images.map((image) => image.identifier), [
      'first',
      'second',
      'third',
    ]);
    expect(viewer.initialIndex, 1);
    expect(viewer.showThumbnails, isTrue);
    expect(_detailIndex(tester), 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await _pumpDetailNavigation(tester);
    expect(_detailIndex(tester), 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await _pumpDetailNavigation(tester);
    expect(_detailIndex(tester), 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await _pumpDetailNavigation(tester);
    expect(_detailIndex(tester), 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await _pumpDetailNavigation(tester);
    expect(_detailIndex(tester), 2);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await _pumpDetailNavigation(tester);
    expect(_detailIndex(tester), 2);
  });

  testWidgets(
    'linked single click selects and second click opens the merged sequence',
    (tester) async {
      final container = _createContainer([
        _image('first'),
        _image('second'),
      ], behavior: HistoryClickBehavior.selectPreview);
      addTearDown(container.dispose);

      await tester.pumpWidget(_historyApp(container));
      await _pumpRoute(tester);

      await tester.tap(find.byKey(const ValueKey('first')));
      await tester.pump();
      expect(container.read(generationPreviewSelectionProvider), 'first');
      expect(find.byType(ImageDetailViewer), findsNothing);
      expect(
        tester
            .widget<SelectableImageCard>(find.byKey(const ValueKey('first')))
            .isPreviewActive,
        isTrue,
      );
      expect(
        container.read(generationPreviewFocusNodeProvider).hasFocus,
        isTrue,
      );

      await tester.tap(find.byKey(const ValueKey('first')));
      await _pumpRoute(tester);
      _expectLinkedViewer(tester, initialIndex: 0);
    },
  );

  testWidgets('linked long press opens the merged sequence at its image', (
    tester,
  ) async {
    final container = _createContainer([
      _image('first'),
      _image('second'),
    ], behavior: HistoryClickBehavior.selectPreview);
    addTearDown(container.dispose);

    await tester.pumpWidget(_historyApp(container));
    await _pumpRoute(tester);
    final second = find.byKey(const ValueKey('second'));
    await tester.ensureVisible(second);
    await tester.longPress(second);
    await _pumpRoute(tester);

    _expectLinkedViewer(tester, initialIndex: 1);
  });

  testWidgets('linked context detail opens the merged sequence at its image', (
    tester,
  ) async {
    final container = _createContainer([
      _image('first'),
      _image('second'),
    ], behavior: HistoryClickBehavior.selectPreview);
    addTearDown(container.dispose);

    await tester.pumpWidget(_historyApp(container));
    await _pumpRoute(tester);
    final second = find.byKey(const ValueKey('second'));
    await tester.ensureVisible(second);
    await _openContextMenu(tester, second);
    await tester.tap(find.text('查看详情'));
    await _pumpRoute(tester);

    _expectLinkedViewer(tester, initialIndex: 1);
  });

  testWidgets('linked Ctrl rapid clicks toggle bulk selection on every click', (
    tester,
  ) async {
    final container = _createContainer([
      _image('toggle'),
    ], behavior: HistoryClickBehavior.selectPreview);
    addTearDown(container.dispose);

    await tester.pumpWidget(_historyApp(container));
    await tester.pumpAndSettle();
    final finder = find.byKey(const ValueKey('toggle'));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.tap(finder);
    await tester.pump();
    expect(tester.widget<SelectableImageCard>(finder).isSelected, isTrue);

    await tester.tap(finder);
    await tester.pump();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(tester.widget<SelectableImageCard>(finder).isSelected, isFalse);
    expect(container.read(generationPreviewSelectionProvider), isNull);
  });

  testWidgets(
    'classic Ctrl rapid clicks stay bulk-only and context opens one',
    (tester) async {
      final container = _createContainer([_image('classic-toggle')]);
      addTearDown(container.dispose);

      await tester.pumpWidget(_historyApp(container));
      await tester.pumpAndSettle();
      final finder = find.byKey(const ValueKey('classic-toggle'));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.tap(finder);
      await tester.pump();
      expect(tester.widget<SelectableImageCard>(finder).isSelected, isTrue);
      await tester.tap(finder);
      await tester.pump();
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);

      expect(tester.widget<SelectableImageCard>(finder).isSelected, isFalse);
      expect(container.read(generationPreviewSelectionProvider), isNull);
      expect(find.byType(ImageDetailViewer), findsNothing);

      await _openContextMenu(tester, finder);
      await tester.tap(find.text('查看详情'));
      await _pumpRoute(tester);
      final viewer = tester.widget<ImageDetailViewer>(
        find.byType(ImageDetailViewer),
      );
      expect(viewer.images, hasLength(1));
      expect(viewer.showThumbnails, isFalse);
    },
  );

  testWidgets('Windows key does not turn a classic click into bulk selection', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      final container = _createContainer([_image('windows-meta')]);
      addTearDown(container.dispose);

      await tester.pumpWidget(_historyApp(container));
      await tester.pumpAndSettle();
      final finder = find.byKey(const ValueKey('windows-meta'));

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.tap(finder);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await _pumpRoute(tester);

      final viewer = tester.widget<ImageDetailViewer>(
        find.byType(ImageDetailViewer),
      );
      expect(viewer.images, hasLength(1));
      expect(viewer.initialIndex, 0);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('rapid tall-row navigation settles on the latest selection', (
    tester,
  ) async {
    final images = [
      for (var index = 0; index < 8; index++)
        _image(
          'rapid-$index',
          width: 100,
          height: 400,
          kind: GeneratedImageKind.failedStreamSnapshot,
        ),
    ];
    final container = _createContainer(
      images,
      behavior: HistoryClickBehavior.selectPreview,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_historyApp(container));
    await tester.pumpAndSettle();
    final selection = container.read(
      generationPreviewSelectionProvider.notifier,
    );
    selection.select('rapid-0');
    for (var index = 0; index < 7; index++) {
      selection.selectNext();
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pump(const Duration(milliseconds: 220));
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    final latestPosition = scrollable.position.pixels;
    await tester.pump(const Duration(milliseconds: 300));

    expect(container.read(generationPreviewSelectionProvider), 'rapid-7');
    expect(find.byKey(const ValueKey('rapid-7')), findsOneWidget);
    expect(scrollable.position.pixels, greaterThan(0));
    expect(
      scrollable.position.pixels,
      greaterThanOrEqualTo(latestPosition - 10),
    );
  });

  testWidgets('generation placeholder row participates in selected offset', (
    tester,
  ) async {
    final target = _image('after-placeholder');
    final container = _createContainer(
      [target],
      behavior: HistoryClickBehavior.selectPreview,
      currentImages: [_image('completed-current')],
      status: GenerationStatus.generating,
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_historyApp(container));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    container
        .read(generationPreviewSelectionProvider.notifier)
        .select(target.id);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(find.byKey(ValueKey(target.id)), findsOneWidget);
    expect(scrollable.position.pixels, greaterThan(250));
  });

  testWidgets('remount scrolls to selection changed while panel was hidden', (
    tester,
  ) async {
    final images = [
      for (var index = 0; index < 5; index++)
        _image(
          'portrait-$index',
          width: 100,
          height: 400,
          kind: GeneratedImageKind.failedStreamSnapshot,
        ),
    ];
    final container = _createContainer(
      images,
      behavior: HistoryClickBehavior.selectPreview,
    );
    addTearDown(container.dispose);
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);

    await tester.pumpWidget(_historyApp(container, visible: visible));
    await tester.pumpAndSettle();
    visible.value = false;
    await tester.pumpAndSettle();

    final selection = container.read(
      generationPreviewSelectionProvider.notifier,
    );
    selection.select('portrait-0');
    for (var index = 0; index < 4; index++) {
      selection.selectNext();
    }
    expect(container.read(generationPreviewSelectionProvider), 'portrait-4');

    visible.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byKey(const ValueKey('portrait-4')), findsOneWidget);
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.pixels, greaterThan(0));
  });
}

ProviderContainer _createContainer(
  List<GeneratedImage> images, {
  HistoryClickBehavior behavior = HistoryClickBehavior.openDetail,
  List<GeneratedImage> currentImages = const [],
  GenerationStatus status = GenerationStatus.idle,
}) {
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWith(
        (_) => _HistoryBehaviorStorage(behavior),
      ),
      shortcutConfigNotifierProvider.overrideWith(
        _HistoryShortcutConfigNotifier.new,
      ),
    ],
  );
  final notifier = container.read(imageGenerationNotifierProvider.notifier);
  notifier.state = notifier.state.copyWith(
    status: status,
    currentImages: currentImages,
    history: images,
    batchWidth: 100,
    batchHeight: 100,
  );
  return container;
}

class _HistoryBehaviorStorage extends LocalStorageService {
  _HistoryBehaviorStorage(this.behavior);

  HistoryClickBehavior behavior;

  @override
  String getHistoryClickBehavior() => behavior.storageValue;

  @override
  Future<void> setHistoryClickBehavior(String value) async {
    behavior = HistoryClickBehavior.fromStorageValue(value);
  }
}

class _HistoryShortcutConfigNotifier extends ShortcutConfigNotifier {
  @override
  Future<ShortcutConfig> build() async => ShortcutConfig.createDefault();
}

GeneratedImage _image(
  String id, {
  int width = 32,
  int height = 32,
  GeneratedImageKind kind = GeneratedImageKind.completed,
}) {
  return GeneratedImage(
    id: id,
    bytes: Uint8List.fromList(
      img.encodePng(img.Image(width: 4, height: 4, numChannels: 4)),
    ),
    width: width,
    height: height,
    kind: kind,
  );
}

Widget _historyApp(
  ProviderContainer container, {
  ValueNotifier<bool>? visible,
}) {
  final previewFocusNode = container.read(generationPreviewFocusNodeProvider);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: const Locale('zh'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: Focus(
          focusNode: previewFocusNode,
          child: SizedBox(
            width: 320,
            height: 640,
            child: visible == null
                ? const HistoryPanel()
                : ValueListenableBuilder(
                    valueListenable: visible,
                    builder: (_, isVisible, __) => isVisible
                        ? const HistoryPanel()
                        : const SizedBox.shrink(),
                  ),
          ),
        ),
      ),
    ),
  );
}

void _expectLinkedViewer(WidgetTester tester, {required int initialIndex}) {
  final viewer = tester.widget<ImageDetailViewer>(
    find.byType(ImageDetailViewer),
  );
  expect(viewer.images, hasLength(2));
  expect(viewer.initialIndex, initialIndex);
  expect(viewer.showThumbnails, isTrue);
}

int _detailIndex(WidgetTester tester) {
  return tester.widget<DetailTopBar>(find.byType(DetailTopBar)).currentIndex;
}

Future<void> _pumpDetailNavigation(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
}

Future<void> _openContextMenu(WidgetTester tester, Finder target) async {
  final gesture = await tester.startGesture(
    tester.getCenter(target),
    kind: PointerDeviceKind.mouse,
    buttons: kSecondaryMouseButton,
  );
  await tester.pump();
  await gesture.up();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

Future<void> _pumpRoute(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}
