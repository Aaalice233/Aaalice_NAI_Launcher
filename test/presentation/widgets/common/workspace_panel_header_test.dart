import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/themes/core/layered_surface_style.dart';
import 'package:nai_launcher/presentation/widgets/common/workspace_panel_header.dart';

void main() {
  testWidgets('统一面板顶栏使用 Section 色面并将尾部操作贴齐右侧', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: WorkspacePanelHeader(
              icon: Icons.brush_outlined,
              title: const Text('画布'),
              trailing: IconButton(
                key: const ValueKey('trailing-action'),
                onPressed: () {},
                icon: const Icon(Icons.chevron_left),
              ),
            ),
          ),
        ),
      ),
    );

    final header = find.byType(WorkspacePanelHeader);
    final headerRect = tester.getRect(header);
    final trailingRect = tester.getRect(
      find.byKey(const ValueKey('trailing-action')),
    );
    final surface = tester.widget<ColoredBox>(
      find.descendant(of: header, matching: find.byType(ColoredBox)).first,
    );
    final colors = Theme.of(tester.element(header)).colorScheme;

    expect(headerRect.height, 56);
    expect(trailingRect.right, closeTo(headerRect.right - 4, 0.01));
    expect(surface.color, sectionSurfaceColor(colors));
  });
}
