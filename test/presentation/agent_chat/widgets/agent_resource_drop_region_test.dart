import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_chat_drop_reader.dart';
import 'package:nai_launcher/presentation/providers/online_gallery_provider.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_resource_drop_region.dart';
import 'package:nai_launcher/presentation/utils/dropped_file_reader.dart';
import 'package:nai_launcher/presentation/widgets/common/image_card_actions.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

import '../../../helpers/card_drop_test_utils.dart';

void main() {
  testWidgets('drag sources keep a stable registered widget tree', (
    tester,
  ) async {
    await tester.pumpWidget(_manySourcesApp());

    expect(find.byType(AgentResourceDragSource), findsAtLeastNWidgets(8));
    expect(find.byType(DragItemWidget), findsAtLeastNWidgets(8));
    expect(find.byType(DraggableWidget), findsAtLeastNWidgets(8));
  });

  testWidgets('drag source local data is platform-channel serializable', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    await tester.pumpWidget(_app());
    final dragWidget = tester.widget<DragItemWidget>(
      find.byType(DragItemWidget),
    );
    final session = _FakeDragSession();
    addTearDown(session.dispose);

    final item = await dragWidget.dragItemProvider(
      DragItemRequest(location: Offset.zero, session: session),
    );

    expect(item, isNotNull);
    expect(item!.localData, isA<Map>());
    expect(
      () => const StandardMessageCodec().encodeMessage(item.localData),
      returnsNormally,
    );
    final decoded = decodeLocalAgentResource(item.localData)!;
    expect(decoded.kind, AgentChatResourceKind.onlineGalleryMedia);
    expect(decoded.source, 'danbooru');
    expect(decoded.resourceId, '1');
    expect(decoded.mediaId, 'cover-1');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('drag source exposes the card Agent action scope', (
    tester,
  ) async {
    ImageCardActionScope? scope;
    await tester.pumpWidget(
      _app(
        child: Builder(
          builder: (context) {
            scope = ImageCardActionScope.maybeOf(context);
            return const ColoredBox(color: Colors.blue);
          },
        ),
      ),
    );

    expect(scope, isNotNull);
  });

  testWidgets('drag source can hide the card Agent action in selection mode', (
    tester,
  ) async {
    ImageCardActionScope? scope;
    await tester.pumpWidget(
      _app(
        enableAddToAgentAction: false,
        child: Builder(
          builder: (context) {
            scope = ImageCardActionScope.maybeOf(context);
            return const ColoredBox(color: Colors.blue);
          },
        ),
      ),
    );

    expect(scope, isNull);
  });

  testWidgets('parent layout changes preserve the card state', (tester) async {
    var initializations = 0;
    var disposals = 0;
    final width = ValueNotifier<double>(100);
    addTearDown(width.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<double>(
        valueListenable: width,
        builder: (context, value, _) => _app(
          width: value,
          child: LayoutBuilder(
            builder: (context, constraints) => _LifecycleProbe(
              onInit: () => initializations++,
              onDispose: () => disposals++,
            ),
          ),
        ),
      ),
    );
    width.value = 120;
    await tester.pumpAndSettle();

    expect(initializations, 1);
    expect(disposals, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('drag source can defer its context menu to the child', (
    tester,
  ) async {
    var childMenuCalls = 0;
    await tester.pumpWidget(
      _app(
        child: GestureDetector(
          key: const ValueKey('child-context-menu'),
          behavior: HitTestBehavior.opaque,
          onSecondaryTapDown: (_) => childMenuCalls++,
          child: const ColoredBox(color: Colors.blue),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('child-context-menu'))),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(childMenuCalls, 1);
    expect(find.byType(PopupMenuItem<bool>, skipOffstage: false), findsNothing);
  });

  group('drop region', () {
    testWidgets('hovering outside images shows the hint and keeps the panel', (
      tester,
    ) async {
      var initializations = 0;
      var disposals = 0;
      await tester.pumpWidget(
        _dropRegionApp(
          child: _LifecycleProbe(
            onInit: () => initializations++,
            onDispose: () => disposals++,
          ),
        ),
      );
      final region = tester.widget<DropRegion>(find.byType(DropRegion));
      final session = TestCardDropSession([
        TestCardDropItem(formats: [Formats.png]),
      ]);
      addTearDown(session.dispose);

      expect(
        await region.onDropOver(
          DropOverEvent(session: session, position: testCardDropPosition),
        ),
        DropOperation.copy,
      );
      await tester.pump();
      expect(find.text('Drop to add to the chat'), findsOneWidget);

      region.onDropLeave?.call(DropEvent(session: session));
      await tester.pump();
      expect(find.text('Drop to add to the chat'), findsNothing);
      expect(initializations, 1);
      expect(disposals, 0);
    });

    testWidgets('a panel that is not ready refuses every drop', (tester) async {
      await tester.pumpWidget(_dropRegionApp(enabled: false));
      final region = tester.widget<DropRegion>(find.byType(DropRegion));

      for (final item in [
        TestCardDropItem.resource('vibe-1'),
        TestCardDropItem(formats: [Formats.png]),
      ]) {
        final session = TestCardDropSession([item]);
        addTearDown(session.dispose);
        expect(
          await region.onDropOver(
            DropOverEvent(session: session, position: testCardDropPosition),
          ),
          DropOperation.none,
        );
      }
      await tester.pump();
      expect(find.text('Drop to add to the chat'), findsNothing);
    });

    testWidgets('resources stay references and outside images go inline', (
      tester,
    ) async {
      final references = <String>[];
      final images = <String>[];
      final external = TestCardDropItem(formats: [Formats.png]);
      await tester.pumpWidget(
        _dropRegionApp(
          onDrop: (reference) async => references.add(reference.resourceId),
          onDropImages: (files) async =>
              images.addAll(files.map((file) => file.fileName)),
          readExternalImage: (item) async => identical(item, external)
              ? DroppedFileData(fileName: 'shot.png', bytes: Uint8List(8))
              : null,
        ),
      );
      final region = tester.widget<DropRegion>(find.byType(DropRegion));
      final session = TestCardDropSession([
        TestCardDropItem.resource('vibe-1'),
        external,
      ]);
      addTearDown(session.dispose);

      await region.onPerformDrop(
        PerformDropEvent(
          session: session,
          position: testCardDropPosition,
          acceptedOperation: DropOperation.copy,
        ),
      );

      expect(references, ['vibe-1']);
      expect(images, ['shot.png']);
    });

    testWidgets('unreadable items are reported and readable ones still land', (
      tester,
    ) async {
      final images = <String>[];
      final readable = TestCardDropItem(formats: [Formats.png]);
      final pendingRead = Completer<DroppedFileData?>();
      await tester.pumpWidget(
        _dropRegionApp(
          onDropImages: (files) async =>
              images.addAll(files.map((file) => file.fileName)),
          readExternalImage: (item) => identical(item, readable)
              ? pendingRead.future
              : Future.value(),
        ),
      );
      final region = tester.widget<DropRegion>(find.byType(DropRegion));
      final session = TestCardDropSession([
        TestCardDropItem(formats: [Formats.fileUri]),
        readable,
      ]);
      addTearDown(session.dispose);

      final drop = region.onPerformDrop(
        PerformDropEvent(
          session: session,
          position: testCardDropPosition,
          acceptedOperation: DropOperation.copy,
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      pendingRead.complete(
        DroppedFileData(fileName: 'kept.png', bytes: Uint8List(8)),
      );
      await drop;
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(images, ['kept.png']);
      expect(find.textContaining('1/2'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
    });
  });
}

Widget _dropRegionApp({
  bool enabled = true,
  Future<void> Function(AgentChatResourceReference reference)? onDrop,
  Future<void> Function(List<DroppedFileData> files)? onDropImages,
  AgentChatExternalImageReader? readExternalImage,
  Widget child = const ColoredBox(color: Colors.blue),
}) {
  return ProviderScope(
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: AgentResourceDropRegion(
          enabled: enabled,
          onDrop: onDrop ?? (_) async {},
          onDropImages: onDropImages ?? (_) async {},
          readExternalImage: readExternalImage ?? (_) async => null,
          child: child,
        ),
      ),
    ),
  );
}

Widget _manySourcesApp() {
  return ProviderScope(
    overrides: [onlineGalleryNotifierProvider.overrideWith(_TestGallery.new)],
    child: MaterialApp(
      home: Scaffold(
        body: GridView.count(
          crossAxisCount: 4,
          children: List.generate(
            24,
            (index) => AgentResourceDragSource(
              reference: AgentChatResourceReference(
                kind: AgentChatResourceKind.onlineGalleryMedia,
                source: 'danbooru',
                resourceId: '$index',
              ),
              child: ColoredBox(color: Colors.primaries[index % 18]),
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _app({
  double width = 100,
  Widget? child,
  bool enableAddToAgentAction = true,
}) {
  return ProviderScope(
    overrides: [onlineGalleryNotifierProvider.overrideWith(_TestGallery.new)],
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            height: 100,
            child: AgentResourceDragSource(
              enableAddToAgentAction: enableAddToAgentAction,
              reference: AgentChatResourceReference(
                kind: AgentChatResourceKind.onlineGalleryMedia,
                source: 'danbooru',
                resourceId: '1',
                mediaId: 'cover-1',
              ),
              child: child ?? const ColoredBox(color: Colors.blue),
            ),
          ),
        ),
      ),
    ),
  );
}

final class _FakeDragSession extends DragSession {
  final _dragging = ValueNotifier(false);
  final _completed = ValueNotifier<DropOperation?>(null);
  final _location = ValueNotifier<Offset?>(null);

  @override
  ValueListenable<bool> get dragging => _dragging;

  @override
  ValueListenable<DropOperation?> get dragCompleted => _completed;

  @override
  ValueListenable<Offset?> get lastScreenLocation => _location;

  @override
  Future<List<Object?>?> getLocalData() async => null;

  void dispose() {
    _dragging.dispose();
    _completed.dispose();
    _location.dispose();
  }
}

class _LifecycleProbe extends StatefulWidget {
  const _LifecycleProbe({required this.onInit, required this.onDispose});

  final VoidCallback onInit;
  final VoidCallback onDispose;

  @override
  State<_LifecycleProbe> createState() => _LifecycleProbeState();
}

class _LifecycleProbeState extends State<_LifecycleProbe> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const ColoredBox(color: Colors.blue);
}

class _TestGallery extends OnlineGalleryNotifier {
  @override
  OnlineGalleryState build() => const OnlineGalleryState();
}
