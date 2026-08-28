import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_system_prompt.dart';
import 'package:nai_launcher/core/agent/harness/harness_types.dart';
import 'package:nai_launcher/data/models/agent/agent_settings.dart';

void main() {
  test(
    'composes immutable built-in, custom, and model-visible Skill layers',
    () {
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
        builtInPrompt: ['BUILT_IN', skillBlock].join('\n'),
        customInstructions: 'CUSTOM',
        mode: AgentSystemPromptMode.append,
      );

      expect(prompt.indexOf('BUILT_IN'), lessThan(prompt.indexOf('CUSTOM')));
      expect(prompt, contains('<name>visible</name>'));
      expect(prompt, isNot(contains('<name>manual</name>')));
    },
  );

  test('normalizes empty layers without changing built-in content', () {
    expect(
      composeAgentSystemPrompt(
        builtInPrompt: '  BUILT_IN  ',
        customInstructions: '  ',
        mode: AgentSystemPromptMode.append,
      ),
      'BUILT_IN',
    );
  });

  test('override returns only user content without built-in or Skill text', () {
    final prompt = composeAgentSystemPrompt(
      builtInPrompt: 'BUILT_IN\n<skills>OLD_SKILL</skills>',
      customInstructions: '  ONLY_USER_CONTENT  ',
      mode: AgentSystemPromptMode.override,
    );

    expect(prompt, 'ONLY_USER_CONTENT');
    expect(prompt, isNot(contains('BUILT_IN')));
    expect(prompt, isNot(contains('OLD_SKILL')));
  });
}
