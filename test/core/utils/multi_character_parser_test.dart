import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/multi_character_parser.dart';
import 'package:nai_launcher/data/models/character/character_prompt.dart';

void main() {
  group('MultiCharacterParser 基础拆分测试', () {
    test('应该正确拆分全局提示词和角色', () {
      const input = '2girls, masterpiece\n| girl, black hair\n| girl, white hair';
      
      final result = MultiCharacterParser.parse(input);
      
      expect(result.globalPrompt, '2girls, masterpiece');
      expect(result.characters.length, 2);
      expect(result.characters[0].prompt, 'girl, black hair');
      expect(result.characters[1].prompt, 'girl, white hair');
      expect(result.hasMultipleCharacters, true);
    });

    test('应该处理只有全局提示词的情况（无分隔符）', () {
      const input = 'masterpiece, best quality';
      
      final result = MultiCharacterParser.parse(input);
      
      expect(result.globalPrompt, 'masterpiece, best quality');
      expect(result.characters.length, 0);
      expect(result.hasMultipleCharacters, false);
    });

    test('应该忽略内联管道符（无换行）', () {
      const input = '{red|blue} dress, {long|short} hair';
      
      final result = MultiCharacterParser.parse(input);
      
      expect(result.globalPrompt, '{red|blue} dress, {long|short} hair');
      expect(result.characters.length, 0);
      expect(result.hasMultipleCharacters, false);
    });

    test('应该正确处理空行和多余空格', () {
      const input = '  Global  \n|  \n  Char1  \n|  Char2  ';
      
      final result = MultiCharacterParser.parse(input);
      
      expect(result.globalPrompt, 'Global');
      expect(result.characters.length, 2);
      expect(result.characters[0].prompt, 'Char1');
      expect(result.characters[1].prompt, 'Char2');
    });

    test('应该跳过空段落', () {
      const input = 'Global\n|\n\n|  \nChar1';
      
      final result = MultiCharacterParser.parse(input);
      
      expect(result.globalPrompt, 'Global');
      expect(result.characters.length, 1);
      expect(result.characters[0].prompt, 'Char1');
    });

    test('应该处理空输入', () {
      const input = '';
      
      final result = MultiCharacterParser.parse(input);
      
      expect(result.globalPrompt, '');
      expect(result.characters.length, 0);
      expect(result.hasMultipleCharacters, false);
    });
  });

  group('MultiCharacterParser 性别推断测试', () {
    test('应该将 1boy 推断为 male', () {
      const input = 'global\n| 1boy, knight';
      
      final result = MultiCharacterParser.parse(input);
      
      expect(result.characters[0].gender, CharacterGender.male);
    });

    test('应该将 2boys 推断为 male', () {
      const input = 'global\n| 2boys, warriors';
      
      final result = MultiCharacterParser.parse(input);
      
      expect(result.characters[0].gender, CharacterGender.male);
    });

    test('应该将 1girl 推断为 female', () {
      const input = 'global\n| 1girl, mage';
      
      final result = MultiCharacterParser.parse(input);
      
      expect(result.characters[0].gender, CharacterGender.female);
    });

    test('应该将 3girls 推断为 female', () {
      const input = 'global\n| 3girls, idols';
      
      final result = MultiCharacterParser.parse(input);
      
      expect(result.characters[0].gender, CharacterGender.female);
    });

    test('应该将 male 标签推断为 male', () {
      const input = 'global\n| male, adult';
      
      final result = MultiCharacterParser.parse(input);
      
      expect(result.characters[0].gender, CharacterGender.male);
    });

    test('应该将 female 标签推断为 female', () {
      const input = 'global\n| female, adult';
      
      final result = MultiCharacterParser.parse(input);
      
      expect(result.characters[0].gender, CharacterGender.female);
    });

    test('应该默认为 female（无性别标签）', () {
      const input = 'global\n| character, tags';
      
      final result = MultiCharacterParser.parse(input);
      
      expect(result.characters[0].gender, CharacterGender.female);
    });

    test('应该按首次出现优先（male 在前）', () {
      const input = 'global\n| 1boy, 1girl, crossdressing';
      
      final result = MultiCharacterParser.parse(input);
      
      expect(result.characters[0].gender, CharacterGender.male);
    });

    test('应该按首次出现优先（female 在前）', () {
      const input = 'global\n| 1girl, 1boy, couple';
      
      final result = MultiCharacterParser.parse(input);
      
      expect(result.characters[0].gender, CharacterGender.female);
    });
  });

  group('MultiCharacterParser 角色命名测试', () {
    test('应该按 Character N 格式命名', () {
      const input = 'global\n| char1\n| char2\n| char3';
      
      final result = MultiCharacterParser.parse(input);
      
      expect(result.characters[0].name, 'Character 1');
      expect(result.characters[1].name, 'Character 2');
      expect(result.characters[2].name, 'Character 3');
    });
  });
}
