import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/storage_keys.dart';
import '../storage/local_storage_service.dart';
import 'completion_models.dart';

class AutocompleteSettings {
  const AutocompleteSettings({
    this.enabled = true,
    this.resultLimit = CompletionResultLimits.all,
    this.showAliases = true,
    this.showTranslations = true,
    this.autoInsertComma = true,
    this.replaceUnderscores = false,
    this.danbooruEnabled = true,
    this.relatedTagsEnabled = true,
    this.llmTranslationEnabled = false,
    this.zhInstallPromptDismissed = false,
  });

  final bool enabled;
  final int resultLimit;
  final bool showAliases;
  final bool showTranslations;
  final bool autoInsertComma;
  final bool replaceUnderscores;
  final bool danbooruEnabled;
  final bool relatedTagsEnabled;
  final bool llmTranslationEnabled;
  final bool zhInstallPromptDismissed;

  AutocompleteSettings copyWith({
    bool? enabled,
    int? resultLimit,
    bool? showAliases,
    bool? showTranslations,
    bool? autoInsertComma,
    bool? replaceUnderscores,
    bool? danbooruEnabled,
    bool? relatedTagsEnabled,
    bool? llmTranslationEnabled,
    bool? zhInstallPromptDismissed,
  }) {
    return AutocompleteSettings(
      enabled: enabled ?? this.enabled,
      resultLimit: resultLimit ?? this.resultLimit,
      showAliases: showAliases ?? this.showAliases,
      showTranslations: showTranslations ?? this.showTranslations,
      autoInsertComma: autoInsertComma ?? this.autoInsertComma,
      replaceUnderscores: replaceUnderscores ?? this.replaceUnderscores,
      danbooruEnabled: danbooruEnabled ?? this.danbooruEnabled,
      relatedTagsEnabled: relatedTagsEnabled ?? this.relatedTagsEnabled,
      llmTranslationEnabled:
          llmTranslationEnabled ?? this.llmTranslationEnabled,
      zhInstallPromptDismissed:
          zhInstallPromptDismissed ?? this.zhInstallPromptDismissed,
    );
  }
}

final autocompleteSettingsProvider =
    StateNotifierProvider<AutocompleteSettingsNotifier, AutocompleteSettings>((
      ref,
    ) {
      return AutocompleteSettingsNotifier(
        ref.read(localStorageServiceProvider),
      );
    });

class AutocompleteSettingsNotifier extends StateNotifier<AutocompleteSettings> {
  AutocompleteSettingsNotifier(this._storage) : super(_load(_storage));

  final LocalStorageService _storage;

  static AutocompleteSettings _load(LocalStorageService storage) {
    try {
      return AutocompleteSettings(
        enabled:
            storage.getSetting<bool>(
              StorageKeys.enableAutocomplete,
              defaultValue: true,
            ) ??
            true,
        resultLimit: _normalizeResultLimit(
          storage.getSetting<int>(
                StorageKeys.autocompleteResultLimit,
                defaultValue: CompletionResultLimits.all,
              ) ??
              CompletionResultLimits.all,
        ),
        showAliases:
            storage.getSetting<bool>(
              StorageKeys.autocompleteShowAliases,
              defaultValue: true,
            ) ??
            true,
        showTranslations:
            storage.getSetting<bool>(
              StorageKeys.autocompleteShowTranslations,
              defaultValue: true,
            ) ??
            true,
        autoInsertComma:
            storage.getSetting<bool>(
              StorageKeys.autocompleteAutoComma,
              defaultValue: true,
            ) ??
            true,
        replaceUnderscores:
            storage.getSetting<bool>(
              StorageKeys.autocompleteReplaceUnderscores,
              defaultValue: false,
            ) ??
            false,
        danbooruEnabled:
            storage.getSetting<bool>(
              StorageKeys.autocompleteDanbooruEnabled,
              defaultValue: true,
            ) ??
            true,
        relatedTagsEnabled:
            storage.getSetting<bool>(
              StorageKeys.enableCooccurrenceRecommendation,
              defaultValue: true,
            ) ??
            true,
        llmTranslationEnabled:
            storage.getSetting<bool>(
              StorageKeys.autocompleteLlmTranslationEnabled,
              defaultValue: false,
            ) ??
            false,
        zhInstallPromptDismissed:
            storage.getSetting<bool>(
              StorageKeys.autocompleteZhInstallPromptDismissed,
              defaultValue: false,
            ) ??
            false,
      );
    } catch (_) {
      return const AutocompleteSettings();
    }
  }

  Future<void> setEnabled(bool value) => _set(
    state.copyWith(enabled: value),
    StorageKeys.enableAutocomplete,
    value,
  );

  Future<void> setResultLimit(int value) {
    final normalized = _normalizeResultLimit(value);
    return _set(
      state.copyWith(resultLimit: normalized),
      StorageKeys.autocompleteResultLimit,
      normalized,
    );
  }

  static int _normalizeResultLimit(int value) =>
      CompletionResultLimits.isAll(value)
      ? CompletionResultLimits.all
      : value.clamp(5, 100);

  Future<void> setShowAliases(bool value) => _set(
    state.copyWith(showAliases: value),
    StorageKeys.autocompleteShowAliases,
    value,
  );

  Future<void> setShowTranslations(bool value) => _set(
    state.copyWith(showTranslations: value),
    StorageKeys.autocompleteShowTranslations,
    value,
  );

  Future<void> setAutoInsertComma(bool value) => _set(
    state.copyWith(autoInsertComma: value),
    StorageKeys.autocompleteAutoComma,
    value,
  );

  Future<void> setReplaceUnderscores(bool value) => _set(
    state.copyWith(replaceUnderscores: value),
    StorageKeys.autocompleteReplaceUnderscores,
    value,
  );

  Future<void> setDanbooruEnabled(bool value) => _set(
    state.copyWith(danbooruEnabled: value),
    StorageKeys.autocompleteDanbooruEnabled,
    value,
  );

  Future<void> setRelatedTagsEnabled(bool value) => _set(
    state.copyWith(relatedTagsEnabled: value),
    StorageKeys.enableCooccurrenceRecommendation,
    value,
  );

  Future<void> setLlmTranslationEnabled(bool value) => _set(
    state.copyWith(llmTranslationEnabled: value),
    StorageKeys.autocompleteLlmTranslationEnabled,
    value,
  );

  Future<void> dismissZhInstallPrompt() => _set(
    state.copyWith(zhInstallPromptDismissed: true),
    StorageKeys.autocompleteZhInstallPromptDismissed,
    true,
  );

  Future<void> _set<T>(AutocompleteSettings next, String key, T value) async {
    state = next;
    await _storage.setSetting<T>(key, value);
  }
}
