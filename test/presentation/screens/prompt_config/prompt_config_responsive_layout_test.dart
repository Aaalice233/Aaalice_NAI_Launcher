import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/screens/prompt_config/prompt_config_screen.dart';

void main() {
  test('prompt config keeps inspector only when width and text fit', () {
    expect(useExpandedPromptConfigLayout(1180, 1), isTrue);
    expect(useExpandedPromptConfigLayout(1180, 1.5), isTrue);
    expect(useExpandedPromptConfigLayout(840, 1), isFalse);
    expect(useExpandedPromptConfigLayout(1180, 1.51), isFalse);
    expect(useExpandedPromptConfigLayout(1600, 3), isFalse);
  });
}
