import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/presentation/agent_chat/widgets/agent_resource_drop_region.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

void main() {
  tearDown(() => PlatformCapabilities.debugOverride = null);

  testWidgets('desktop deferred drag source registers only while hovered', (
    tester,
  ) async {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.windows,
    );
    await tester.pumpWidget(_manySourcesApp());

    expect(find.byType(AgentResourceDragSource), findsAtLeastNWidgets(8));
    expect(find.byType(DragItemWidget), findsNothing);
    expect(find.byType(DraggableWidget), findsNothing);

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(const Offset(50, 50)));
    await tester.pump();

    expect(find.byType(DragItemWidget), findsOneWidget);
    expect(find.byType(DraggableWidget), findsOneWidget);

    await tester.sendEventToBinding(pointer.hover(const Offset(900, 700)));
    await tester.pump();

    expect(find.byType(DragItemWidget), findsNothing);
    expect(find.byType(DraggableWidget), findsNothing);
  });

  testWidgets('desktop hover registration preserves the card state', (
    tester,
  ) async {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.windows,
    );
    var initializations = 0;
    var disposals = 0;
    await tester.pumpWidget(
      _app(
        deferDesktopRegistration: true,
        child: _LifecycleProbe(
          onInit: () => initializations++,
          onDispose: () => disposals++,
        ),
      ),
    );

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(const Offset(50, 50)));
    await tester.pump();
    await tester.sendEventToBinding(pointer.hover(const Offset(500, 500)));
    await tester.pump();

    expect(initializations, 1);
    expect(disposals, 0);
  });

  testWidgets('desktop drag source stays registered until pointer up', (
    tester,
  ) async {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.windows,
    );
    await tester.pumpWidget(_app(deferDesktopRegistration: true));

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(const Offset(50, 50)));
    await tester.pump();
    await tester.sendEventToBinding(pointer.down(const Offset(50, 50)));
    await tester.sendEventToBinding(pointer.move(const Offset(500, 500)));
    await tester.pump();

    expect(find.byType(DragItemWidget), findsOneWidget);

    await tester.sendEventToBinding(pointer.up());
    await tester.pump();

    expect(find.byType(DragItemWidget), findsNothing);
  });

  testWidgets('touch platform keeps deferred drag source registered', (
    tester,
  ) async {
    PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
      TargetPlatform.android,
    );
    await tester.pumpWidget(_app(deferDesktopRegistration: true));

    expect(find.byType(DragItemWidget), findsOneWidget);
    expect(find.byType(DraggableWidget), findsOneWidget);
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
              deferDesktopRegistration: true,
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

Widget _app({required bool deferDesktopRegistration, Widget? child}) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 100,
            height: 100,
            child: AgentResourceDragSource(
              deferDesktopRegistration: deferDesktopRegistration,
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
