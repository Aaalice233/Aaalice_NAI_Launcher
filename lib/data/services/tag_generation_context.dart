import 'dart:math';

import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/character/character_prompt.dart';
import '../models/prompt/category_filter_config.dart';
import '../models/prompt/random_prompt_result.dart';

part 'tag_generation_context.freezed.dart';
part 'tag_generation_context.g.dart';

/// 标签生成上下文
///
/// 用于跟踪随机提示词生成过程中的状态。
/// 从 RandomPromptGenerator 中提取的状态管理模型。
///
/// 主要职责：
/// - 维护生成过程中的状态（角色数量、性别等）
/// - 提供不可变的状态更新方法
/// - 支持条件过滤的上下文跟踪
/// - 保证状态的可序列化和可重现性
///
/// ## 设计模式
///
/// 使用 Freezed 模式实现不可变状态：
/// - 所有修改返回新实例
/// - 原始实例保持不变
/// - 支持值比较和序列化
///
/// ## 线程安全性
///
/// - 不可变设计，天然线程安全
/// - 可以在多个 Isolate 间安全传递
/// - Random 实例通过 seed 创建，避免状态共享
///
/// ## 使用示例
///
/// ```dart
/// // 创建初始上下文
/// final context = TagGenerationContext.create(
///   seed: 42,
///   isV4Model: true,
/// );
///
/// // 更新状态（返回新实例）
/// final updated = context
///   .setCharacterCount(2)
///   .addGender(CharacterGender.female)
///   .addTag('blonde hair');
///
/// // 创建可重现的 Random 实例
/// final random = context.createRandom();
/// ```
@freezed
class TagGenerationContext with _$TagGenerationContext {
  const TagGenerationContext._();

  const factory TagGenerationContext({
    /// 随机种子（可选，用于结果复现）
    int? seed,

    /// 是否为 V4+ 模型（支持多角色）
    @Default(true) bool isV4Model,

    /// 分类级 Danbooru 补充配置
    @Default(CategoryFilterConfig()) CategoryFilterConfig filterConfig,

    /// 角色数量
    @Default(0) int characterCount,

    /// 角色性别列表
    @Default([]) List<CharacterGender> genders,

    /// 已生成的角色列表
    @Default([]) List<GeneratedCharacter> generatedCharacters,

    /// 当前累积的标签（主提示词）
    @Default([]) List<String> currentTags,

    /// 当前上下文标签（用于条件过滤）
    /// 例如：['male', 'solo'] 用于过滤仅适用于男性单人场景的标签
    @Default([]) List<String> contextTags,

    /// 当前正在生成的角色索引（0-based）
    /// 用于跟踪多角色生成进度
    @Default(0) int currentCharacterIndex,

    /// 是否为无人物场景
    @Default(false) bool isNoHumans,
  }) = _TagGenerationContext;

  factory TagGenerationContext.fromJson(Map<String, dynamic> json) =>
      _$TagGenerationContextFromJson(json);

  /// 创建初始上下文
  ///
  /// 使用指定的种子创建初始生成上下文。
  /// 如果提供了种子，可以使用它创建可重现的 Random 实例。
  ///
  /// [seed] 随机种子（可选）
  /// [isV4Model] 是否为 V4+ 模式
  /// [filterConfig] 分类过滤配置
  ///
  /// 返回新的 TagGenerationContext 实例
  ///
  /// 示例：
  /// ```dart
  /// final context = TagGenerationContext.create(
  ///   seed: 42,
  ///   isV4Model: true,
  /// );
  /// // 使用时创建 Random 实例：
  /// final random = context.seed != null ? Random(context.seed!) : Random();
  /// ```
  factory TagGenerationContext.create({
    int? seed,
    bool isV4Model = true,
    CategoryFilterConfig filterConfig = const CategoryFilterConfig(),
  }) {
    return TagGenerationContext(
      seed: seed,
      isV4Model: isV4Model,
      filterConfig: filterConfig,
    );
  }

  /// 创建 Random 实例
  ///
  /// 根据上下文的 seed 创建 Random 实例，保证可重现性。
  ///
  /// 返回 Random 实例
  ///
  /// 示例：
  /// ```dart
  /// final random = context.createRandom();
  /// final selected = random.nextInt(100);
  /// ```
  Random createRandom() {
    return seed != null ? Random(seed!) : Random();
  }

