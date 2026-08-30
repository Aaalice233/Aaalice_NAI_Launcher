import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/main_workspace.dart';

void main() {
  group('MainWorkspace classic prompt height', () {
    test('keeps the saved default height when prompt content is short', () {
      expect(
        MainWorkspace.resolveClassicPromptAreaHeight(
          storedHeight: 200,
          adaptiveHeight: 132,
          heightCap: 420,
        ),
        200,
      );
    });

    test('grows for longer prompt content', () {
      expect(
        MainWorkspace.resolveClassicPromptAreaHeight(
          storedHeight: 200,
          adaptiveHeight: 268,
          heightCap: 420,
        ),
        268,
      );
    });

    test('clamps a saved height to the current preview-safe cap', () {
      expect(
        MainWorkspace.resolveClassicPromptAreaHeight(
          storedHeight: 520,
          adaptiveHeight: 240,
          heightCap: 360,
        ),
        360,
      );
    });
  });
}
