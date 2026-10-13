import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/local_onnx_model_service.dart';

// 面板重建复用同一次扫描，目录/托管文件变化或刷新时失效
final localTaggerModelsProvider =
    FutureProvider.autoDispose<List<LocalOnnxModelDescriptor>>(
      (ref) => ref.watch(localOnnxModelServiceProvider).scanTaggerModels(),
    );

/// 设置页显示的托管模型文件数，与模型列表在同样的时机失效。
final localTaggerManagedFileCountProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(localOnnxModelServiceProvider).managedFileCount(),
);

/// 模型目录或托管文件变化后让本地 tagger 的缓存一起失效。
void invalidateLocalTaggerCaches(ProviderContainer container) {
  container
    ..invalidate(localTaggerModelsProvider)
    ..invalidate(localTaggerManagedFileCountProvider);
}
