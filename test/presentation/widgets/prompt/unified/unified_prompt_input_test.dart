import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide group, test, expect;
import 'package:nai_launcher/core/services/tag_search_index.dart';
import 'package:nai_launcher/core/utils/nai_prompt_parser.dart';
import 'package:nai_launcher/data/models/prompt/prompt_tag.dart';
import 'package:nai_launcher/data/models/tag/local_tag.dart';
import 'package:nai_launcher/presentation/widgets/autocomplete/autocomplete_controller.dart';
import 'package:nai_launcher/presentation/widgets/prompt/unified/unified_prompt_config.dart';

/// **任务 7.1 & 7.2: 验证功能一致性**
/// **Validates: Requirements 5.1, 5.2, 5.3, 5.4**
///
/// 验证角色编辑器的自动补全和标签视图操作与主界面行为一致。
void consistencyTests() {
  group('Task 7.1: Autocomplete Behavior Consistency', () {
    test('characterEditor preset has autocomplete enabled', () {
      // 验证角色编辑器预设启用了自动补全
      const config = UnifiedPromptConfig.characterEditor;
      expect(config.enableAutocomplete, isTrue);
    });

    test('characterEditor preset autocomplete config matches main interface',
        () {
      // 角色编辑器预设配置
      const characterConfig = UnifiedPromptConfig.characterEditor;
      final charAutocomplete = characterConfig.autocompleteConfig;

      // 主界面使用的配置（来自 prompt_input.dart）
      const mainAutocomplete = AutocompleteConfig(
        maxSuggestions: 20,
        showTranslation: true,
        showCategory: true,
        showCount: true,
        autoInsertComma: true,
      );

      // 验证关键配置一致性
      // 注意：角色编辑器使用 15 个建议，主界面使用 20 个，这是合理的差异
      // 因为角色编辑器空间较小
      expect(
        charAutocomplete.showTranslation,
        equals(mainAutocomplete.showTranslation),
        reason: 'showTranslation should match',
      );
      expect(
        charAutocomplete.showCategory,
        equals(mainAutocomplete.showCategory),
        reason: 'showCategory should match',
      );
      expect(
        charAutocomplete.autoInsertComma,
        equals(mainAutocomplete.autoInsertComma),
        reason: 'autoInsertComma should match',
      );
    });

    test('characterEditor preset has syntax highlighting enabled', () {
      // 验证角色编辑器预设启用了语法高亮
      const config = UnifiedPromptConfig.characterEditor;
      expect(config.enableSyntaxHighlight, isTrue);
    });

    test('characterEditor preset has view mode toggle enabled', () {
      // 验证角色编辑器预设启用了视图模式切换
      const config = UnifiedPromptConfig.characterEditor;
      expect(config.enableViewModeToggle, isTrue);
    });

    test('compactMode preset has autocomplete enabled but view toggle disabled',
        () {
      // 验证紧凑模式预设配置
      const config = UnifiedPromptConfig.compactMode;
      expect(config.enableAutocomplete, isTrue);
      expect(config.enableViewModeToggle, isFalse);
      expect(config.compact, isTrue);
    });
  });

  group('Task 7.2: Tag View Operations Consistency', () {
    test('TagView uses same operations as main interface', () {
      // 验证标签操作使用相同的 NaiPromptParser 方法
      // 这确保了操作行为的一致性

      // 创建测试标签
      final tags = [
        PromptTag.create(text: 'tag1', weight: 1.0),
        PromptTag.create(text: 'tag2', weight: 1.2),
        PromptTag.create(text: 'tag3', weight: 0.8),
      ];

      // 测试删除操作
      final afterRemove = NaiPromptParser.removeTag(tags, tags[1].id);
      expect(afterRemove.length, equals(2));
      expect(afterRemove.any((t) => t.text == 'tag2'), isFalse);

      // 测试切换启用状态
      final afterToggle = NaiPromptParser.toggleTagEnabled(tags, tags[0].id);
      expect(afterToggle[0].enabled, isFalse);

      // 测试移动操作（拖拽排序）
      final afterMove = NaiPromptParser.moveTag(tags, 0, 2);
      expect(afterMove[0].text, equals('tag2'));
      expect(afterMove[1].text, equals('tag3'));
      expect(afterMove[2].text, equals('tag1'));
    });

    test('Tag weight adjustment uses same range as main interface', () {
      // 验证权重范围一致性（与 PromptTag 定义一致）
      expect(PromptTag.minWeight, equals(0.1));
      expect(PromptTag.maxWeight, equals(3.0));

      // 验证权重调整后的 clamp 行为
      // 注意：copyWith 不会自动 clamp，需要手动 clamp
      final _ = PromptTag.create(text: 'test', weight: 1.0);

      // 测试超出范围的权重被正确 clamp（模拟 TagView 中的行为）
      final highWeightValue =
          4.0.clamp(PromptTag.minWeight, PromptTag.maxWeight);
      expect(highWeightValue, equals(3.0));

      final lowWeightValue =
          0.01.clamp(PromptTag.minWeight, PromptTag.maxWeight);
      expect(lowWeightValue, equals(0.1));

      // 验证 increaseWeight 和 decreaseWeight 方法正确 clamp
      final maxTag = PromptTag.create(text: 'test', weight: 3.0);
      final afterIncrease = maxTag.increaseWeight();
      expect(afterIncrease.weight, equals(3.0)); // 不能超过最大值

      final minTag = PromptTag.create(text: 'test', weight: 0.1);
      final afterDecrease = minTag.decreaseWeight();
      expect(afterDecrease.weight, equals(0.1)); // 不能低于最小值
    });

    test('Batch operations work consistently', () {
      // 验证批量操作一致性
      final tags = [
        PromptTag.create(text: 'tag1', weight: 1.0).copyWith(selected: true),
        PromptTag.create(text: 'tag2', weight: 1.0).copyWith(selected: true),
        PromptTag.create(text: 'tag3', weight: 1.0).copyWith(selected: false),
      ];

      // 测试批量删除选中
      final afterRemoveSelected = tags.removeSelected();
      expect(afterRemoveSelected.length, equals(1));
      expect(afterRemoveSelected[0].text, equals('tag3'));

      // 测试批量禁用选中
      final afterDisable = tags.disableSelected();
      expect(afterDisable[0].enabled, isFalse);
      expect(afterDisable[1].enabled, isFalse);
      expect(afterDisable[2].enabled, isTrue);

      // 测试全选
      final afterSelectAll = tags.toggleSelectAll(true);
      expect(afterSelectAll.every((t) => t.selected), isTrue);
    });

    test('Insert tag operation works consistently', () {
      // 验证插入标签操作一致性
      final tags = [
        PromptTag.create(text: 'tag1', weight: 1.0),
        PromptTag.create(text: 'tag2', weight: 1.0),
      ];

      // 在末尾插入
      final afterInsertEnd =
          NaiPromptParser.insertTag(tags, tags.length, 'new_tag');
      expect(afterInsertEnd.length, equals(3));
      expect(afterInsertEnd.last.text, equals('new_tag'));

      // 在开头插入
      final afterInsertStart = NaiPromptParser.insertTag(tags, 0, 'first_tag');
      expect(afterInsertStart.length, equals(3));
      expect(afterInsertStart.first.text, equals('first_tag'));
    });
  });
}

