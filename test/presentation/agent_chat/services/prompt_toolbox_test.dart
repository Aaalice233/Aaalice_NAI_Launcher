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

  test(
    'character tools expose, position, switch, and reorder full state',
    () async {
      final container = ProviderContainer(
        overrides: [
          generationParamsNotifierProvider.overrideWith(
            _TestGenerationParamsNotifier.new,
          ),
          characterPromptNotifierProvider.overrideWith(
            _OrchestrationCharacterNotifier.new,
          ),
        ],
      );
      addTearDown(container.dispose);
      final tools = PromptToolbox(container.read(_refProvider)).tools();
      AgentTool tool(String name) =>
          tools.firstWhere((candidate) => candidate.name == name);

      final initial = jsonDecode(
        _resultText(await tool('get_prompt_state').execute('read', const {})),
      );
      expect(initial['character_layout_mode'], 'ai_choice');
      expect(initial['characters'][0]['id'], 'first');
      expect(initial['characters'][0]['order'], 0);
      expect(initial['characters'][0]['position_x'], 0.2);

      final preserved = await tool('update_character').execute(
        'preserve-position',
        const {'id': 'first', 'prompt': 'updated hero'},
      );
      expect(preserved.isError, isFalse);
      final preservedCharacter = container
          .read(characterPromptNotifierProvider)
          .characters
          .firstWhere((character) => character.id == 'first');
      expect(preservedCharacter.positionMode, CharacterPositionMode.aiChoice);
      expect(preservedCharacter.customPosition?.column, 0.2);
      expect(preservedCharacter.customPosition?.row, 0.4);

      final missingCustom = await tool('update_character').execute(
        'missing-custom',
        const {'id': 'second', 'position_mode': 'custom'},
      );
      expect(missingCustom.isError, isTrue);
      expect(
        _resultText(missingCustom),
        contains('missing_character_coordinates'),
      );

      final partial = await tool(
        'update_character',
      ).execute('partial', const {'id': 'second', 'position_x': 0.5});
      expect(partial.isError, isTrue);
      expect(_resultText(partial), contains('partial_character_coordinates'));

      final updated = await tool('update_character').execute('position', const {
        'id': 'second',
        'position_x': 0.8,
        'position_y': 0.3,
      });
      expect(updated.isError, isFalse);
      expect(
        jsonDecode(_resultText(updated))['character']['position_mode'],
        'custom',
      );
      expect(
        container.read(characterPromptNotifierProvider).globalAiChoice,
        isFalse,
      );

      await tool(
        'set_character_layout_mode',
      ).execute('custom', const {'mode': 'custom'});
      final reordered = await tool('reorder_characters').execute(
        'reorder',
        const {
          'ordered_ids': ['second', 'first'],
        },
      );
      expect(reordered.isError, isFalse);
      expect(
        jsonDecode(_resultText(reordered))['characters'][0]['id'],
        'second',
      );

      await tool(
        'set_character_layout_mode',
      ).execute('ai', const {'mode': 'ai_choice'});
      final config = container.read(characterPromptNotifierProvider);
      expect(config.globalAiChoice, isTrue);
      expect(config.characters.first.customPosition?.column, 0.8);
      expect(config.characters.first.customPosition?.row, 0.3);
    },
  );

  test('rejects ambiguous or conflicting character selectors', () async {
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
    final tools = PromptToolbox(container.read(_refProvider)).tools();
    AgentTool tool(String name) =>
        tools.firstWhere((candidate) => candidate.name == name);
    await tool(
      'add_character',
    ).execute('duplicate', const {'name': 'Alice', 'prompt': 'blue hair'});

    final ambiguous = await tool(
      'update_character',
    ).execute('ambiguous', const {'name': 'Alice', 'prompt': 'changed'});
    expect(ambiguous.isError, isTrue);
    expect(_resultText(ambiguous), contains('invalid_character_selector'));

    final conflicting = await tool('remove_character').execute(
      'conflicting',
      const {'id': 'old-character', 'name': 'Different'},
    );
    expect(conflicting.isError, isTrue);
    expect(_resultText(conflicting), contains('invalid_character_selector'));

    final missingId = await tool(
      'remove_character',
    ).execute('missing-id', const {'id': 'missing', 'name': 'Alice'});
    expect(missingId.isError, isTrue);
    expect(_resultText(missingId), contains('character_not_found'));

    final invalidGender = await tool('update_character').execute(
      'invalid-gender',
      const {'id': 'old-character', 'gender': 'robot'},
    );
    expect(invalidGender.isError, isTrue);
    expect(_resultText(invalidGender), contains('invalid_character_gender'));

    final invalidPrompt = await tool(
      'add_character',
    ).execute('invalid-prompt', const {'name': 'Bob', 'prompt': 42});
    expect(invalidPrompt.isError, isTrue);
    expect(_resultText(invalidPrompt), contains('invalid_character_field'));

    final invalidSelector = await tool(
      'remove_character',
    ).execute('invalid-selector', const {'id': 42});
    expect(invalidSelector.isError, isTrue);
    expect(_resultText(invalidSelector), contains('invalid_character_field'));
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
    expect(characters.last.positionMode, CharacterPositionMode.aiChoice);
    expect(characters.last.customPosition, isNull);

    final customWithoutCoordinates = await tool.execute(
      'add-custom-without-coordinates',
      const {
        'name': 'Manual',
        'prompt': 'green hair',
        'position_mode': 'custom',
      },
    );
    expect(customWithoutCoordinates.isError, isTrue);
    expect(
      _resultText(customWithoutCoordinates),
      contains('missing_character_coordinates'),
    );

    final positionModeSchema =
        (tool.parameters['properties'] as Map<String, dynamic>)['position_mode']
            as Map<String, dynamic>;
    expect(positionModeSchema['default'], 'ai_choice');
  });
}

