import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/data/models/metadata/metadata_import_options.dart';
import 'package:nai_launcher/data/services/metadata_import_selection_store.dart';

import '../../helpers/memory_local_storage.dart';

void main() {
  test('first use offers the select-all default', () {
    final store = MetadataImportSelectionStore(MemoryLocalStorage());

    expect(store.load(), MetadataImportOptions.all());
  });

  test('confirmed categories are stored as text and reloaded', () async {
    final storage = MemoryLocalStorage();
    final store = MetadataImportSelectionStore(storage);
    final options = MetadataImportOptions.all().copyWith(
      importSeed: false,
      importCharacterPrompts: false,
    );

    await store.save(options);

    expect(
      storage.values[StorageKeys.metadataImportLastSelection],
      isA<String>(),
    );
    expect(MetadataImportSelectionStore(storage).load(), options);
  });

  test('a non-text stored value is treated as no memory', () {
    final storage = MemoryLocalStorage()
      ..values[StorageKeys.metadataImportLastSelection] = {'seed': false};

    expect(
      MetadataImportSelectionStore(storage).load(),
      MetadataImportOptions.all(),
    );
  });
}
