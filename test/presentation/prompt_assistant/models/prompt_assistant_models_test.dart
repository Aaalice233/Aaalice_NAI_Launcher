import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/prompt_assistant/models/prompt_assistant_models.dart';

void main() {
  group('AgentPermissionMode persistence', () {
    for (final mode in AgentPermissionMode.values) {
      test('round-trips ${mode.name}', () {
        final encoded = PromptAssistantConfigState.defaults()
            .copyWith(agentPermissionMode: mode)
            .encode();

        final decoded = PromptAssistantConfigState.decode(encoded);

        expect(decoded.agentPermissionMode, mode);
      });
    }

    test('defaults missing or unknown values to confirmation mode', () {
      expect(
        AgentPermissionMode.fromName(null),
        AgentPermissionMode.askBeforeSensitiveActions,
      );
      expect(
        AgentPermissionMode.fromName('future-mode'),
        AgentPermissionMode.askBeforeSensitiveActions,
      );
    });
  });
}
