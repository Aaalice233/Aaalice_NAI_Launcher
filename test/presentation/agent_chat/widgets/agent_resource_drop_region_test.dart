import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference_codec.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_resource_drop_region.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

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
    await tester.pumpWidget(_app());
    final dragWidget = tester.widget<DragItemWidget>(
      find.byType(DragItemWidget),
    );
    final session = _FakeDragSession();
    addTearDown(session.dispose);

    final item = await tester.runAsync(() async {
      final provided = dragWidget.dragItemProvider(
        DragItemRequest(location: Offset.zero, session: session),
      );
      return Future<DragItem?>.value(provided);
    });

    expect(item, isNotNull);
    expect(item!.localData, isA<String>());
    final decoded = AgentChatResourceReferenceCodec.decodeJson(
      item.localData! as String,
    );
    expect(decoded.kind, AgentChatResourceKind.onlineGalleryMedia);
    expect(decoded.source, 'danbooru');
    expect(decoded.resourceId, '1');
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
        enableAddToAgentMenu: false,
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
}

Widget _manySourcesApp() {
  return ProviderScope(
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
  bool enableAddToAgentMenu = true,
}) {
  return ProviderScope(
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
              enableAddToAgentMenu: enableAddToAgentMenu,
              reference: AgentChatResourceReference(
                kind: AgentChatResourceKind.onlineGalleryMedia,
                source: 'danbooru',
                resourceId: '1',
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
