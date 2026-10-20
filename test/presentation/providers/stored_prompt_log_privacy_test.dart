import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/presentation/providers/fixed_tags_provider.dart';
import 'package:nai_launcher/presentation/providers/prompt_regex_rules_provider.dart';
import 'package:nai_launcher/presentation/providers/tag_library_page_provider.dart';

import '../../helpers/log_capture.dart';
import '../../helpers/memory_local_storage.dart';

const _corrupt = '[{"content":"secret lighthouse keeper",';

void main() {
  late MemoryLocalStorage storage;
  late ProviderContainer container;

  setUp(() {
    storage = MemoryLocalStorage();
    container = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    );
  });

  tearDown(() => container.dispose());

  Future<List<String>> loadLogs(ProviderListenable<Object?> provider) {
    return captureLogs(() => container.read(provider));
  }

  test('corrupt fixed tags load without logging the prompt', () async {
    storage.values[StorageKeys.fixedTagsData] = _corrupt;

    final logs = await loadLogs(fixedTagsNotifierProvider);

    expect(container.read(fixedTagsNotifierProvider).entries, isEmpty);
    expect(logs.where((line) => line.contains('fixed tags')), hasLength(1));
    expect(logs.where((line) => line.contains('lighthouse')), isEmpty);
  });

  test('corrupt tag library loads without logging the prompt', () async {
    storage.values[StorageKeys.tagLibraryEntriesData] = _corrupt;

    final logs = await loadLogs(tagLibraryPageNotifierProvider);

    expect(container.read(tagLibraryPageNotifierProvider).entries, isEmpty);
    expect(logs.where((line) => line.contains('tag library')), hasLength(1));
    expect(logs.where((line) => line.contains('lighthouse')), isEmpty);
  });

  test('corrupt regex rule is skipped without logging its text', () async {
    storage.values[StorageKeys.promptRegexRules] = <dynamic>[
      '{"pattern":"secret lighthouse keeper",',
    ];

    final logs = await loadLogs(promptRegexRulesProvider);

    expect(container.read(promptRegexRulesProvider), isEmpty);
    expect(logs.where((line) => line.contains('regex rule')), hasLength(1));
    expect(logs.where((line) => line.contains('lighthouse')), isEmpty);
  });
}
