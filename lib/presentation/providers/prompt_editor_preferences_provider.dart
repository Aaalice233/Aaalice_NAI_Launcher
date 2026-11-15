import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/storage/local_storage_service.dart';

/// Stable session IDs persist locally; controller identities stay in memory.
final promptTagModeProvider = NotifierProvider.autoDispose
    .family<PromptTagModeNotifier, bool, Object>(PromptTagModeNotifier.new);

class PromptTagModeNotifier extends Notifier<bool> {
  PromptTagModeNotifier(this.arg);

  final Object arg;

  @override
  bool build() => arg is String
      ? ref
                .watch(localStorageServiceProvider)
                .getSetting<bool>('${StorageKeys.promptTagMode}.$arg') ??
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
