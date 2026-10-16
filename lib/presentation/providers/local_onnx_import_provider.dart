import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/local_onnx_model_service.dart';

/// 本地 ONNX 模型是否正在导入；状态不随设置页销毁，GB 级导入期间不能再发起导入或清空模型。
final localOnnxImportProvider = NotifierProvider<LocalOnnxImportNotifier, bool>(
  LocalOnnxImportNotifier.new,
);

class LocalOnnxImportNotifier extends Notifier<bool> {
  var _disposed = false;

  @override
  bool build() {
    ref.onDispose(() => _disposed = true);
    return false;
  }

  /// 已有导入进行中时抛出 [StateError]，不会有两次导入同时写托管目录。
  Future<int> importSelections(List<LocalOnnxImportSource> sources) async {
    if (state) {
      throw StateError('A local ONNX model import is already running');
    }
    final service = ref.read(localOnnxModelServiceProvider);
    state = true;
    try {
      return await service.importTaggerSelections(sources);
    } finally {
      if (!_disposed) state = false;
    }
  }
}
