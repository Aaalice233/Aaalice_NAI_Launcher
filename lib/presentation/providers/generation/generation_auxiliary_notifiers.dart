import 'dart:async';
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/datasources/remote/nai_image_enhancement_api_service.dart';
import '../../../data/datasources/remote/nai_tag_suggestion_api_service.dart';
import '../../../data/models/tag/tag_suggestion.dart';

part 'generation_auxiliary_notifiers.g.dart';

// ==================== 标签建议 Provider ====================

/// 标签建议状态
class TagSuggestionState {
  final List<TagSuggestion> suggestions;
  final bool isLoading;
  final String? error;

  const TagSuggestionState({
    this.suggestions = const [],
    this.isLoading = false,
    this.error,
  });

  TagSuggestionState copyWith({
    List<TagSuggestion>? suggestions,
    bool? isLoading,
    String? error,
  }) {
    return TagSuggestionState(
      suggestions: suggestions ?? this.suggestions,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 标签建议 Notifier
@riverpod
class TagSuggestionNotifier extends _$TagSuggestionNotifier {
  Timer? _debounceTimer;

  @override
  TagSuggestionState build() {
    ref.onDispose(() {
      _debounceTimer?.cancel();
    });
    return const TagSuggestionState();
  }

  /// 获取标签建议 (带防抖)
  void fetchSuggestions(String input, {String? model}) {
    _debounceTimer?.cancel();

    if (input.trim().length < 2) {
      state = const TagSuggestionState();
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      state = state.copyWith(isLoading: true, error: null);

      try {
        final apiService = ref.read(naiTagSuggestionApiServiceProvider);
        final suggestions = await apiService.suggestTags(input, model: model);
        state = state.copyWith(
          suggestions: suggestions,
          isLoading: false,
        );
      } catch (e) {
        state = state.copyWith(
          isLoading: false,
          error: e.toString(),
        );
      }
    });
  }

  /// 清除建议
  void clearSuggestions() {
    _debounceTimer?.cancel();
    state = const TagSuggestionState();
  }
}

// ==================== 图片放大 Provider ====================

/// 放大状态
enum UpscaleStatus {
  idle,
  processing,
  completed,
  error,
}

/// 放大状态
class UpscaleState {
  final UpscaleStatus status;
  final Uint8List? result;
  final String? error;
  final double progress;

  const UpscaleState({
    this.status = UpscaleStatus.idle,
    this.result,
    this.error,
    this.progress = 0.0,
  });

  UpscaleState copyWith({
    UpscaleStatus? status,
    Uint8List? result,
    String? error,
    double? progress,
  }) {
    return UpscaleState(
      status: status ?? this.status,
      result: result ?? this.result,
      error: error,
      progress: progress ?? this.progress,
    );
  }
}

/// 放大 Notifier
@riverpod
class UpscaleNotifier extends _$UpscaleNotifier {
  @override
  UpscaleState build() {
    return const UpscaleState();
  }

  /// 放大图像
  Future<void> upscale(Uint8List image, {int scale = 2}) async {
    state = state.copyWith(
      status: UpscaleStatus.processing,
      progress: 0.0,
      error: null,
      result: null,
    );

    try {
      final apiService = ref.read(naiImageEnhancementApiServiceProvider);
      final result = await apiService.upscaleImage(
        image,
        scale: scale,
        onProgress: (received, total) {
          if (total > 0) {
            state = state.copyWith(progress: received / total);
          }
        },
      );

      state = state.copyWith(
        status: UpscaleStatus.completed,
        result: result,
        progress: 1.0,
      );
    } catch (e) {
      state = state.copyWith(
        status: UpscaleStatus.error,
        error: e.toString(),
        progress: 0.0,
      );
    }
  }

  /// 清除结果
  void clear() {
    state = const UpscaleState();
  }
}
