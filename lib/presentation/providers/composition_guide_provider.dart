import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/local_storage_service.dart';
import '../widgets/common/composition_guide.dart';

part 'composition_guide_provider.g.dart';

/// 构图参考线设置：档位 + 自定义网格的列/行
typedef CompositionGuideSettings = ({
  CompositionGuideMode mode,
  int columns,
  int rows,
});

/// 构图参考线设置
///
/// 全局偏好，跨会话保留；列/行读出后夹到合法区间，防止旧值或手改存储越界。
@Riverpod(keepAlive: true)
class CompositionGuideNotifier extends _$CompositionGuideNotifier {
  @override
  CompositionGuideSettings build() {
    final storage = ref.read(localStorageServiceProvider);
    return (
      mode: CompositionGuideMode.fromStorageValue(
        storage.getCompositionGuideMode(),
      ),
      columns: CompositionGuide.clampDivisions(
        storage.getCompositionGuideColumns(),
      ),
      rows: CompositionGuide.clampDivisions(storage.getCompositionGuideRows()),
    );
  }

  Future<void> setMode(CompositionGuideMode mode) async {
    if (mode == state.mode) return;
    state = (mode: mode, columns: state.columns, rows: state.rows);
    await ref
        .read(localStorageServiceProvider)
        .setCompositionGuideMode(mode.storageValue);
  }

  Future<void> setColumns(int columns) async {
    final clamped = CompositionGuide.clampDivisions(columns);
    if (clamped == state.columns) return;
    state = (mode: state.mode, columns: clamped, rows: state.rows);
    await ref
        .read(localStorageServiceProvider)
        .setCompositionGuideColumns(clamped);
  }

  Future<void> setRows(int rows) async {
    final clamped = CompositionGuide.clampDivisions(rows);
    if (clamped == state.rows) return;
    state = (mode: state.mode, columns: state.columns, rows: clamped);
    await ref
        .read(localStorageServiceProvider)
        .setCompositionGuideRows(clamped);
  }
}
