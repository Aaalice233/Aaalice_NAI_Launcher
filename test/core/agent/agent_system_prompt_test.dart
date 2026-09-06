import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_system_prompt.dart';
import 'package:nai_launcher/core/agent/harness/harness_types.dart';
import 'package:nai_launcher/data/models/agent/agent_settings.dart';

void main() {
  test('composes built-in and custom text before current Skill context', () {
    const visible = HarnessSkill(
      name: 'visible',
      description: 'Visible skill',
      content: 'instructions',
      filePath: '/skills/visible/SKILL.md',
    );
    const manual = HarnessSkill(
      name: 'manual',
      description: 'Manual skill',
      content: 'instructions',
      filePath: '/skills/manual/SKILL.md',
      disableModelInvocation: true,
    );
    final skillBlock = formatSkillsForSystemPrompt(const [visible, manual]);
    final prompt = composeAgentSystemPrompt(
      builtInPrompt: 'BUILT_IN',
      customInstructions: 'CUSTOM',
      mode: AgentSystemPromptMode.append,
      runtimeContext: skillBlock,
    );

    expect(prompt.indexOf('BUILT_IN'), lessThan(prompt.indexOf('CUSTOM')));
    expect(prompt, contains('<name>visible</name>'));
    expect(prompt.indexOf('CUSTOM'), lessThan(prompt.indexOf('<name>visible')));
    expect(prompt, isNot(contains('<name>manual</name>')));
  });

  test('normalizes empty layers without changing built-in content', () {
    expect(
      composeAgentSystemPrompt(
        builtInPrompt: '  BUILT_IN  ',
        customInstructions: '  ',
        mode: AgentSystemPromptMode.append,
        runtimeContext: '  ',
      ),
      'BUILT_IN',
    );
  });

  test('override replaces the body while retaining runtime context', () {
    final prompt = composeAgentSystemPrompt(
      builtInPrompt: 'BUILT_IN',
      customInstructions: '  ONLY_USER_CONTENT  ',
      mode: AgentSystemPromptMode.override,
      runtimeContext: '<skills>CURRENT_SKILL</skills>',
    );

    expect(prompt, 'ONLY_USER_CONTENT\n\n<skills>CURRENT_SKILL</skills>');
    expect(prompt, isNot(contains('BUILT_IN')));
  });

  test(
    'empty override still includes application context without a fallback body',
    () {
      expect(
        composeAgentSystemPrompt(
          builtInPrompt: 'BUILT_IN',
          customInstructions: '  ',
          mode: AgentSystemPromptMode.override,
          runtimeContext: 'CURRENT_CONTEXT',
        ),
        'CURRENT_CONTEXT',
      );
    },
  );

  test('user text is literal and requires no template placeholders', () {
    const custom = r'保留 {tag}、{{workspace}} 和 $skillBlock 原文。';
    expect(
      composeAgentSystemPrompt(
        builtInPrompt: 'BUILT_IN',
        customInstructions: custom,
        mode: AgentSystemPromptMode.override,
        runtimeContext: 'CURRENT_CONTEXT',
      ),
      '$custom\n\nCURRENT_CONTEXT',
    );
  });
}
