import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/agent/agent_types.dart';
import 'package:nai_launcher/core/agent/harness/harness_types.dart';
import 'package:nai_launcher/core/agent/harness/skills.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';
import 'package:nai_launcher/data/models/image/image_params.dart'
    show ImageParams;
import 'package:nai_launcher/presentation/agent_chat/services/prompt_toolbox.dart';
import 'package:nai_launcher/presentation/providers/character_prompt_provider.dart';
import 'package:nai_launcher/presentation/providers/generation/generation_params_notifier.dart';

final _refProvider = Provider<Ref>((ref) => ref);

String _resultText(AgentToolResult result) => result.content
    .whereType<ToolResultTextContent>()
    .map((content) => content.text)
    .join();

void main() {
  test('read_skill_resource stays within its skill directory', () async {
    final root = await Directory.systemTemp.createTemp('prompt-toolbox-');
    addTearDown(() => root.delete(recursive: true));
    final skillDir = Directory(
      '${root.path}${Platform.pathSeparator}demo-skill',
    );
    final references = Directory(
      '${skillDir.path}${Platform.pathSeparator}references',
    );
    await references.create(recursive: true);
    final skillFile = File('${skillDir.path}${Platform.pathSeparator}SKILL.md');
    await skillFile.writeAsString('instructions');
    await File(
      '${references.path}${Platform.pathSeparator}guide.txt',
    ).writeAsString('first\nsecond\nthird');
    await File(
      '${root.path}${Platform.pathSeparator}secret.txt',
    ).writeAsString('outside');
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final toolbox = PromptToolbox(
      container.read(_refProvider),
      skills: {
        'demo-skill': HarnessSkill(
          name: 'demo-skill',
          description: 'Demo',
          content: 'instructions',
          filePath: skillFile.path,
        ),
      },
    );
    final tool = toolbox.tools().firstWhere(
      (item) => item.name == 'read_skill_resource',
    );

    await File(
      '${references.path}${Platform.pathSeparator}paths.txt',
    ).writeAsString('Open C:/Users/Alice/private.txt and /home/alice/private.');

    final allowed = await tool.execute('read-allowed', {
      'name': 'demo-skill',
      'path': 'references/guide.txt',
      'offset': 1,
      'limit': 1,
    });
    final blocked = await tool.execute('read-blocked', {
      'name': 'demo-skill',
      'path': '../secret.txt',
    });

    expect(allowed.isError, isFalse);
    expect(jsonDecode(_resultText(allowed))['content'], 'second');
    expect(blocked.isError, isTrue);
    expect(_resultText(blocked), contains('not permitted'));
    expect(_resultText(blocked), isNot(contains(root.path)));

    final redacted = await tool.execute('read-redacted', {
      'name': 'demo-skill',
      'path': 'references/paths.txt',
    });
    expect(redacted.isError, isFalse);
    expect(_resultText(redacted), contains('[absolute path]'));
    expect(_resultText(redacted), isNot(contains('C:/Users/Alice')));
    expect(_resultText(redacted), isNot(contains('/home/alice')));
  });

  test('read_skill redacts absolute paths from instructions', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final tool = PromptToolbox(
      container.read(_refProvider),
      skills: const {
        'demo': HarnessSkill(
          name: 'demo',
          description: 'Demo',
          content: 'Read C:/Users/Alice/private.txt or file:///home/alice/key.',
          filePath: 'C:/skills/demo/SKILL.md',
        ),
      },
    ).tools().firstWhere((item) => item.name == 'read_skill');

    final result = await tool.execute('read', const {'name': 'demo'});
    expect(_resultText(result), contains('[absolute path]'));
    expect(_resultText(result), isNot(contains('C:/Users/Alice')));
    expect(_resultText(result), isNot(contains('/home/alice')));
  });

  test('get_skill_diagnostics exposes the latest load warnings', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final tool = PromptToolbox(
      container.read(_refProvider),
      skillDiagnostics: const [
        SkillDiagnostic(
          code: SkillDiagnosticCode.invalidMetadata,
          message: 'bad name at C:/skills/bad/SKILL.md',
          path: 'C:/skills/bad/SKILL.md',
        ),
      ],
    ).tools().firstWhere((item) => item.name == 'get_skill_diagnostics');

    final result = await tool.execute('diagnostics', const {});
    final json = jsonDecode(_resultText(result)) as Map<String, dynamic>;

    expect(json['count'], 1);
    expect(json['diagnostics'][0]['code'], 'invalidMetadata');
    expect(json['diagnostics'][0]['path'], '.../skills/bad/SKILL.md');
    expect(_resultText(result), isNot(contains('C:/skills')));
  });

  test('add_character updates the newly created duplicate name', () async {
    final container = ProviderContainer(
      overrides: [
        generationParamsNotifierProvider.overrideWith(
          _TestGenerationParamsNotifier.new,
        ),
        characterPromptNotifierProvider.overrideWith(
          _DuplicateNameCharacterNotifier.new,
        ),
      ],
    );
    addTearDown(container.dispose);
    final tool = PromptToolbox(
      container.read(_refProvider),
    ).tools().firstWhere((item) => item.name == 'add_character');

    final result = await tool.execute('add-duplicate', const {
      'name': 'Alice',
      'prompt': 'blue hair',
      'negative_prompt': 'red hair',
    });

    expect(result.isError, isFalse);
    final json = jsonDecode(_resultText(result)) as Map<String, dynamic>;
    expect(json['character']['id'], 'new-character');
    final characters = container
        .read(characterPromptNotifierProvider)
        .characters;
    expect(characters, hasLength(2));
    expect(characters.first.negativePrompt, 'old negative');
    expect(characters.last.negativePrompt, 'red hair');
  });
}

class _TestGenerationParamsNotifier extends GenerationParamsNotifier {
  @override
  ImageParams build() => const ImageParams();
}

class _DuplicateNameCharacterNotifier extends CharacterPromptNotifier {
  @override
  CharacterPromptConfig build() => const CharacterPromptConfig(
    characters: [
      CharacterPrompt(
        id: 'old-character',
        name: 'Alice',
        prompt: 'black hair',
        negativePrompt: 'old negative',
      ),
    ],
  );

  @override
  void addCharacter(
    CharacterGender gender, {
    String? name,
    String? prompt,
    String? negativePrompt,
    String? thumbnailPath,
  }) {
    state = state.copyWith(
      characters: [
        ...state.characters,
        CharacterPrompt(
          id: 'new-character',
          name: name ?? '',
          prompt: prompt ?? '',
          negativePrompt: negativePrompt ?? '',
          gender: gender,
        ),
      ],
    );
  }

  @override
  void updateCharacter(CharacterPrompt character) {
    state = state.copyWith(
      characters: [
        for (final current in state.characters)
          if (current.id == character.id) character else current,
      ],
    );
  }
}