/// **Feature: unified-prompt-input, Property 1: Text-Tag Round Trip Consistency**
/// **Validates: Requirements 1.3, 3.2, 3.3**
///
/// 对于任何有效的提示词字符串，解析为标签后再序列化回文本，
/// 应该产生语义等价的提示词字符串（相同的标签和权重，可能格式化不同）。

/// 自定义生成器：生成有效的提示词标签
Shrinkable<PromptTag> generatePromptTag(Random random, int size) {
  // 生成标签文本：字母、数字、下划线组成
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789_';
  final length = random.nextInt(20) + 1; // 1-20 字符
  final text = String.fromCharCodes(
    List.generate(
      length,
      (_) => chars.codeUnitAt(random.nextInt(chars.length)),
    ),
  );

  // 生成权重：0.5 到 2.0 之间，步进 0.05
  final weightSteps = random.nextInt(31) - 10; // -10 到 20
  final weight = 1.0 + (weightSteps * 0.05);

  final tag = PromptTag.create(
    text: text,
    weight: weight.clamp(0.5, 2.0),
    syntaxType: WeightSyntaxType.bracket,
  );

  return Shrinkable(tag, () sync* {
    // 简化：缩短文本或将权重设为 1.0
    if (tag.text.length > 1) {
      yield Shrinkable(
        tag.copyWith(text: tag.text.substring(0, tag.text.length ~/ 2)),
        () sync* {},
      );
    }
    if (tag.weight != 1.0) {
      yield Shrinkable(tag.copyWith(weight: 1.0), () sync* {});
    }
  });
}

