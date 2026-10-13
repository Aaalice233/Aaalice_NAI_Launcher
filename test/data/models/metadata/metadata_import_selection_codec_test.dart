import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/metadata/metadata_import_options.dart';
import 'package:nai_launcher/data/models/metadata/metadata_import_selection_codec.dart';

void main() {
  MetadataImportOptions roundTrip(MetadataImportOptions options) =>
      MetadataImportSelectionCodec.decode(
        MetadataImportSelectionCodec.encode(options),
      );

  Map<String, Object?> encodedMap(MetadataImportOptions options) =>
      jsonDecode(MetadataImportSelectionCodec.encode(options))
          as Map<String, Object?>;

  test('select-all and clear presets round-trip every category', () {
    expect(roundTrip(MetadataImportOptions.all()), MetadataImportOptions.all());
    expect(
      roundTrip(MetadataImportOptions.none()),
      MetadataImportOptions.none(),
    );
  });

  test('each stored key controls exactly one category', () {
    final keys = encodedMap(
      MetadataImportOptions.all(),
    ).entries.where((entry) => entry.value is bool).map((entry) => entry.key);

    for (final key in keys) {
      final decoded = MetadataImportSelectionCodec.decode(
        jsonEncode({key: false}),
      );
      final booleans = encodedMap(
        decoded,
      ).entries.where((entry) => entry.value is bool);
      expect(
        booleans.where((entry) => entry.value == false).map((e) => e.key),
        [key],
        reason: key,
      );
    }
  });

  test('mixed categories and the unknown fixed tag policy survive', () {
    final options = MetadataImportOptions.all().copyWith(
      importSeed: false,
      importNegativePrompt: false,
      importFixedNegativeSuffix: false,
      importVibeReferences: false,
      unknownFixedTagPolicy: UnknownFixedTagPolicy.keepCurrent,
    );

    expect(roundTrip(options), options);
  });

  test('per-image item selections are not persisted', () {
    final options = MetadataImportOptions.all().copyWith(
      selectedQualityTags: ['masterpiece'],
      selectedCharacterIndices: [0, 2],
      selectedVibeIndices: [1],
      selectedPreciseReferenceIndices: [0],
    );

    final decoded = roundTrip(options);

    expect(decoded.selectedQualityTags, isEmpty);
    expect(decoded.selectedCharacterIndices, isEmpty);
    expect(decoded.selectedVibeIndices, isEmpty);
    expect(decoded.selectedPreciseReferenceIndices, isEmpty);
    expect(
      decoded,
      MetadataImportOptions.all(),
      reason: 'categories must stay intact',
    );
  });

  test('missing or unreadable storage falls back to select-all', () {
    for (final raw in [null, '', 'not json', '[]', '"seed"', '42']) {
      expect(
        MetadataImportSelectionCodec.decode(raw),
        MetadataImportOptions.all(),
        reason: '$raw',
      );
    }
  });

  test('invalid entries fall back individually', () {
    final decoded = MetadataImportSelectionCodec.decode(
      jsonEncode({
        'seed': false,
        'steps': 'no',
        'prompt': 0,
        'model': null,
        'unknownFixedTagPolicy': 'bogus',
        'someFutureCategory': false,
      }),
    );

    expect(decoded, MetadataImportOptions.all().copyWith(importSeed: false));
  });
}
