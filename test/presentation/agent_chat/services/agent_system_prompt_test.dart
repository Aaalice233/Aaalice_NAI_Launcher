import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_system_prompt.dart';

void main() {
  test('does not inspect or repeat direct generation output by default', () {
    final prompt = buildAgentSystemPrompt(
      workspacePath: 'C:/exports',
      webAccessEnabled: false,
      skillBlock: '',
    );

    expect(
      prompt,
      contains(
        'Do not call get_recent_images, read, preview_generated_image, or '
        'display_images merely to inspect or repeat that same output.',
      ),
    );
    expect(
      prompt,
      contains(
        'Only retrieve it again when the user explicitly asks to reopen, '
        'compare, inspect, or analyze the image.',
      ),
    );
    expect(
      prompt,
      contains(
        'path is the exact workspace-relative argument for read, while '
        'resource_ref is an application-owned identity',
      ),
    );
    expect(
      prompt,
      contains(
        'Never turn resource_ref/resourceId into a path, filename, or '
        'extension.',
      ),
    );
  });
}
