import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/constants/api_constants.dart';
import '../../core/storage/local_storage_service.dart';
import '../../data/models/tag_library/tag_library_entry.dart';
import 'tag_library_page_provider.dart';

part 'uc_preset_provider.g.dart';

/// 负面词预设状态
class UcPresetState {
  /// 当前选择的 NAI 预设类型
  final UcPresetType presetType;

  /// 自定义条目 ID（如果有值，则使用自定义内容替换 NAI 预设）
  final String? customEntryId;

  const UcPresetState({
    this.presetType = UcPresetType.heavy,
    this.customEntryId,
  });

  UcPresetState copyWith({
    UcPresetType? presetType,
    String? customEntryId,
    bool clearCustomEntryId = false,
  }) {
    return UcPresetState(
      presetType: presetType ?? this.presetType,
      customEntryId:
          clearCustomEntryId ? null : (customEntryId ?? this.customEntryId),
    );
  }

  /// 是否使用自定义条目
  bool get isCustom => customEntryId != null;

  /// 是否启用预设（非 none 且非自定义）
  bool get isPresetEnabled => !isCustom && presetType != UcPresetType.none;

  /// 是否完全禁用（none 且非自定义）
  bool get isDisabled => !isCustom && presetType == UcPresetType.none;
}

/// 负面词预设 Provider（支持自定义条目）
@Riverpod(keepAlive: true)
class UcPresetNotifier extends _$UcPresetNotifier {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  UcPresetState build() {
    // 读取自定义条目 ID
    final customId = _storage.getUcPresetCustomId();

    // 读取 NAI 预设类型
    final typeIndex = _storage.getUcPresetType();
    final presetType =
        (typeIndex >= 0 && typeIndex < UcPresetType.values.length)
            ? UcPresetType.values[typeIndex]
            : UcPresetType.heavy;

    return UcPresetState(
      presetType: presetType,
      customEntryId: customId,
    );
  }

  /// 设置 NAI 预设类型（清除自定义）
  void setPresetType(UcPresetType type) {
    state = UcPresetState(presetType: type);
    _save();
  }

  /// 设置为自定义条目
  void setCustomEntry(String entryId) {
    state = state.copyWith(customEntryId: entryId);
    _save();

    // 记录使用次数
    ref.read(tagLibraryPageNotifierProvider.notifier).recordUsage(entryId);
  }

  /// 移除自定义条目（回退到之前选择的预设）
  void removeCustomEntry() {
    state = state.copyWith(clearCustomEntryId: true);
    _save();
  }

  /// 保存到本地存储
  void _save() {
    _storage.setUcPresetType(state.presetType.index);
    _storage.setUcPresetCustomId(state.customEntryId);
  }

  /// 获取实际应用的负面词内容
  ///
  /// [model] 当前选择的模型
  /// 返回 null 表示不添加预设内容
  String? getEffectiveContent(String model) {
    // 如果有自定义条目，使用自定义内容
    if (state.isCustom) {
      final entries = ref.read(tagLibraryPageNotifierProvider).entries;
      final entry = entries.cast<TagLibraryEntry?>().firstWhere(
            (e) => e?.id == state.customEntryId,
            orElse: () => null,
          );
      return entry?.content;
    }

    // 使用 NAI 预设
    if (state.presetType == UcPresetType.none) {
      return null;
    }
    return UcPresets.getPresetContent(model, state.presetType);
  }
}

/// 当前选择的 UC 自定义条目
@riverpod
TagLibraryEntry? currentUcEntry(CurrentUcEntryRef ref) {
  final config = ref.watch(ucPresetNotifierProvider);
  if (!config.isCustom) return null;

  final entries = ref.watch(tagLibraryPageNotifierProvider).entries;
  return entries.cast<TagLibraryEntry?>().firstWhere(
        (e) => e?.id == config.customEntryId,
        orElse: () => null,
      );
}