class _TestGenerationParamsNotifier extends GenerationParamsNotifier {
  @override
  ImageParams build() => const ImageParams();
}

class _OrchestrationCharacterNotifier extends CharacterPromptNotifier {
  @override
  CharacterPromptConfig build() => const CharacterPromptConfig(
    globalAiChoice: true,
    characters: [
      CharacterPrompt(
        id: 'first',
        name: 'First',
        prompt: 'hero',
        positionMode: CharacterPositionMode.aiChoice,
        customPosition: CharacterPosition(
          mode: CharacterPositionMode.custom,
          row: 0.4,
          column: 0.2,
        ),
      ),
      CharacterPrompt(id: 'second', name: 'Second', prompt: 'companion'),
    ],
  );

  @override
  Future<bool> updateCharacterPersisted(CharacterPrompt character) async {
    state = state.updateCharacter(character).normalizeCustomPositions();
    return true;
  }

  @override
  Future<bool> setGlobalAiChoicePersisted(bool value) async {
    var next = state.copyWith(globalAiChoice: value);
    if (!value) next = next.normalizeCustomPositions();
    state = next;
    return true;
  }

  @override
  Future<bool> setCharacterOrderPersisted(List<String> orderedIds) async {
    final byId = {
      for (final character in state.characters) character.id: character,
    };
    state = state.copyWith(
      characters: [for (final id in orderedIds) byId[id]!],
    );
    return true;
  }
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
  Future<({CharacterPrompt character, bool persisted})?> addCharacterPersisted(
    CharacterGender gender, {
    required String name,
    required String prompt,
    String? negativePrompt,
    required bool enabled,
    required CharacterPositionMode positionMode,
    CharacterPosition? customPosition,
  }) async {
    final created = CharacterPrompt(
      id: 'new-character',
      name: name,
      prompt: prompt,
      negativePrompt: negativePrompt ?? '',
      gender: gender,
      enabled: enabled,
      positionMode: positionMode,
      customPosition: customPosition,
    );
    state = state.copyWith(characters: [...state.characters, created]);
    return (character: created, persisted: true);
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
