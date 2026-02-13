import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/enums/uc_preset_type.dart';
import '../../../core/storage/local_storage_service.dart';

part 'generation_settings_notifiers.g.dart';

/// 质量标签设置 Notifier
@Riverpod(keepAlive: true)
class QualityTagsSettings extends _$QualityTagsSettings {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  bool build() => _storage.getAddQualityTags();

  void toggle() => set(!state);

  void set(bool value) {
    state = value;
    _storage.setAddQualityTags(value);
  }
}

/// 自动补全设置 Notifier
@Riverpod(keepAlive: true)
class AutocompleteSettings extends _$AutocompleteSettings {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  bool build() => _storage.getEnableAutocomplete();

  void toggle() => set(!state);

  void set(bool value) {
    state = value;
    _storage.setEnableAutocomplete(value);
  }
}

/// 自动格式化设置 Notifier
@Riverpod(keepAlive: true)
class AutoFormatPromptSettings extends _$AutoFormatPromptSettings {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  bool build() => _storage.getAutoFormatPrompt();

  void toggle() => set(!state);

  void set(bool value) {
    state = value;
    _storage.setAutoFormatPrompt(value);
  }
}

/// 高亮强调设置 Notifier
@Riverpod(keepAlive: true)
class HighlightEmphasisSettings extends _$HighlightEmphasisSettings {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  bool build() => _storage.getHighlightEmphasis();

  void toggle() => set(!state);

  void set(bool value) {
    state = value;
    _storage.setHighlightEmphasis(value);
  }
}

/// SD语法自动转换设置 Notifier
@Riverpod(keepAlive: true)
class SdSyntaxAutoConvertSettings extends _$SdSyntaxAutoConvertSettings {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  bool build() => _storage.getSdSyntaxAutoConvert();

  void toggle() => set(!state);

  void set(bool value) {
    state = value;
    _storage.setSdSyntaxAutoConvert(value);
  }
}

/// 标签共现推荐设置 Notifier
@Riverpod(keepAlive: true)
class CooccurrenceSettings extends _$CooccurrenceSettings {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  bool build() => _storage.getEnableCooccurrenceRecommendation();

  void toggle() => set(!state);

  void set(bool value) {
    state = value;
    _storage.setEnableCooccurrenceRecommendation(value);
  }
}

/// 负面提示词预设设置 Notifier
@Riverpod(keepAlive: true)
class UcPresetSettings extends _$UcPresetSettings {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  UcPresetType build() {
    final index = _storage.getUcPresetType();
    return (index >= 0 && index < UcPresetType.values.length)
        ? UcPresetType.values[index]
        : UcPresetType.heavy;
  }

  void set(UcPresetType type) {
    state = type;
    _storage.setUcPresetType(type.index);
  }
}

/// 抽卡模式设置 Notifier（生成时自动随机提示词）
@Riverpod(keepAlive: true)
class RandomPromptMode extends _$RandomPromptMode {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  bool build() => _storage.getRandomPromptMode();

  void toggle() => set(!state);

  void set(bool value) {
    state = value;
    _storage.setRandomPromptMode(value);
  }
}

/// 每次请求生成图片数量设置 Notifier（1-4张）
@Riverpod(keepAlive: true)
class ImagesPerRequest extends _$ImagesPerRequest {
  LocalStorageService get _storage => ref.read(localStorageServiceProvider);

  @override
  int build() => _storage.getImagesPerRequest();

  void set(int value) {
    state = value.clamp(1, 4);
    _storage.setImagesPerRequest(state);
  }
}
