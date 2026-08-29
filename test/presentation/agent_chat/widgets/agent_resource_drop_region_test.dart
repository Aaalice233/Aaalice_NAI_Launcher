import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/resources/agent_chat_resource_reference.dart';
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

Widget _app({double width = 100, Widget? child}) {
  return ProviderScope(
    child: MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            height: 100,
            child: AgentResourceDragSource(
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
