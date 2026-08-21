import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/local_storage_service.dart';
import '../widgets/common/transparency_background.dart';

part 'preview_transparency_provider.g.dart';

/// 预览区透明底色样式（对齐官网结果区的 transparencyBackground 设置）
///
/// 值域见 [TransparencyBackgrounds]：三档棋盘格、`none`、六个具名纯色
/// 或 `#RRGGBB` 自定义颜色。
@Riverpod(keepAlive: true)
class PreviewTransparencyNotifier extends _$PreviewTransparencyNotifier {
  @override
  String build() {
    final storage = ref.read(localStorageServiceProvider);
    return TransparencyBackgrounds.normalize(
      storage.getPreviewTransparencyBackground(),
    );
  }

  Future<void> setStyle(String style) async {
    final normalized = TransparencyBackgrounds.normalize(style);
    if (normalized == state) return;
    state = normalized;
    await ref
        .read(localStorageServiceProvider)
        .setPreviewTransparencyBackground(normalized);
  }
}
