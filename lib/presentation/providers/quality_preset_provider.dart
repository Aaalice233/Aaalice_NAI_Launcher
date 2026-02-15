import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/api_constants.dart';
import '../../core/storage/local_storage_service.dart';
import '../../data/models/prompt/prompt_preset_mode.dart';
import '../../data/models/tag_library/tag_library_entry.dart';
import 'tag_library_page_provider.dart';

part 'quality_preset_provider.g.dart';

/// 质量词预设状态
class QualityPresetState {
  /// 当前预设模式
  final PromptPresetMode mode;

  /// 当前选中的自定义条目 ID（mode 为 custom 时有效）
  final String? customEntryId;

  /// 所有已添加的自定义条目 ID 列表（持久化保存）
  final List<String> customEntryIds;

  const QualityPresetState({
    this.mode = PromptPresetMode.naiDefault,
    this.customEntryId,
    this.customEntryIds = const [],
  });

  QualityPresetState copyWith({
    PromptPresetMode? mode,
    String? customEntryId,
    bool clearCustomEntryId = false,
    List<String>? customEntryIds,
  }) {
    return QualityPresetState(
      mode: mode ?? this.mode,
      customEntryId:
          clearCustomEntryId ? null : (customEntryId ?? this.customEntryId),
      customEntryIds: customEntryIds ?? this.customEntryIds,
    );
  }

  /// 是否使用自定义条目
  bool get isCustom => mode == PromptPresetMode.custom && customEntryId != null;

  /// 是否启用质量词（非 none 模式）
  bool get isEnabled => mode != PromptPresetMode.none;

  /// 是否有已添加的自定义条目
  bool get hasCustomEntries => customEntryIds.isNotEmpty;
}

/// 质量词预设 Provider
@Riverpod(keepAlive: true)
class QualityPresetNotifier extends _$QualityPresetNotifier {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  QualityPresetState build() {
    // 读取自定义条目列表
    final customIds = _storage.getQualityPresetCustomIds();

    // 优先读取新格式
    final modeIndex = _storage.getQualityPresetMode();
    final customId = _storage.getQualityPresetCustomId();

    // 如果新格式有数据，使用新格式
    if (modeIndex > 0 || customId != null) {
      final mode = PromptPresetMode.values[modeIndex.clamp(0, 2)];
      return QualityPresetState(
        mode: mode,
        customEntryId: customId,
        customEntryIds: customIds,
      );
    }

    // 兼容旧格式：从 addQualityTags 布尔值迁移
    final oldEnabled = _storage.getAddQualityTags();
    return QualityPresetState(
      mode: oldEnabled ? PromptPresetMode.naiDefault : PromptPresetMode.none,
      customEntryIds: customIds,
    );
  }

  /// 设置为 NAI 默认
  void setNaiDefault() {
    state = state.copyWith(
      mode: PromptPresetMode.naiDefault,
      clearCustomEntryId: true,
    );
    _save();
  }

  /// 设置为无
  void setNone() {
    state = state.copyWith(
      mode: PromptPresetMode.none,
      clearCustomEntryId: true,
    );
    _save();
  }

  /// 设置为自定义条目
  void setCustomEntry(String entryId) {
    // 添加到列表（如果不存在）
    final newIds = List<String>.from(state.customEntryIds);
    if (!newIds.contains(entryId)) {
      newIds.add(entryId);
    }

    state = QualityPresetState(
      mode: PromptPresetMode.custom,
      customEntryId: entryId,
      customEntryIds: newIds,
    );
    _save();

    // 记录使用次数
    ref.read(tagLibraryPageNotifierProvider.notifier).recordUsage(entryId);
  }

  /// 切换到已添加的自定义条目
  void selectCustomEntry(String entryId) {
    if (!state.customEntryIds.contains(entryId)) return;
    state = state.copyWith(
      mode: PromptPresetMode.custom,
      customEntryId: entryId,
    );
    _save();
  }

  /// 从列表中删除自定义条目
  void removeCustomEntry(String entryId) {
    final newIds = List<String>.from(state.customEntryIds)..remove(entryId);

    // 如果删除的是当前选中的条目，切换到 NAI 默认
    if (state.customEntryId == entryId) {
      state = QualityPresetState(
        mode: PromptPresetMode.naiDefault,
        customEntryIds: newIds,
      );
    } else {
      state = state.copyWith(customEntryIds: newIds);
    }
    _save();
  }

  /// 保存到本地存储
  void _save() {
    _storage.setQualityPresetMode(state.mode.index);
    _storage.setQualityPresetCustomId(state.customEntryId);
    _storage.setQualityPresetCustomIds(state.customEntryIds);

    // 同步更新旧格式（保持向后兼容）
    _storage.setAddQualityTags(state.mode != PromptPresetMode.none);
  }

  /// 获取实际应用的质量词内容
  ///
  /// [model] 当前选择的模型
  /// 返回 null 表示不添加质量词
  String? getEffectiveContent(String model) {
    switch (state.mode) {
      case PromptPresetMode.naiDefault:
        return QualityTags.getQualityTags(model);
      case PromptPresetMode.none:
        return null;
      case PromptPresetMode.custom:
        if (state.customEntryId == null) return null;
        final entries = ref.read(tagLibraryPageNotifierProvider).entries;
        final entry = entries.cast<TagLibraryEntry?>().firstWhere(
              (e) => e?.id == state.customEntryId,
              orElse: () => null,
            );
        return entry?.content;
    }
    return null;
  }
}

/// 当前选择的质量词自定义条目
@riverpod
TagLibraryEntry? currentQualityEntry(Ref ref) {
  final config = ref.watch(qualityPresetNotifierProvider);
  if (!config.isCustom) return null;

  final entries = ref.watch(tagLibraryPageNotifierProvider).entries;
  return entries.cast<TagLibraryEntry?>().firstWhere(
        (e) => e?.id == config.customEntryId,
        orElse: () => null,
      );
}

/// 所有已添加的质量词自定义条目列表
@riverpod
List<TagLibraryEntry> qualityCustomEntries(Ref ref) {
  final config = ref.watch(qualityPresetNotifierProvider);
  final allEntries = ref.watch(tagLibraryPageNotifierProvider).entries;

  return config.customEntryIds
      .map(
        (id) => allEntries.cast<TagLibraryEntry?>().firstWhere(
              (e) => e?.id == id,
              orElse: () => null,
            ),
      )
      .whereType<TagLibraryEntry>()
      .toList();
}
