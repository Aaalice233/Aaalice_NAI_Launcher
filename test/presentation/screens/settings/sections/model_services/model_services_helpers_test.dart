import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/model_services/model_capability_tags.dart';
import 'package:nai_launcher/presentation/screens/settings/sections/model_services/model_family_group.dart';

void main() {
  group('modelFamilyGroup', () {
    test('groups by the first two segments', () {
      expect(modelFamilyGroup('gpt-4o-mini'), 'gpt-4o');
      expect(modelFamilyGroup('gpt-4o'), 'gpt-4o');
      expect(modelFamilyGroup('deepseek-v4-pro'), 'deepseek-v4');
      expect(modelFamilyGroup('claude_opus_4_8'), 'claude-opus');
    });

    test('uses the vendor or tag prefix of relay and Ollama IDs', () {
      expect(modelFamilyGroup('anthropic/claude-opus-4-8'), 'anthropic');
      expect(modelFamilyGroup('qwen3:8b'), 'qwen3');
    });

    test('normalizes case and whitespace and keeps single-segment IDs', () {
      expect(modelFamilyGroup('  DeepSeek-Flash '), 'deepseek-flash');
      expect(modelFamilyGroup('o3'), 'o3');
      expect(modelFamilyGroup('MiniMax-M2.7'), 'minimax-m2.7');
    });
  });

  test('formatContextWindow rounds catalog windows to K and M', () {
    expect(formatContextWindow(128000), '128K');
    expect(formatContextWindow(131072), '131K');
    expect(formatContextWindow(1000000), '1M');
    expect(formatContextWindow(1048576), '1M');
    expect(formatContextWindow(2097152), '2.1M');
    expect(formatContextWindow(512), '512');
  });
}
