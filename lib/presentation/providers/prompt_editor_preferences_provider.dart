import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/storage/local_storage_service.dart';

/// Stable session IDs persist locally; controller identities stay in memory.
final promptTagModeProvider = NotifierProvider.autoDispose
    .family<PromptTagModeNotifier, bool, Object>(PromptTagModeNotifier.new);

class PromptTagModeNotifier extends AutoDisposeFamilyNotifier<bool, Object> {
  @override
  bool build(Object sessionId) => sessionId is String
      ? ref
                .watch(localStorageServiceProvider)
                .getSetting<bool>('${StorageKeys.promptTagMode}.$sessionId') ??
            false
      : false;

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    if (arg case final String sessionId) {
      await ref
          .read(localStorageServiceProvider)
          .setSetting('${StorageKeys.promptTagMode}.$sessionId', enabled);
    }
  }
}