  /// 添加标签到当前标签列表
  ///
  /// 向主提示词中添加新标签，返回更新后的上下文。
  ///
  /// [tag] 要添加的标签
  ///
  /// 返回更新后的上下文
  ///
  /// 示例：
  /// ```dart
  /// final updated = context.addTag('blonde hair');
  /// ```
  TagGenerationContext addTag(String tag) {
    return copyWith(currentTags: [...currentTags, tag]);
  }

  /// 批量添加标签
  ///
  /// 向主提示词中批量添加标签。
  ///
  /// [tags] 要添加的标签列表
  ///
  /// 返回更新后的上下文
  ///
  /// 示例：
  /// ```dart
  /// final updated = context.addTags(['blonde hair', 'blue eyes']);
  /// ```
  TagGenerationContext addTags(List<String> tags) {
    return copyWith(currentTags: [...currentTags, ...tags]);
  }

  /// 添加上下文标签
  ///
  /// 添加用于条件过滤的上下文标签。
  ///
  /// [contextTag] 上下文标签
  ///
  /// 返回更新后的上下文
  ///
  /// 示例：
  /// ```dart
  /// final updated = context.addContextTag('male');
  /// ```
  TagGenerationContext addContextTag(String contextTag) {
    return copyWith(contextTags: [...contextTags, contextTag]);
  }

  /// 批量添加上下文标签
  ///
  /// [tags] 上下文标签列表
  ///
  /// 返回更新后的上下文
  TagGenerationContext addContextTags(List<String> tags) {
    return copyWith(contextTags: [...contextTags, ...tags]);
  }

  /// 设置角色数量
  ///
  /// [count] 角色数量
  ///
  /// 返回更新后的上下文
  ///
  /// 示例：
  /// ```dart
  /// final updated = context.setCharacterCount(2);
  /// ```
  TagGenerationContext setCharacterCount(int count) {
    return copyWith(characterCount: count);
  }

  /// 添加角色性别
  ///
  /// [gender] 角色性别
  ///
  /// 返回更新后的上下文
  ///
  /// 示例：
  /// ```dart
  /// final updated = context.addGender(CharacterGender.female);
  /// ```
  TagGenerationContext addGender(CharacterGender gender) {
    return copyWith(genders: [...genders, gender]);
  }

  /// 批量设置角色性别
  ///
  /// [newGenders] 性别列表
  ///
  /// 返回更新后的上下文
  TagGenerationContext setGenders(List<CharacterGender> newGenders) {
    return copyWith(genders: newGenders);
  }

  /// 添加已生成的角色
  ///
  /// [character] 生成的角色
  ///
  /// 返回更新后的上下文
  ///
  /// 示例：
  /// ```dart
  /// final character = GeneratedCharacter.female('blonde hair, blue eyes');
  /// final updated = context.addCharacter(character);
  /// ```
  TagGenerationContext addCharacter(GeneratedCharacter character) {
    return copyWith(
      generatedCharacters: [...generatedCharacters, character],
      currentCharacterIndex: generatedCharacters.length + 1,
    );
  }

  /// 设置当前角色索引
  ///
  /// [index] 角色索引
  ///
  /// 返回更新后的上下文
  TagGenerationContext setCurrentCharacterIndex(int index) {
    return copyWith(currentCharacterIndex: index);
  }

  /// 设置为无人物场景
  ///
  /// 返回更新后的上下文
  ///
  /// 示例：
  /// ```dart
  /// final updated = context.setNoHumans();
  /// ```
  TagGenerationContext setNoHumans() {
    return copyWith(
      isNoHumans: true,
      characterCount: 0,
    );
  }

  /// 更新过滤配置
  ///
  /// [config] 新的过滤配置
  ///
  /// 返回更新后的上下文
  TagGenerationContext updateFilterConfig(CategoryFilterConfig config) {
    return copyWith(filterConfig: config);
  }

  /// 检查是否完成所有角色生成
  ///
  /// 返回是否已生成所有角色
  ///
  /// 示例：
  /// ```dart
  /// if (context.isCharacterGenerationComplete) {
  ///   // 继续生成背景和场景
  /// }
  /// ```
  bool get isCharacterGenerationComplete {
    return characterCount == 0 || generatedCharacters.length == characterCount;
  }