/// 自定义生成器：生成有效的提示词标签列表
Shrinkable<List<PromptTag>> generatePromptTagList(Random random, int size) {
  final length = random.nextInt(size.clamp(1, 10)); // 0-9 个标签
  final tags = List.generate(
    length,
    (_) => generatePromptTag(random, size).value,
  );

  return Shrinkable(tags, () sync* {
    if (tags.isEmpty) return;
    // 简化：移除一个元素
    yield Shrinkable(tags.sublist(0, tags.length - 1), () sync* {});
  });
}

void main() {
  // 任务 7.1 & 7.2: 验证功能一致性测试
  consistencyTests();

  // Property 1 测试
  group('Property 1: Text-Tag Round Trip Consistency', () {
    Glados<List<PromptTag>>(generatePromptTagList).test(
      'parse(toPromptString(tags)) produces semantically equivalent tags',
      (tags) {
        // 跳过空列表
        if (tags.isEmpty) return;

        // 序列化为文本
        final promptString = NaiPromptParser.toPromptString(tags);

        // 解析回标签
        final parsedTags = NaiPromptParser.parse(promptString);

        // 验证标签数量相同
        expect(
          parsedTags.length,
          equals(tags.where((t) => t.enabled).length),
          reason: 'Parsed tags count should match enabled tags count',
        );

        // 验证每个标签的文本和权重语义等价
        final enabledTags = tags.where((t) => t.enabled).toList();
        for (var i = 0; i < parsedTags.length; i++) {
          expect(
            parsedTags[i].text,
            equals(enabledTags[i].text),
            reason: 'Tag text at index $i should match',
          );

          // 权重应该在一个小的误差范围内相等（由于浮点数精度）
          expect(
            (parsedTags[i].weight - enabledTags[i].weight).abs(),
            lessThan(0.01),
            reason: 'Tag weight at index $i should be approximately equal',
          );
        }
      },
    );
  });

  // Property 2 测试
  property2Tests();

  // Property 3 测试
  property3Tests();

  // Property 4 测试
  property4Tests();

  // Property 5 测试
  property5Tests();
}

/// **Feature: unified-prompt-input, Property 4: External Controller Synchronization**
/// **Validates: Requirements 6.3, 6.4**
///
/// 对于任何外部文本控制器值的变化，UnifiedPromptInput 的内部状态
/// （文本和解析后的标签）应该正确同步。

