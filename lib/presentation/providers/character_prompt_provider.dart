import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/models/character/character_prompt.dart';
import '../../data/repositories/character_prompt_repository.dart';

part 'character_prompt_provider.g.dart';

/// 多角色提示词状态管理 Provider
///
/// 管理多角色提示词配置，包括添加、删除、更新、重排序等操作。
/// 数据自动持久化到本地存储。
///
/// Requirements: 1.4
@riverpod
class CharacterPromptNotifier extends _$CharacterPromptNotifier {
  late final CharacterPromptRepository _repository;

  @override
  CharacterPromptConfig build() {
    _repository = ref.read(characterPromptRepositoryProvider);
    // 同步加载配置（应用启动时 Hive box 已打开）
    return _repository.load();
  }

  /// 保存配置到本地存储
  Future<void> _saveConfig() async {
    await _repository.save(state);
  }

  /// 添加新角色
  ///
  /// [gender] 角色性别
  /// [name] 角色名称，为空时自动生成
  /// [prompt] 正向提示词，为空时根据性别生成默认值
  /// [thumbnailPath] 缩略图路径（词库导入时）
  ///
  /// Requirements: 1.2, 1.3
  void addCharacter(
    CharacterGender gender, {
    String? name,
    String? prompt,
    String? thumbnailPath,
  }) {
    state = state.addCharacter(
      gender: gender,
      name: name,
      prompt: prompt,
      thumbnailPath: thumbnailPath,
    );
    _saveConfig();
  }

  /// 移除角色
  ///
  /// [id] 要移除的角色ID
  ///
  /// Requirements: 4.2
  void removeCharacter(String id) {
    state = state.removeCharacter(id);
    _saveConfig();
  }

  /// 更新角色
  ///
  /// [character] 更新后的角色数据
  ///
  /// Requirements: 2.2, 2.3, 2.4, 2.5
  void updateCharacter(CharacterPrompt character) {
    state = state.updateCharacter(character);
    _saveConfig();
  }

  /// 重新排序角色
  ///
  /// [oldIndex] 原位置索引
  /// [newIndex] 新位置索引
  ///
  /// Requirements: 4.1, 4.3
  void reorderCharacters(int oldIndex, int newIndex) {
    state = state.reorderCharacters(oldIndex, newIndex);
    _saveConfig();
  }

  /// 设置全局AI选择位置
  ///
  /// [value] 是否启用全局AI选择
  ///
  /// Requirements: 3.4
  void setGlobalAiChoice(bool value) {
    state = state.copyWith(globalAiChoice: value);
    _saveConfig();
  }

  /// 清空所有角色
  ///
  /// Requirements: 4.4
  void clearAllCharacters() {
    state = state.clearAllCharacters();
    _saveConfig();
  }

  /// 清空所有角色（别名）
  void clearAll() => clearAllCharacters();

  /// 替换所有角色
  ///
  /// 用于随机生成时一次性设置所有角色
  void replaceAll(List<CharacterPrompt> characters) {
    state = CharacterPromptConfig(
      characters: characters,
      globalAiChoice: state.globalAiChoice,
    );
    _saveConfig();
  }

  /// 向上移动角色
  ///
  /// [index] 当前位置索引
  void moveCharacterUp(int index) {
    if (index > 0) {
      reorderCharacters(index, index - 1);
    }
  }

  /// 向下移动角色
  ///
  /// [index] 当前位置索引
  void moveCharacterDown(int index) {
    if (index < state.characters.length - 1) {
      reorderCharacters(index, index + 2);
    }
  }

  /// 切换角色启用状态
  ///
  /// [id] 角色ID
  void toggleCharacterEnabled(String id) {
    final character = state.findCharacterById(id);
    if (character != null) {
      updateCharacter(character.copyWith(enabled: !character.enabled));
    }
  }
}

/// 当前选中的角色ID Provider
///
/// 用于跟踪编辑器中当前选中的角色
///
/// Requirements: 2.1
@riverpod
class SelectedCharacterId extends _$SelectedCharacterId {
  @override
  String? build() => null;

  /// 选择角色
  void select(String? id) {
    state = id;
  }

  /// 清除选择
  void clear() {
    state = null;
  }
}

/// 便捷 Provider：获取角色列表
@riverpod
List<CharacterPrompt> characterList(Ref ref) {
  final config = ref.watch(characterPromptNotifierProvider);
  return config.characters;
}

/// 便捷 Provider：获取角色数量
@riverpod
int characterCount(Ref ref) {
  final config = ref.watch(characterPromptNotifierProvider);
  return config.characters.length;
}

/// 便捷 Provider：获取启用的角色数量
@riverpod
int enabledCharacterCount(Ref ref) {
  final config = ref.watch(characterPromptNotifierProvider);
  return config.characters.where((c) => c.enabled).length;
}

/// 便捷 Provider：获取当前选中的角色
@riverpod
CharacterPrompt? selectedCharacter(Ref ref) {
  final config = ref.watch(characterPromptNotifierProvider);
  final selectedId = ref.watch(selectedCharacterIdProvider);

  if (selectedId == null) return null;
  return config.findCharacterById(selectedId);
}

/// 便捷 Provider：获取全局AI选择状态
@riverpod
bool globalAiChoice(Ref ref) {
  final config = ref.watch(characterPromptNotifierProvider);
  return config.globalAiChoice;
}

/// 便捷 Provider：生成NAI格式提示词
@riverpod
String characterNaiPrompt(Ref ref) {
  final config = ref.watch(characterPromptNotifierProvider);
  return config.toNaiPrompt();
}

/// 便捷 Provider：检查是否有角色
@riverpod
bool hasCharacters(Ref ref) {
  final config = ref.watch(characterPromptNotifierProvider);
  return config.characters.isNotEmpty;
}
