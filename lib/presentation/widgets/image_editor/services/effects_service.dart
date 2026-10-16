import 'package:flutter/foundation.dart';

import '../../../../core/utils/isolate_pool.dart';
import '../effects/editor_effects.dart';

class EditorEffectsService {
  const EditorEffectsService();

  Future<EditorEffectResult> apply(EditorEffectJob job) async {
    final message = await ComputeGate().runCompute(
      runEditorEffectJobMessage,
      job.toMessage(),
      debugLabel: 'image_editor_effect',
    );
    return EditorEffectResult.fromMessage(message);
  }

  /// 预览只关心最新一次：取得计算许可时 [isCurrent] 已为 false 的请求不再执行，返回 null。
  Future<EditorEffectResult?> preview(
    EditorEffectJob job, {
    required bool Function() isCurrent,
  }) async {
    final message = await ComputeGate().run<Map<String, Object?>?>(() {
      if (!isCurrent()) return null;
      return compute(
        runEditorEffectJobMessage,
        job.toMessage(),
        debugLabel: 'image_editor_effect_preview',
      );
    });
    return message == null ? null : EditorEffectResult.fromMessage(message);
  }
}
