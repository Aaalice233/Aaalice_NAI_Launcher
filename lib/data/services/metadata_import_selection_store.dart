import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/storage/local_storage_service.dart';
import '../models/metadata/metadata_import_options.dart';
import '../models/metadata/metadata_import_selection_codec.dart';

final metadataImportSelectionStoreProvider =
    Provider<MetadataImportSelectionStore>(
      (ref) =>
          MetadataImportSelectionStore(ref.watch(localStorageServiceProvider)),
    );

/// 记住用户上次在元数据导入对话框中确认的类别开关，仅保存在本机。
class MetadataImportSelectionStore {
  const MetadataImportSelectionStore(this._storage);

  final LocalStorageService _storage;

  MetadataImportOptions load() {
    final raw = _storage.getSetting<Object?>(
      StorageKeys.metadataImportLastSelection,
    );
    return MetadataImportSelectionCodec.decode(raw is String ? raw : null);
  }

  Future<void> save(MetadataImportOptions options) => _storage.setSetting(
    StorageKeys.metadataImportLastSelection,
    MetadataImportSelectionCodec.encode(options),
  );
}