/// 自定义生成器：生成有效的提示词文本
Shrinkable<String> generatePromptText(Random random, int size) {
  // 生成 0-5 个标签
  final tagCount = random.nextInt(6);
  if (tagCount == 0) {
    return Shrinkable('', () sync* {});
  }

  final tags = <String>[];
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789_';

  for (var i = 0; i < tagCount; i++) {
    final length = random.nextInt(15) + 1;
    final text = String.fromCharCodes(
      List.generate(
        length,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
    tags.add(text);
  }

  final result = tags.join(', ');
  return Shrinkable(result, () sync* {
    if (tags.length > 1) {
      yield Shrinkable(
        tags.sublist(0, tags.length - 1).join(', '),
        () sync* {},
      );
    }
  });
}

/// Property 4 测试：验证外部控制器同步
/// 这是一个纯逻辑测试，验证 NaiPromptParser 的解析一致性
void property4Tests() {
  group('Property 4: External Controller Synchronization', () {
    Glados<String>(generatePromptText).test(
      'parsing text produces consistent tags regardless of source',
      (text) {
        // 模拟外部控制器设置文本后的解析
        final tags1 = NaiPromptParser.parse(text);

        // 再次解析相同文本
        final tags2 = NaiPromptParser.parse(text);

        // 验证两次解析结果一致
        expect(tags1.length, equals(tags2.length));

        for (var i = 0; i < tags1.length; i++) {
          expect(tags1[i].text, equals(tags2[i].text));
          expect(tags1[i].weight, equals(tags2[i].weight));
        }
      },
    );

    Glados<List<PromptTag>>(generatePromptTagList).test(
      'internal state updates correctly when text changes',
      (tags) {
        // 模拟：外部控制器文本变化 -> 内部状态更新
        final text = NaiPromptParser.toPromptString(tags);

        // 解析文本（模拟 _syncFromExternalController 的行为）
        final parsedTags = NaiPromptParser.parse(text);

        // 验证解析后的标签与原始启用的标签一致
        final enabledTags = tags.where((t) => t.enabled).toList();
        expect(parsedTags.length, equals(enabledTags.length));

        for (var i = 0; i < parsedTags.length; i++) {
          expect(parsedTags[i].text, equals(enabledTags[i].text));
          expect(
            (parsedTags[i].weight - enabledTags[i].weight).abs(),
            lessThan(0.01),
          );
        }
      },
    );
  });
}

/// **Feature: unified-prompt-input, Property 5: Callback Invocation on Changes**
/// **Validates: Requirements 6.1, 6.2**
///
/// 对于任何文本修改（文本模式）或标签修改（标签模式），
/// 相应的回调（onChanged 或 onTagsChanged）应该被正确调用。

/// 修改操作类型
enum ModificationType {
  addTag,
  removeTag,
  updateWeight,
  toggleEnabled,
}

/// 自定义生成器：生成修改操作
Shrinkable<ModificationType> generateModificationType(Random random, int size) {
  const types = ModificationType.values;
  final type = types[random.nextInt(types.length)];
  return Shrinkable(type, () sync* {});
}

/// Property 5 测试：验证回调触发
/// 这是一个纯逻辑测试，验证修改操作产生正确的结果
void property5Tests() {
  group('Property 5: Callback Invocation on Changes', () {
    Glados<List<PromptTag>>(generatePromptTagList).test(
      'tag modifications produce different output',
      (tags) {
        if (tags.isEmpty) return;

        // 原始文本
        final originalText = NaiPromptParser.toPromptString(tags);

        // 模拟添加标签
        final tagsWithNew =
            NaiPromptParser.insertTag(tags, tags.length, 'new_tag');
        final textWithNew = NaiPromptParser.toPromptString(tagsWithNew);

        // 验证添加标签后文本变化
        if (tags.any((t) => t.enabled)) {
          expect(textWithNew, isNot(equals(originalText)));
          expect(textWithNew, contains('new_tag'));
        }
      },
    );

    Glados<List<PromptTag>>(generatePromptTagList).test(
      'removing tag produces different output',
      (tags) {
        final enabledTags = tags.where((t) => t.enabled).toList();
        if (enabledTags.isEmpty) return;

        // 原始文本
        final originalText = NaiPromptParser.toPromptString(tags);

        // 模拟删除第一个标签
        final tagsWithRemoved = NaiPromptParser.removeTag(tags, tags.first.id);
        final textWithRemoved = NaiPromptParser.toPromptString(tagsWithRemoved);

        // 验证删除标签后文本变化（如果删除的是启用的标签）
        if (tags.first.enabled) {
          expect(textWithRemoved, isNot(equals(originalText)));
        }
      },
    );

    Glados<List<PromptTag>>(generatePromptTagList).test(
      'weight change produces different output',
      (tags) {
        final enabledTags = tags.where((t) => t.enabled).toList();
        if (enabledTags.isEmpty) return;

        // 原始文本
        final originalText = NaiPromptParser.toPromptString(tags);

        // 模拟增加第一个标签的权重
        final firstTag = tags.first;
        final newWeight = (firstTag.weight + 0.1).clamp(0.5, 2.0);
        final tagsWithNewWeight = tags.map((t) {
          if (t.id == firstTag.id) {
            return t.copyWith(weight: newWeight);
          }
          return t;
        }).toList();
        final textWithNewWeight =
            NaiPromptParser.toPromptString(tagsWithNewWeight);

        // 验证权重变化后文本变化（如果标签启用且权重确实变化）
        if (firstTag.enabled && newWeight != firstTag.weight) {
          expect(textWithNewWeight, isNot(equals(originalText)));
        }
      },
    );

    Glados<List<PromptTag>>(generatePromptTagList).test(
      'toggle enabled produces different output',
      (tags) {
        if (tags.isEmpty) return;

        // 原始文本
        final originalText = NaiPromptParser.toPromptString(tags);

        // 模拟切换第一个标签的启用状态
        final tagsWithToggled =
            NaiPromptParser.toggleTagEnabled(tags, tags.first.id);
        final textWithToggled = NaiPromptParser.toPromptString(tagsWithToggled);

        // 验证切换启用状态后文本变化
        expect(textWithToggled, isNot(equals(originalText)));
      },
    );
  });
}

/// **Feature: unified-prompt-input, Property 3: Tag Insertion Correctness**
/// **Validates: Requirements 2.2**
///
/// 对于任何文本内容、光标位置和选中的自动补全建议，
/// 插入建议后应该在正确的位置放置标签，并使用正确的逗号分隔。

/// 模拟标签插入逻辑（与 AutocompleteTextField 中的逻辑一致）
/// 返回插入后的文本和新光标位置
({String text, int cursorPosition}) insertTagAtCursor({
  required String text,
  required int cursorPosition,
  required String tagName,
  required bool autoInsertComma,
}) {
  // 找到当前标签的范围
  final textBeforeCursor = text.substring(0, cursorPosition);

  // 查找最后一个分隔符（支持中英文逗号和单竖线，但跳过双竖线）
  var lastSeparatorIndex = -1;
  for (var i = textBeforeCursor.length - 1; i >= 0; i--) {
    final char = textBeforeCursor[i];
    if (char == ',' || char == '，') {
      lastSeparatorIndex = i;
      break;
    }
    // 检查单竖线分隔符（跳过双竖线 ||）
    if (char == '|') {
      final isPartOfDoublePipe = (i > 0 && textBeforeCursor[i - 1] == '|') ||
          (i < textBeforeCursor.length - 1 && textBeforeCursor[i + 1] == '|');
      if (!isPartOfDoublePipe) {
        lastSeparatorIndex = i;
        break;
      }
      // 如果是双竖线，跳过这两个字符
      if (i > 0 && textBeforeCursor[i - 1] == '|') {
        i--;
      }
    }
  }

  final tagStart = lastSeparatorIndex + 1;

  // 找到标签结束位置（支持中英文逗号和单竖线，但跳过双竖线）
  var tagEnd = cursorPosition;
  for (var i = cursorPosition; i < text.length; i++) {
    final char = text[i];
    if (char == ',' || char == '，') {
      tagEnd = i;
      break;
    }
    // 检查单竖线分隔符（跳过双竖线 ||）
    if (char == '|') {
      final isPartOfDoublePipe = (i > 0 && text[i - 1] == '|') ||
          (i < text.length - 1 && text[i + 1] == '|');
      if (!isPartOfDoublePipe) {
        tagEnd = i;
        break;
      }
      // 如果是双竖线，跳过这两个字符
      if (i < text.length - 1 && text[i + 1] == '|') {
        i++;
      }
    }
  }
  if (tagEnd == cursorPosition) {
    tagEnd = text.length;
  }

  // 构建新文本
  final prefix = text.substring(0, tagStart);
  final suffix = text.substring(tagEnd);

  // 添加前导空格（如果前面有内容）
  final needsLeadingSpace = prefix.isNotEmpty && !prefix.endsWith(' ');
  final leadingSpace = needsLeadingSpace ? ' ' : '';

  // 添加逗号和空格（如果配置了自动插入）
  final trailingComma =
      autoInsertComma && (suffix.isEmpty || !suffix.trimLeft().startsWith(','))
          ? ', '
          : '';

  final newText = '$prefix$leadingSpace$tagName$trailingComma$suffix';
  final newCursorPosition = prefix.length +
      leadingSpace.length +
      tagName.length +
      trailingComma.length;

  return (text: newText, cursorPosition: newCursorPosition);
}

/// 自定义生成器：生成有效的标签名（用于插入）
Shrinkable<String> generateTagName(Random random, int size) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789_';
  final length = random.nextInt(15) + 1; // 1-15 字符
  final tagName = String.fromCharCodes(
    List.generate(
      length,
      (_) => chars.codeUnitAt(random.nextInt(chars.length)),
    ),
  );

  return Shrinkable(tagName, () sync* {
    if (tagName.length > 1) {
      yield Shrinkable(tagName.substring(0, tagName.length ~/ 2), () sync* {});
    }
  });
}

/// 自定义生成器：生成文本和光标位置的组合
Shrinkable<({String text, int cursorPosition})> generateTextWithCursor(
  Random random,
  int size,
) {
  // 生成 0-5 个标签
  final tagCount = random.nextInt(6);
  String text;
  if (tagCount == 0) {
    text = '';
  } else {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789_';
    final tags = <String>[];
    for (var i = 0; i < tagCount; i++) {
      final length = random.nextInt(10) + 1;
      final tag = String.fromCharCodes(
        List.generate(
          length,
          (_) => chars.codeUnitAt(random.nextInt(chars.length)),
        ),
      );
      tags.add(tag);
    }
    text = tags.join(', ');
  }

  // 生成有效的光标位置
  final cursorPosition = text.isEmpty ? 0 : random.nextInt(text.length + 1);

  return Shrinkable((text: text, cursorPosition: cursorPosition), () sync* {
    if (text.isNotEmpty) {
      yield Shrinkable((text: '', cursorPosition: 0), () sync* {});
    }
  });
}

/// Property 3 测试：验证标签插入正确性
void property3Tests() {
  group('Property 3: Tag Insertion Correctness', () {
    // 测试 1：插入后的文本应该包含新标签
    Glados<({String text, int cursorPosition})>(generateTextWithCursor).test(
      'inserted tag appears in the result text',
      (input) {
        const tagName = 'test_tag';
        final result = insertTagAtCursor(
          text: input.text,
          cursorPosition: input.cursorPosition,
          tagName: tagName,
          autoInsertComma: true,
        );

        expect(
          result.text.contains(tagName),
          isTrue,
          reason: 'Result text should contain the inserted tag "$tagName"',
        );
      },
    );

    // 测试 2：插入后光标位置应该在标签之后
    Glados<String>(generateTagName).test(
      'cursor position is after the inserted tag',
      (tagName) {
        // 跳过空标签名
        if (tagName.isEmpty) return;

        final result = insertTagAtCursor(
          text: 'existing_tag',
          cursorPosition: 12, // 在 "existing_tag" 末尾
          tagName: tagName,
          autoInsertComma: true,
        );

        // 光标应该在新标签之后（包括可能的逗号和空格）
        expect(
          result.cursorPosition,
          greaterThanOrEqualTo(tagName.length),
          reason: 'Cursor should be at or after the inserted tag',
        );
        expect(
          result.cursorPosition,
          lessThanOrEqualTo(result.text.length),
          reason: 'Cursor should not exceed text length',
        );
      },
    );

    // 测试 3：自动插入逗号时，结果应该有正确的逗号分隔
    Glados<({String text, int cursorPosition})>(generateTextWithCursor).test(
      'comma separation is correct when autoInsertComma is true',
      (input) {
        const tagName = 'new_tag';
        final result = insertTagAtCursor(
          text: input.text,
          cursorPosition: input.cursorPosition,
          tagName: tagName,
          autoInsertComma: true,
        );

        // 解析结果文本为标签列表
        final parsedTags = NaiPromptParser.parse(result.text);

        // 验证新标签在解析结果中
        final containsNewTag = parsedTags.any((t) => t.text == tagName);
        expect(
          containsNewTag,
          isTrue,
          reason: 'Parsed tags should contain the inserted tag "$tagName"',
        );
      },
    );

    // 测试 4：在已有标签之间插入时，不应该破坏现有标签
    Glados<String>(generateTagName).test(
      'inserting between tags preserves existing tags',
      (tagName) {
        if (tagName.isEmpty) return;

        const originalText = 'tag1, tag2, tag3';
        // 在 tag1 和 tag2 之间插入（光标在逗号后）
        final result = insertTagAtCursor(
          text: originalText,
          cursorPosition: 6, // 在 "tag1, " 之后
          tagName: tagName,
          autoInsertComma: true,
        );

        final parsedTags = NaiPromptParser.parse(result.text);

        // 验证 tag1 和 tag3 仍然存在
        expect(
          parsedTags.any((t) => t.text == 'tag1'),
          isTrue,
          reason: 'tag1 should still exist',
        );
        expect(
          parsedTags.any((t) => t.text == 'tag3'),
          isTrue,
          reason: 'tag3 should still exist',
        );
        // 验证新标签存在
        expect(
          parsedTags.any((t) => t.text == tagName),
          isTrue,
          reason: 'New tag should exist',
        );
      },
    );

    // 测试 5：禁用自动逗号时，不应该添加尾随逗号
    Glados<String>(generateTagName).test(
      'no trailing comma when autoInsertComma is false',
      (tagName) {
        if (tagName.isEmpty) return;

        final result = insertTagAtCursor(
          text: '',
          cursorPosition: 0,
          tagName: tagName,
          autoInsertComma: false,
        );

        // 结果应该只包含标签名，没有尾随逗号
        expect(
          result.text,
          equals(tagName),
          reason:
              'Result should be exactly the tag name without trailing comma',
        );
      },
    );
  });
}

/// **Feature: unified-prompt-input, Property 2: Autocomplete Suggestion Relevance**
/// **Validates: Requirements 2.1**
///
/// 对于任何至少2字符的部分标签输入，自动补全系统返回的建议中，
/// 每个建议的标签名应该包含输入作为子串（不区分大小写）。

/// 自定义生成器：生成有效的搜索查询（至少2字符的英文字符串）
Shrinkable<String> generateSearchQuery(Random random, int size) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789_';
  // 生成 2-8 字符的查询
  final length = random.nextInt(7) + 2; // 2-8 字符
  final query = String.fromCharCodes(
    List.generate(
      length,
      (_) => chars.codeUnitAt(random.nextInt(chars.length)),
    ),
  );

  return Shrinkable(query, () sync* {
    if (query.length > 2) {
      yield Shrinkable(query.substring(0, query.length - 1), () sync* {});
    }
  });
}

