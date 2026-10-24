import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/autocomplete/autocomplete_providers.dart';

enum AutocompleteCacheKind { danbooru, aiTranslations }

/// 正在清除的补全缓存；状态不随设置页销毁，离开再返回时按钮仍保持忙碌。
final autocompleteCacheClearProvider =
    NotifierProvider<
      AutocompleteCacheClearNotifier,
      Set<AutocompleteCacheKind>
    >(AutocompleteCacheClearNotifier.new);

class AutocompleteCacheClearNotifier
    extends Notifier<Set<AutocompleteCacheKind>> {
  var _disposed = false;

  @override
  Set<AutocompleteCacheKind> build() {
    ref.onDispose(() => _disposed = true);
    return const {};
  }

  /// 同类缓存已在清除时抛出 [StateError]；失败原样抛出，统计仍按磁盘现状刷新。
  Future<int> clear(AutocompleteCacheKind kind) async {
    if (state.contains(kind)) {
      throw StateError('Autocomplete cache ${kind.name} is already clearing');
    }
    final clearCache = switch (kind) {
      AutocompleteCacheKind.danbooru =>
        ref.read(danbooruCompletionSourceProvider).clearCache,
      AutocompleteCacheKind.aiTranslations =>
        ref.read(autocompleteCacheDatabaseProvider).clearAiTranslationCache,
    };
    state = {...state, kind};
    try {
      return await clearCache();
    } finally {
      if (!_disposed) {
        state = {...state}..remove(kind);
        ref.invalidate(autocompleteCacheStatisticsProvider);
      }
    }
  }
}
