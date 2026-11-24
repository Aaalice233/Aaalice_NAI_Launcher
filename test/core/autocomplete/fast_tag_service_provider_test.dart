import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/autocomplete/fast_tag_service_provider.dart';
import 'package:nai_launcher/core/autocomplete/tag_translation_lookup.dart';
import 'package:nai_launcher/core/autocomplete/zh_dictionary_service.dart';
import 'package:nai_launcher/core/database/datasources/translation_data_source.dart';

class _Dictionary extends ZhDictionaryService {
  _Dictionary() : super(translations: TranslationDataSource());

  ZhDictionaryState current = const ZhDictionaryState(
    isInstalled: true,
    version: 'v1',
    tagCount: 1000,
  );
  @override
  ZhDictionaryState get state => current;
  @override
  int installRevision = 0;
  void publish(ZhDictionaryState next) {
    current = next;
    notifyListeners();
  }
}

void main() {
  test(
    'translation cache survives dictionary progress but refreshes for content changes',
    () {
      final dictionary = _Dictionary();
      final container = ProviderContainer(
        overrides: [
          zhDictionaryServiceProvider.overrideWith(
            () => ZhDictionaryNotifier(dictionary),
          ),
        ],
      );
      addTearDown(container.dispose);
      final initial = container.read(tagTranslationLookupProvider);
      dictionary.publish(
        dictionary.state.copyWith(
          isBusy: true,
          progress: 0.5,
          updateAvailable: true,
        ),
      );
      expect(container.read(tagTranslationLookupProvider), same(initial));
      dictionary.publish(
        dictionary.state.copyWith(version: 'v2', isBusy: false),
      );
      final updated = container.read(tagTranslationLookupProvider);
      expect(updated, isNot(same(initial)));
      dictionary.installRevision++;
      dictionary.publish(dictionary.state);
      final repaired = container.read(tagTranslationLookupProvider);
      expect(repaired, isNot(same(updated)));
      dictionary.publish(const ZhDictionaryState());
      expect(
        container.read(tagTranslationLookupProvider),
        isNot(same(repaired)),
      );
    },
  );
}
