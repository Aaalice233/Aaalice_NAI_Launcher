import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/canvas/editor_canvas.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/core/editor_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('EditorCanvas settles immediately when there is no selection', (
    tester,
  ) async {
    final state = EditorState();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EditorCanvas(state: state)),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    state.dispose();
  });
}
