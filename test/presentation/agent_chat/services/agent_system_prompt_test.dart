import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/agent/agent_settings.dart';
import 'package:nai_launcher/presentation/agent_chat/services/agent_system_prompt.dart';

void main() {
  test('plain-language replacement retains current execution context', () {
    final prompt = buildAgentSystemPrompt(
      workspacePath: 'E:/exports',
      webAccessEnabled: false,
      skillBlock: '<available_skills>CURRENT_SKILL</available_skills>',
      customInstructions: '请用中文回答，先给结论。',
      mode: AgentSystemPromptMode.override,
    );
    expect(prompt, startsWith('请用中文回答，先给结论。\n\n'));
    expect(prompt, isNot(contains('You are the AI agent inside Aaalice')));
    expect(
      prompt,
      isNot(contains('Character identity and appearance research:')),
    );
    expect(prompt, contains('E:/exports'));
    expect(prompt, contains('CURRENT_SKILL'));
    expect(prompt, contains('Web access is disabled'));
    expect(prompt, contains('prepare_generation first'));
    expect(prompt, contains('application permission gate is authoritative'));
  });

  test('runtime context refreshes without editing saved user text', () {
    const custom = '按我的风格回复。';
    final old = buildAgentSystemPrompt(
      workspacePath: '/old-device/exports',
      webAccessEnabled: false,
      skillBlock: 'OLD_SKILL',
      customInstructions: custom,
      mode: AgentSystemPromptMode.override,
    );
    final current = buildAgentSystemPrompt(
      workspacePath: '/new-device/exports',
      webAccessEnabled: true,
      skillBlock: 'NEW_SKILL',
      customInstructions: custom,
      mode: AgentSystemPromptMode.override,
    );
    expect(old, contains('/old-device/exports'));
    expect(current, startsWith(custom));
    expect(current, contains('/new-device/exports'));
    expect(current, contains('NEW_SKILL'));
    expect(current, isNot(contains('OLD_SKILL')));
    expect(current, isNot(contains('/old-device/exports')));
    expect(current, isNot(contains('Web access is disabled')));
    expect(current, contains('web_search returns'));
  });

  test(
    'character research is composed into the prompt and respects unavailable web access',
    () {
      final online = buildAgentSystemPrompt(
        workspacePath: 'workspace',
        webAccessEnabled: true,
        skillBlock: 'CUSTOM SKILL',
      );
      final offline = buildAgentSystemPrompt(
        workspacePath: 'workspace',
        webAccessEnabled: false,
        skillBlock: '',
      );
      final research = online.substring(
        online.indexOf('Character identity and appearance research:'),
      );
      expect(
        research.indexOf('web_search'),
        lessThan(research.indexOf('search_tags')),
      );
      expect(
        research.indexOf('search_tags'),
        lessThan(research.indexOf('browse_online_gallery')),
      );
      expect(research, contains('asks whether you know a named character'));
      expect(
        research,
        contains('not authorize editing prompts or generating an image'),
      );
      expect(online, contains('CUSTOM SKILL'));
      expect(offline, contains('Web access is disabled'));
      expect(offline, isNot(contains('First use web_search')));
      expect(online, contains('exactly zero'));
      expect(online, contains('without asking for confirmation'));
      expect(online, contains('Destructive operations and paid/unknown-cost'));
    },
  );
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
