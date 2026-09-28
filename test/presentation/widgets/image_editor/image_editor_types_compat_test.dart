import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/image_editor/image_editor_screen_types.dart';

void main() {
  test('legacy editor types import remains a public facade', () {
    expect(ImageEditorMode.values, isNotEmpty);
  });
}
