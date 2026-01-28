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

  /// 自定义条目 ID（mode 为 custom 时有效）
  final String? customEntryId;

  const QualityPresetState({
    this.mode = PromptPresetMode.naiDefault,
    this.customEntryId,
  });

  QualityPresetState copyWith({
    PromptPresetMode? mode,
    String? customEntryId,
    bool clearCustomEntryId = false,
  }) {
    return QualityPresetState(
      mode: mode ?? this.mode,
      customEntryId:
          clearCustomEntryId ? null : (customEntryId ?? this.customEntryId),
    );
  }

  /// 是否使用自定义条目
  bool get isCustom => mode == PromptPresetMode.custom && customEntryId != null;

  /// 是否启用质量词（非 none 模式）
  bool get isEnabled => mode != PromptPresetMode.none;
}

/// 质量词预设 Provider
@Riverpod(keepAlive: true)
class QualityPresetNotifier extends _$QualityPresetNotifier {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  QualityPresetState build() {
    // 优先读取新格式
    final modeIndex = _storage.getQualityPresetMode();
    final customId = _storage.getQualityPresetCustomId();

    // 如果新格式有数据，使用新格式
    if (modeIndex > 0 || customId != null) {
      final mode = PromptPresetMode.values[modeIndex.clamp(0, 2)];
      return QualityPresetState(
        mode: mode,
        customEntryId: customId,
      );
    }

    // 兼容旧格式：从 addQualityTags 布尔值迁移
    final oldEnabled = _storage.getAddQualityTags();
    return QualityPresetState(
      mode: oldEnabled ? PromptPresetMode.naiDefault : PromptPresetMode.none,
    );
  }

  /// 设置为 NAI 默认
  void setNaiDefault() {
    state = const QualityPresetState(mode: PromptPresetMode.naiDefault);
    _save();
  }

  /// 设置为无
  void setNone() {
    state = const QualityPresetState(mode: PromptPresetMode.none);
    _save();
  }

  /// 设置为自定义条目
  void setCustomEntry(String entryId) {
    state = QualityPresetState(
      mode: PromptPresetMode.custom,
      customEntryId: entryId,
    );
    _save();

    // 记录使用次数
    ref.read(tagLibraryPageNotifierProvider.notifier).recordUsage(entryId);
  }

  /// 移除自定义条目（切换回 NAI 默认）
  void removeCustomEntry() {
    setNaiDefault();
  }

  /// 保存到本地存储
  void _save() {
    _storage.setQualityPresetMode(state.mode.index);
    _storage.setQualityPresetCustomId(state.customEntryId);

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
  }
}

/// 当前选择的质量词自定义条目
@riverpod
TagLibraryEntry? currentQualityEntry(CurrentQualityEntryRef ref) {
  final config = ref.watch(qualityPresetNotifierProvider);
  if (!config.isCustom) return null;

  final entries = ref.watch(tagLibraryPageNotifierProvider).entries;
  return entries.cast<TagLibraryEntry?>().firstWhere(
        (e) => e?.id == config.customEntryId,
        orElse: () => null,
      );
}
