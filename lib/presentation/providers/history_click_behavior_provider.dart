import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/local_storage_service.dart';

part 'history_click_behavior_provider.g.dart';

enum HistoryClickBehavior {
  openDetail,
  selectPreview;

  static HistoryClickBehavior fromStorageValue(String value) {
    return value == 'select_preview'
        ? HistoryClickBehavior.selectPreview
        : HistoryClickBehavior.openDetail;
  }

  String get storageValue => this == HistoryClickBehavior.selectPreview
      ? 'select_preview'
      : 'open_detail';
}

@Riverpod(keepAlive: true)
class HistoryClickBehaviorNotifier extends _$HistoryClickBehaviorNotifier {
  @override
  HistoryClickBehavior build() {
    final storage = ref.read(localStorageServiceProvider);
    return HistoryClickBehavior.fromStorageValue(
      storage.getHistoryClickBehavior(),
    );
  }

  Future<void> setBehavior(HistoryClickBehavior behavior) async {
    state = behavior;
    await ref
        .read(localStorageServiceProvider)
        .setHistoryClickBehavior(behavior.storageValue);
  }
}
