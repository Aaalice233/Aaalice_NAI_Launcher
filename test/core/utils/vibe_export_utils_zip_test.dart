import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/vibe_export_utils.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';

void main() {
  test(
    'buildVibeZipArchiveBytes packs selected entries as unique files',
    () async {
      final entries = [
        _entry(id: 'entry-a', name: 'Same', encoding: 'encoded-a'),
        _entry(id: 'entry-b', name: 'Same', encoding: 'encoded-b'),
      ];

      final zipBytes = await VibeExportUtils.buildVibeZipArchiveBytes(entries);
      final archive = ZipDecoder().decodeBytes(zipBytes);

      expect(
        archive.files.map((file) => file.name),
        containsAll(<String>['Same.naiv4vibe', 'Same (1).naiv4vibe']),
      );

      final firstFile = archive.findFile('Same.naiv4vibe');
      expect(firstFile, isNotNull);

      final json =
          jsonDecode(utf8.decode((firstFile!.content as List<int>).cast<int>()))
              as Map<String, dynamic>;
      expect(json['identifier'], 'novelai-vibe-transfer');
      expect(json['name'], 'Same');
      expect(
        json['encodings']['nai-diffusion-4-full']['vibe']['encoding'],
        'encoded-a',
      );
    },
  );
}

VibeLibraryEntry _entry({
  required String id,
  required String name,
  required String encoding,
}) {
  return VibeLibraryEntry(
    id: id,
    name: name,
    vibeDisplayName: name,
    vibeEncoding: encoding,
    sourceTypeIndex: VibeSourceType.naiv4vibe.index,
    createdAt: DateTime(2026),
  );
}
