import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/storage/local_storage_service.dart';

final promptTagModeProvider = NotifierProvider<PromptTagModeNotifier, bool>(
  PromptTagModeNotifier.new,
);

class PromptTagModeNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref
          .read(localStorageServiceProvider)
          .getSetting<bool>(StorageKeys.promptTagMode) ??
      false;

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    await ref
        .read(localStorageServiceProvider)
        .setSetting(StorageKeys.promptTagMode, enabled);
  }
}