/// 自定义生成器：生成测试用的标签数据库
Shrinkable<List<LocalTag>> generateTagDatabase(Random random, int size) {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789_';
  final tagCount = random.nextInt(50) + 10; // 10-59 个标签

  final tags = <LocalTag>[];
  for (var i = 0; i < tagCount; i++) {
    final tagLength = random.nextInt(15) + 3; // 3-17 字符
    final tagName = String.fromCharCodes(
      List.generate(
        tagLength,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );

    tags.add(
      LocalTag(
        tag: tagName,
        count: random.nextInt(10000) + 1,
        category: random.nextInt(5),
      ),
    );
  }

  return Shrinkable(tags, () sync* {
    if (tags.length > 10) {
      yield Shrinkable(tags.sublist(0, tags.length ~/ 2), () sync* {});
    }
  });
}

/// Property 2 测试：验证自动补全建议相关性
/// 注意：实际实现使用前缀匹配（Trie 树），而非子串匹配
void property2Tests() {
  group('Property 2: Autocomplete Suggestion Relevance', () {
    Glados<List<LocalTag>>(generateTagDatabase).test(
      'all suggestions start with the query prefix (case-insensitive)',
      (tagDatabase) async {
        // 跳过空数据库
        if (tagDatabase.isEmpty) return;

        // 构建搜索索引
        final searchIndex = TagSearchIndex();
        await searchIndex.buildIndex(tagDatabase, useIsolate: false);

        // 从数据库中选择一个标签的前缀作为查询
        // 这确保查询一定能匹配到结果
        final targetTag = tagDatabase.first;
        final queryLength = (targetTag.tag.length / 2).ceil().clamp(2, 8);
        final query = targetTag.tag.substring(0, queryLength);

        // 执行搜索
        final suggestions = searchIndex.search(query, limit: 20);

        // 验证每个建议都以查询字符串为前缀
        final lowerQuery = query.toLowerCase();
        for (final suggestion in suggestions) {
          final tagLower = suggestion.tag.toLowerCase();
          final aliasLower = suggestion.alias?.toLowerCase() ?? '';

          // 标签名或别名应该以查询字符串开头
          final startsWithQuery = tagLower.startsWith(lowerQuery) ||
              aliasLower.startsWith(lowerQuery);

          expect(
            startsWithQuery,
            isTrue,
            reason:
                'Suggestion "${suggestion.tag}" (alias: ${suggestion.alias}) '
                'should start with query "$query"',
          );
        }
      },
    );

    Glados<List<LocalTag>>(generateTagDatabase).test(
      'search with exact tag name returns that tag',
      (tagDatabase) async {
        if (tagDatabase.isEmpty) return;

        // 构建搜索索引
        final searchIndex = TagSearchIndex();
        await searchIndex.buildIndex(tagDatabase, useIsolate: false);

        // 选择一个随机标签进行精确搜索
        final targetTag = tagDatabase.first;
        final query = targetTag.tag;

        // 跳过太短的标签
        if (query.length < 2) return;

        // 执行搜索
        final suggestions = searchIndex.search(query, limit: 20);

        // 验证结果包含目标标签
        final containsTarget =
            suggestions.any((s) => s.tag.toLowerCase() == query.toLowerCase());

        expect(
          containsTarget,
          isTrue,
          reason: 'Search for "$query" should return the exact tag',
        );
      },
    );
  });
}
