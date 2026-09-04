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
        'Do not call get_recent_images, read, inspect_images, or '
        'display_images merely to inspect or repeat that same output.',
      ),
    );
    expect(
      prompt,
      contains(
        'Only retrieve it again when the user explicitly asks to reopen, '
        'compare, inspect, or analyze the image, or when you need '
        'coordinates for create_inpaint_mask.',
      ),
    );
    // 量坐标必须走 read：图片展示通道是缩略图，够看不够量。
    expect(
      prompt,
      contains(
        'inspect_images and display_images return small previews that are too '
        'coarse to measure a region from.',
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

  test('distinguishes private inspection from user-visible display', () {
    final prompt = buildAgentSystemPrompt(
      workspacePath: 'C:/exports',
      webAccessEnabled: false,
      skillBlock: '',
    );

    expect(
      prompt,
      contains(
        'inspect_images is private visual inspection: the model receives the '
        'images but the user does not.',
      ),
    );
    expect(
      prompt,
      contains(
        'Do not say or imply that the user can see an image unless '
        'display_images succeeded with user_visible=true',
      ),
    );
  });

  test('separates the persistent source-image slot from one-shot img2img', () {
    final prompt = buildAgentSystemPrompt(
      workspacePath: 'C:/exports',
      webAccessEnabled: false,
      skillBlock: '',
    );

    expect(
      prompt,
      contains(
        'those are one-shot overrides for that single transaction and leave '
        'the page untouched',
      ),
    );
    expect(
      prompt,
      contains(
        'Use the source-image tools whenever the user should see the image '
        'sitting in the Image2Image panel.',
      ),
    );
    expect(prompt, contains('set_generation_source_image'));
    expect(prompt, contains('clear_generation_source_image'));
    expect(prompt, contains('update_generation_source_settings'));
  });
}
