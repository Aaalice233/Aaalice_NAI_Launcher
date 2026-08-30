import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/model_capabilities.dart';
import '../../core/utils/app_logger.dart';
import '../../data/models/character/character_prompt.dart';
import '../../data/repositories/character_prompt_repository.dart';
import 'generation/generation_params_notifier.dart';

part 'character_prompt_provider.g.dart';

CharacterPromptConfig limitCharacterConfigForModel(
  CharacterPromptConfig config,
  String model,
) {
  final limit = ModelCapabilityRegistry.of(model).maxCharacters;
  final limited = limit > 0 && config.characters.length > limit
      ? config.copyWith(characters: config.characters.take(limit).toList())
      : config;
  return limited.normalizeCustomPositions();
}

/// 多角色提示词状态管理 Provider
///
/// 管理多角色提示词配置，包括添加、删除、更新、重排序等操作。
/// 数据自动持久化到本地存储。
///
/// Requirements: 1.4
@Riverpod(keepAlive: true)
class CharacterPromptNotifier extends _$CharacterPromptNotifier {
  late final CharacterPromptRepository _repository;
  Future<void> _saveTail = Future<void>.value();

  @override
  CharacterPromptConfig build() {
    _repository = ref.read(characterPromptRepositoryProvider);
    // 同步加载配置（应用启动时 Hive box 已打开）
    final loaded = _repository.load();
    final normalized = loaded.normalizeCustomPositions();
    if (normalized != loaded) {
      unawaited(_saveSnapshot(normalized));
    }
    return normalized;
  }

