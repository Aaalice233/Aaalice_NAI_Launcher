import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/local_onnx_model_service.dart';

/// 反推面板列出的本地 tagger 模型。
///
/// 面板重建时复用同一次扫描；切换目录、导入、清除托管模型或用户点刷新时失效重扫，
/// 面板卸载后释放，下次展开重新扫描以反映外部放入的文件。
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
