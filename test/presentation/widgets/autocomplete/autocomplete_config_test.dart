import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/widgets/autocomplete/autocomplete_config.dart';

void main() {
  group('AutocompleteConfig.insertsSpacedTags', () {
    test('prompt fields follow the user preference', () {
      const config = AutocompleteConfig();

      expect(
        config.insertsSpacedTags(text: 'blu', userPreference: true),
        isTrue,
      );
      expect(
        config.insertsSpacedTags(text: 'blu', userPreference: false),
        isFalse,
      );
    });

    test('space-separated fields always insert canonical tags', () {
      const config = AutocompleteConfig(treatSpacesAsSeparators: true);

      expect(
        config.insertsSpacedTags(text: 'blu', userPreference: true),
        isFalse,
      );
      expect(
        config.insertsSpacedTags(text: 'blu', userPreference: false),
        isFalse,
      );
    });
  });
}
