import 'package:freezed_annotation/freezed_annotation.dart';

import '../../models/character/character_prompt.dart';

/// 标签性别限定
///
/// 用于限定类别/词组适用的角色性别
enum TagGender {
  /// 女性
  @JsonValue('female')
  female,

  /// 男性
  @JsonValue('male')
  male,

  /// 伪娘（生理男性，女性化外表）
  @JsonValue('trap')
  trap,

  /// 扶她（双性）
  @JsonValue('futanari')
  futanari,
}

/// TagGender 扩展方法
extension TagGenderExtension on TagGender {
  /// 获取显示名称的键（用于国际化）
  String get l10nKey => switch (this) {
        TagGender.female => 'gender_female',
        TagGender.male => 'gender_male',
        TagGender.trap => 'gender_trap',
        TagGender.futanari => 'gender_futanari',
      };

  /// 检查是否与 CharacterGender 兼容
  ///
  /// - female: 仅匹配 CharacterGender.female
  /// - male: 仅匹配 CharacterGender.male
  /// - trap: 匹配 CharacterGender.male（伪娘基于男性）
  /// - futanari: 匹配任何性别
  bool isCompatibleWith(CharacterGender gender) {
    return switch (this) {
      TagGender.female => gender == CharacterGender.female,
      TagGender.male => gender == CharacterGender.male,
      TagGender.trap => gender == CharacterGender.male,
      TagGender.futanari => true,
    };
  }

  /// 从 CharacterGender 推断 TagGender
  ///
  /// 注意：trap 和 futanari 需要额外信息，此方法仅做基础映射
  static TagGender fromCharacterGender(CharacterGender gender) {
    return switch (gender) {
      CharacterGender.female => TagGender.female,
      CharacterGender.male => TagGender.male,
      CharacterGender.other => TagGender.female, // 默认处理
    };
  }
}