  Future<bool> _saveSnapshot(CharacterPromptConfig snapshot) {
    final operation = _saveTail.then((_) => _repository.save(snapshot));
    _saveTail = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace __) {},
    );
    return operation;
  }

  /// 保存按调用顺序串行落盘，避免较旧快照在较新快照之后完成。
  Future<bool> _saveConfig() => _saveSnapshot(state);

  /// Agent 入口使用可等待的原子修改，避免先报告成功再异步写盘失败。
  Future<bool> updateCharacterPersisted(CharacterPrompt character) {
    state = state.updateCharacter(character).normalizeCustomPositions();
    return _saveConfig();
  }

  Future<bool> removeCharacterPersisted(String id) {
    state = state.removeCharacter(id);
    return _saveConfig();
  }

  Future<bool> clearAllCharactersPersisted() {
    state = state.clearAllCharacters();
    return _saveConfig();
  }

  Future<bool> setGlobalAiChoicePersisted(bool value) {
    var newState = state.copyWith(globalAiChoice: value);
    if (!value) newState = newState.normalizeCustomPositions();
    state = newState;
    return _saveConfig();
  }

  Future<bool> setCharacterOrderPersisted(List<String> orderedIds) {
    final currentById = {
      for (final character in state.characters) character.id: character,
    };
    if (orderedIds.length != currentById.length ||
        orderedIds.toSet().length != orderedIds.length ||
        !orderedIds.every(currentById.containsKey)) {
      throw const FormatException(
        'orderedIds must contain every current character ID exactly once',
      );
    }
    state = state.copyWith(
      characters: [for (final id in orderedIds) currentById[id]!],
    );
    return _saveConfig();
  }

  Future<({CharacterPrompt character, bool persisted})?> addCharacterPersisted(
    CharacterGender gender, {
    required String name,
    required String prompt,
    String? negativePrompt,
    required bool enabled,
    required CharacterPositionMode positionMode,
    CharacterPosition? customPosition,
  }) async {
    if (isAtCharacterLimit || characterLimit == 0) return null;
    final existingIds = state.characters
        .map((character) => character.id)
        .toSet();
    state = state.addCharacter(
      gender: gender,
      name: name,
      prompt: prompt,
      negativePrompt: negativePrompt,
    );
    var created = state.characters.firstWhere(
      (character) => !existingIds.contains(character.id),
    );
    created = created.copyWith(
      enabled: enabled,
      positionMode: positionMode,
      customPosition: customPosition,
    );
    state = state.updateCharacter(created).normalizeCustomPositions();
    final applied = state.characters.firstWhere(
      (character) => character.id == created.id,
    );
    return (character: applied, persisted: await _saveConfig());
  }

  /// 添加新角色
  ///
  /// [gender] 角色性别
  /// [name] 角色名称，为空时自动生成
  /// [prompt] 正向提示词，为空时根据性别生成默认值
  /// [negativePrompt] 角色独立负向提示词；null 时保留旧版默认值
  /// [thumbnailPath] 缩略图路径（词库导入时）
  ///
  /// Requirements: 1.2, 1.3
  void addCharacter(
    CharacterGender gender, {
    String? name,
    String? prompt,
    String? negativePrompt,
    String? thumbnailPath,
  }) {
    if (isAtCharacterLimit) {
      // 官方上限：V5 为 22、V4/V4.5 为 6。到顶后静默拒绝，
      // 添加入口会按同一判定禁用并给出提示。
      AppLogger.w(
        'Character limit reached ($characterLimit), ignoring addCharacter',
        'CharacterPrompt',
      );
      return;
    }
    state = state.addCharacter(
      gender: gender,
      name: name,
      prompt: prompt,
      negativePrompt: negativePrompt,
      thumbnailPath: thumbnailPath,
    );
    unawaited(_saveConfig());
  }

  /// 当前模型的官方角色数量上限。
  int get characterLimit {
    final model = ref.read(generationParamsNotifierProvider).model;
    return ModelCapabilityRegistry.of(model).maxCharacters;
  }

  /// 是否已达到官方角色数量上限。
  bool get isAtCharacterLimit {
    final limit = characterLimit;
    return limit > 0 && state.characters.length >= limit;
  }

  /// 移除角色
  ///
  /// [id] 要移除的角色ID
  ///
  /// Requirements: 4.2
  void removeCharacter(String id) {
    state = state.removeCharacter(id);
    unawaited(_saveConfig());
  }

  /// 更新角色
  ///
  /// [character] 更新后的角色数据
  ///
  /// Requirements: 2.2, 2.3, 2.4, 2.5
  void updateCharacter(CharacterPrompt character) {
    state = state.updateCharacter(character).normalizeCustomPositions();
    unawaited(_saveConfig());
  }

  /// 重新排序角色
  ///
  /// [oldIndex] 原位置索引
  /// [newIndex] 新位置索引
  ///
  /// Requirements: 4.1, 4.3
  void reorderCharacters(int oldIndex, int newIndex) {
    state = state.reorderCharacters(oldIndex, newIndex);
    unawaited(_saveConfig());
  }

  /// 按稳定角色 ID 设置完整顺序。
  void setCharacterOrder(List<String> orderedIds) {
    final currentById = {
      for (final character in state.characters) character.id: character,
    };
    if (orderedIds.length != currentById.length ||
        orderedIds.toSet().length != orderedIds.length ||
        !orderedIds.every(currentById.containsKey)) {
      throw const FormatException(
        'orderedIds must contain every current character ID exactly once',
      );
    }
    state = state.copyWith(
      characters: [for (final id in orderedIds) currentById[id]!],
    );
    unawaited(_saveConfig());
  }

  /// 设置全局AI选择位置
  ///
  /// [value] 是否启用全局AI选择
  ///
  /// Requirements: 3.4
  void setGlobalAiChoice(bool value) {
    var newState = state.copyWith(globalAiChoice: value);

    // 当关闭全局AI选择时，为未设置位置的角色智能分配位置
    if (!value) {
      newState = newState.normalizeCustomPositions();
    }

    state = newState;
    unawaited(_saveConfig());
  }

  /// 清空所有角色
  ///
  /// Requirements: 4.4
  void clearAllCharacters() {
    state = state.clearAllCharacters();
    unawaited(_saveConfig());
  }

  /// 清空所有角色（别名）
  void clearAll() => clearAllCharacters();

  /// 替换所有角色
  ///
  /// 用于随机生成时一次性设置所有角色
  void replaceAll(List<CharacterPrompt> characters) {
    final requested = CharacterPromptConfig(
      characters: characters,
      globalAiChoice: state.globalAiChoice,
    );
    final model = ref.read(generationParamsNotifierProvider).model;
    state = limitCharacterConfigForModel(requested, model);
    if (state.characters.length != characters.length) {
      AppLogger.w(
        'Character import truncated from ${characters.length} to '
            '${state.characters.length} for $model',
        'CharacterPrompt',
      );
    }
    unawaited(_saveConfig());
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

/// 是否已达到当前模型的官方角色上限（V5 为 22、V4/V4.5 为 6）。
@riverpod
bool characterLimitReached(Ref ref) {
  final model = ref.watch(
    generationParamsNotifierProvider.select((params) => params.model),
  );
  final limit = ModelCapabilityRegistry.of(model).maxCharacters;
  final count = ref.watch(characterCountProvider);
  return limit > 0 && count >= limit;
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
