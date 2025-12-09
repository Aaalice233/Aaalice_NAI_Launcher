import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

part 'character_prompt.freezed.dart';
part 'character_prompt.g.dart';

/// 角色性别
enum CharacterGender {
  @JsonValue('female')
  female,
  @JsonValue('male')
  male,
  @JsonValue('other')
  other,
}

/// 角色位置模式
enum CharacterPositionMode {
  @JsonValue('aiChoice')
  aiChoice,
  @JsonValue('custom')
  custom,
}

/// 角色位置 (5x5网格)
@freezed
class CharacterPosition with _$CharacterPosition {
  const CharacterPosition._();

  const factory CharacterPosition({
    /// 行索引 (0-4)
    required int row,
    /// 列索引 (0-4)
    required int column,
  }) = _CharacterPosition;

  factory CharacterPosition.fromJson(Map<String, dynamic> json) =>
      _$CharacterPositionFromJson(json);

  /// 转换为NAI位置字符串 (如 "A1", "B2")
  String toNaiString() {
    final colChar = String.fromCharCode('A'.codeUnitAt(0) + column);
    final rowNum = row + 1;
    return '$colChar$rowNum';
  }
}


/// 单个角色提示词模型
@freezed
class CharacterPrompt with _$CharacterPrompt {
  const CharacterPrompt._();

  const factory CharacterPrompt({
    /// 唯一标识
    required String id,
    /// 角色名称
    required String name,
    /// 角色性别
    @Default(CharacterGender.female) CharacterGender gender,
    /// 正向提示词
    @Default('') String prompt,
    /// 负面提示词 (Undesired Content)
    @Default('') String negativePrompt,
    /// 位置模式
    @Default(CharacterPositionMode.aiChoice) CharacterPositionMode positionMode,
    /// 自定义位置 (仅当positionMode为custom时有效)
    CharacterPosition? customPosition,
    /// 是否启用
    @Default(true) bool enabled,
  }) = _CharacterPrompt;

  factory CharacterPrompt.fromJson(Map<String, dynamic> json) =>
      _$CharacterPromptFromJson(json);

  /// 创建新角色
  factory CharacterPrompt.create({
    required String name,
    CharacterGender gender = CharacterGender.female,
    String prompt = '',
    String negativePrompt = '',
    CharacterPositionMode positionMode = CharacterPositionMode.aiChoice,
    CharacterPosition? customPosition,
  }) {
    return CharacterPrompt(
      id: const Uuid().v4(),
      name: name,
      gender: gender,
      prompt: prompt,
      negativePrompt: negativePrompt,
      positionMode: positionMode,
      customPosition: customPosition,
    );
  }

  /// 生成NAI格式的角色提示词
  /// [useAiPosition] 是否强制使用AI选择位置（全局设置覆盖）
  String toNaiPrompt({bool useAiPosition = false}) {
    if (!enabled || prompt.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.write('[');
    buffer.write(prompt);

    // 处理位置
    final shouldUseCustomPosition =
        !useAiPosition && positionMode == CharacterPositionMode.custom && customPosition != null;

    if (shouldUseCustomPosition) {
      buffer.write(', position: ');
      buffer.write(customPosition!.toNaiString());
    }

    buffer.write(']');
    return buffer.toString();
  }
}


/// 多角色提示词配置
@freezed
class CharacterPromptConfig with _$CharacterPromptConfig {
  const CharacterPromptConfig._();

  const factory CharacterPromptConfig({
    /// 角色列表
    @Default([]) List<CharacterPrompt> characters,
    /// 全局AI选择位置（覆盖所有角色的位置设置）
    @Default(false) bool globalAiChoice,
  }) = _CharacterPromptConfig;

  factory CharacterPromptConfig.fromJson(Map<String, dynamic> json) =>
      _$CharacterPromptConfigFromJson(json);

  /// 生成NAI格式的多角色提示词
  String toNaiPrompt() {
    final enabledCharacters = characters.where((c) => c.enabled && c.prompt.isNotEmpty);
    if (enabledCharacters.isEmpty) return '';

    return enabledCharacters
        .map((c) => c.toNaiPrompt(useAiPosition: globalAiChoice))
        .where((s) => s.isNotEmpty)
        .join('\n');
  }

  /// 获取下一个角色的默认名称
  String getNextCharacterName() {
    return 'Character ${characters.length + 1}';
  }

  /// 添加新角色
  CharacterPromptConfig addCharacter({
    String? name,
    CharacterGender gender = CharacterGender.female,
  }) {
    final newCharacter = CharacterPrompt.create(
      name: name ?? getNextCharacterName(),
      gender: gender,
    );
    return copyWith(characters: [...characters, newCharacter]);
  }

  /// 移除角色
  CharacterPromptConfig removeCharacter(String id) {
    return copyWith(
      characters: characters.where((c) => c.id != id).toList(),
    );
  }

  /// 更新角色
  CharacterPromptConfig updateCharacter(CharacterPrompt character) {
    return copyWith(
      characters: characters.map((c) => c.id == character.id ? character : c).toList(),
    );
  }

  /// 重新排序角色
  CharacterPromptConfig reorderCharacters(int oldIndex, int newIndex) {
    final newList = List<CharacterPrompt>.from(characters);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = newList.removeAt(oldIndex);
    newList.insert(newIndex, item);
    return copyWith(characters: newList);
  }

  /// 清空所有角色
  CharacterPromptConfig clearAllCharacters() {
    return copyWith(characters: []);
  }

  /// 根据ID查找角色
  CharacterPrompt? findCharacterById(String id) {
    try {
      return characters.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }
}