  /// 获取当前正在生成的角色
  ///
  /// 返回当前角色，如果不存在则返回 null
  GeneratedCharacter? get currentCharacter {
    if (currentCharacterIndex < generatedCharacters.length) {
      return generatedCharacters[currentCharacterIndex];
    }
    return null;
  }

  /// 获取当前角色的性别
  ///
  /// 返回当前角色的性别，如果不存在则返回 null
  CharacterGender? get currentGender {
    if (currentCharacterIndex < genders.length) {
      return genders[currentCharacterIndex];
    }
    return null;
  }

  /// 是否为单人场景
  bool get isSolo => characterCount == 1;

  /// 是否为多人场景
  bool get isMultipleCharacters => characterCount > 1;

  /// 是否为女性角色
  bool get isFemaleOnly =>
      genders.isNotEmpty &&
      genders.every((g) => g == CharacterGender.female);

  /// 是否为男性角色
  bool get isMaleOnly =>
      genders.isNotEmpty && genders.every((g) => g == CharacterGender.male);

  /// 获取主提示词字符串
  ///
  /// 将当前标签列表合并为逗号分隔的字符串。
  ///
  /// 返回主提示词字符串
  ///
  /// 示例：
  /// ```dart
  /// final prompt = context.mainPrompt;
  /// // "blonde hair, blue eyes, smile"
  /// ```
  String get mainPrompt {
    return currentTags.join(', ');
  }

  /// 创建 RandomPromptResult
  ///
  /// 将当前上下文转换为最终结果。
  ///
  /// 返回生成的随机提示词结果
  ///
  /// 示例：
  /// ```dart
  /// final result = context.toResult();
  /// ```
  RandomPromptResult toResult() {
    if (isNoHumans) {
      return RandomPromptResult.noHuman(
        prompt: mainPrompt,
        seed: seed,
      );
    }

    if (generatedCharacters.isEmpty) {
      return RandomPromptResult(
        mainPrompt: mainPrompt,
        seed: seed,
      );
    }

    return RandomPromptResult.multiCharacter(
      mainPrompt: mainPrompt,
      characters: generatedCharacters,
      seed: seed,
    );
  }

  /// 重置当前标签（保留其他状态）
  ///
  /// 清空当前累积的标签，用于开始新的标签生成阶段。
  ///
  /// 返回更新后的上下文
  TagGenerationContext resetTags() {
    return copyWith(currentTags: []);
  }

  /// 重置上下文标签（保留其他状态）
  ///
  /// 清空条件过滤的上下文标签。
  ///
  /// 返回更新后的上下文
  TagGenerationContext resetContextTags() {
    return copyWith(contextTags: []);
  }

  /// 创建副本并更新种子
  ///
  /// 用于需要独立随机数序列的场景。
  ///
  /// [newSeed] 新的种子（可选）
  ///
  /// 返回新的上下文副本，带有新的种子
  TagGenerationContext withSeed(int? newSeed) {
    return copyWith(seed: newSeed);
  }

  /// 验证上下文状态是否有效
  ///
  /// 检查上下文状态是否一致和有效。
  ///
  /// 返回是否有效
  ///
  /// 示例：
  /// ```dart
  /// if (!context.isValid) {
  ///   throw StateError('Invalid context state');
  /// }
  /// ```
  bool get isValid {
    // 无人物场景
    if (isNoHumans) {
      return characterCount == 0 && generatedCharacters.isEmpty;
    }

    // 有角色场景
    if (characterCount > 0) {
      // 检查生成的角色数量是否匹配
      if (generatedCharacters.length > characterCount) {
        return false;
      }
      // 检查性别列表长度是否匹配
      if (genders.length > characterCount) {
        return false;
      }
    }

    return true;
  }

  /// 获取生成进度信息
  ///
  /// 返回生成进度的描述性字符串
  ///
  /// 示例：
  /// ```dart
  /// print(context.progressInfo);
  /// // "Characters: 2/3, Tags: 15"
  /// ```
  String get progressInfo {
    if (isNoHumans) {
      return 'No humans, Tags: ${currentTags.length}';
    }
    if (characterCount > 0) {
      return 'Characters: ${generatedCharacters.length}/$characterCount, Tags: ${currentTags.length}';
    }
    return 'Tags: ${currentTags.length}';
  }
}
