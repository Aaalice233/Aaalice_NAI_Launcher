import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/models/tag_library/tag_library_entry.dart';
import '../../../data/services/alias_resolver_service.dart';

part 'alias_autocomplete_provider.g.dart';

/// 别名自动补全状态
class AliasAutocompleteState {
  /// 建议列表
  final List<TagLibraryEntry> suggestions;

  /// 是否正在加载
  final bool isLoading;

  /// 是否有建议
  bool get hasSuggestions => suggestions.isNotEmpty;

  const AliasAutocompleteState({
    this.suggestions = const [],
    this.isLoading = false,
  });

  AliasAutocompleteState copyWith({
    List<TagLibraryEntry>? suggestions,
    bool? isLoading,
  }) {
    return AliasAutocompleteState(
      suggestions: suggestions ?? this.suggestions,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// 别名自动补全 Provider
///
/// 用于词库条目的智能补全
@riverpod
class AliasAutocompleteNotifier extends _$AliasAutocompleteNotifier {
  Timer? _debounceTimer;

  /// 防抖延迟
  static const _debounceDelay = Duration(milliseconds: 150);

  @override
  AliasAutocompleteState build() {
    ref.onDispose(() {
      _debounceTimer?.cancel();
    });
    return const AliasAutocompleteState();
  }

  /// 搜索词库条目
  ///
  /// [query] 搜索关键词
  /// [immediate] 是否立即执行（跳过防抖）
  void search(String query, {bool immediate = false}) {
    _debounceTimer?.cancel();

    // 设置加载状态
    state = state.copyWith(isLoading: true);

    void performSearch() {
      try {
        final resolverService = ref.read(aliasResolverServiceProvider.notifier);
        final entries = resolverService.searchEntries(query, limit: 15);

        debugPrint(
          'AliasAutocomplete: query="$query", found ${entries.length} entries',
        );

        state = AliasAutocompleteState(
          suggestions: entries,
          isLoading: false,
        );
      } catch (e) {
        debugPrint('AliasAutocomplete search error: $e');
        state = state.copyWith(isLoading: false);
      }
    }

    if (immediate) {
      performSearch();
    } else {
      _debounceTimer = Timer(_debounceDelay, performSearch);
    }
  }

  /// 清除建议
  void clear() {
    _debounceTimer?.cancel();
    state = const AliasAutocompleteState();
  }
}
