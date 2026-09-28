import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/storage/local_storage_service.dart';

final imageComparisonFollowMouseProvider =
    NotifierProvider<ImageComparisonFollowMouseNotifier, bool>(
      ImageComparisonFollowMouseNotifier.new,
    );

class ImageComparisonFollowMouseNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref
          .watch(localStorageServiceProvider)
          .getSetting<bool>(StorageKeys.imageComparisonFollowMouse) ??
      false;

  Future<void> setEnabled(bool enabled) async {
    await ref
        .read(localStorageServiceProvider)
        .setSetting(StorageKeys.imageComparisonFollowMouse, enabled);
    state = enabled;
  }
}
