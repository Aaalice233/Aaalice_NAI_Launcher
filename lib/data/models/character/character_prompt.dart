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

/// 角色位置 (百分比坐标)
@freezed
class CharacterPosition with _$CharacterPosition {
  const CharacterPosition._();

  const factory CharacterPosition({
    /// 位置模式
    @Default(CharacterPositionMode.aiChoice) CharacterPositionMode mode,

    /// 行位置 (0.0-1.0 百分比)
    @Default(0.5) double row,

    /// 列位置 (0.0-1.0 百分比)
    @Default(0.5) double column,
  }) = _CharacterPosition;

  factory CharacterPosition.fromJson(Map<String, dynamic> json) =>
      _$CharacterPositionFromJson(json);

  /// 转换为NAI位置字符串 (如 "A1", "B2")
  /// 将百分比坐标转换为5x5网格索引
  String toNaiString() {
    final colIndex = (column * 4).round().clamp(0, 4);
    final rowIndex = (row * 4).round().clamp(0, 4);
    final colChar = String.fromCharCode('A'.codeUnitAt(0) + colIndex);
    final rowNum = rowIndex + 1;
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

    /// 缩略图路径（词库导入时保存）
    String? thumbnailPath,
  }) = _CharacterPrompt;

  factory CharacterPrompt.fromJson(Map<String, dynamic> json) =>
      _$CharacterPromptFromJson(json);

  /// 创建新角色
  factory CharacterPrompt.create({
    required String name,
    CharacterGender gender = CharacterGender.female,
    String prompt = '',
    String negativePrompt = 'lowres, aliasing, ',
    CharacterPositionMode positionMode = CharacterPositionMode.aiChoice,
    CharacterPosition? customPosition,
    String? thumbnailPath,
  }) {
    return CharacterPrompt(
      id: const Uuid().v4(),
      name: name,
      gender: gender,
      prompt: prompt,
      negativePrompt: negativePrompt,
      positionMode: positionMode,
      customPosition: customPosition,
      thumbnailPath: thumbnailPath,
    );
  }

  /// 生成NAI格式的角色提示词
  /// [useAiPosition] 是否使用AI选择位置（全局设置）
  String toNaiPrompt({bool useAiPosition = false}) {
    if (!enabled || prompt.isEmpty) return '';

    final buffer = StringBuffer();
    buffer.write('[');

    // 添加性别提示词
    final genderTag = _getGenderTag();
    if (genderTag.isNotEmpty) {
      buffer.write(genderTag);
      buffer.write(', ');
    }

    buffer.write(prompt);

    // 处理位置：全局AI选择时不添加位置，否则使用自定义位置
    if (!useAiPosition && customPosition != null) {
      buffer.write(', position: ');
      buffer.write(customPosition!.toNaiString());
    }

    buffer.write(']');
    return buffer.toString();
  }

  /// 根据性别返回对应的提示词标签
  String _getGenderTag() {
    switch (gender) {
      case CharacterGender.female:
        return '1girl';
      case CharacterGender.male:
        return '1boy';
      case CharacterGender.other:
        return '';
    }
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
    @Default(true) bool globalAiChoice,
  }) = _CharacterPromptConfig;

  factory CharacterPromptConfig.fromJson(Map<String, dynamic> json) =>
      _$CharacterPromptConfigFromJson(json);

  /// 生成NAI格式的多角色提示词
  String toNaiPrompt() {
    final enabledCharacters =
        characters.where((c) => c.enabled && c.prompt.isNotEmpty);
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

  /// 预定义的默认位置列表（分散在5x5网格中，尽量不重合）
  static const List<CharacterPosition> _defaultPositions = [
    CharacterPosition(row: 2, column: 2), // C3 - 中心
    CharacterPosition(row: 1, column: 1), // B2 - 左上
    CharacterPosition(row: 1, column: 3), // D2 - 右上
    CharacterPosition(row: 3, column: 1), // B4 - 左下
    CharacterPosition(row: 3, column: 3), // D4 - 右下
    CharacterPosition(row: 2, column: 0), // A3 - 最左
  ];

  /// 获取下一个可用的默认位置
  CharacterPosition _getNextDefaultPosition() {
    // 收集已使用的位置
    final usedPositions = characters
        .where((c) => c.customPosition != null)
        .map((c) => c.customPosition!)
        .toList();

    // 从预定义位置中找一个未使用的
    for (final pos in _defaultPositions) {
      final isUsed = usedPositions.any(
        (used) => used.row == pos.row && used.column == pos.column,
      );
      if (!isUsed) {
        return pos;
      }
    }

    // 如果预定义位置都用完了，找一个未使用的网格位置
    for (int row = 0; row < 5; row++) {
      for (int col = 0; col < 5; col++) {
        final rowPercent = row / 4.0;
        final colPercent = col / 4.0;
        final isUsed = usedPositions.any(
          (used) =>
              (used.row * 4).round() == row && (used.column * 4).round() == col,
        );
        if (!isUsed) {
          return CharacterPosition(row: rowPercent, column: colPercent);
        }
      }
    }

    // 兜底：返回中心位置
    return const CharacterPosition(row: 0.5, column: 0.5);
  }

  /// 添加新角色
  CharacterPromptConfig addCharacter({
    String? name,
    CharacterGender gender = CharacterGender.female,
    String? prompt,
    String? thumbnailPath,
  }) {
    // 根据性别设置初始提示词（如果未指定）
    final initialPrompt = prompt ??
        switch (gender) {
          CharacterGender.female => 'girl, ',
          CharacterGender.male => 'boy, ',
          CharacterGender.other => '',
        };

    // 获取默认位置
    final defaultPosition = _getNextDefaultPosition();

    final newCharacter = CharacterPrompt.create(
      name: name ?? getNextCharacterName(),
      gender: gender,
      prompt: initialPrompt,
      positionMode: CharacterPositionMode.custom,
      customPosition: defaultPosition,
      thumbnailPath: thumbnailPath,
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
      characters:
          characters.map((c) => c.id == character.id ? character : c).toList(),
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
