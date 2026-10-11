import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/data/services/vibe_display_cache_repository.dart';
import 'package:nai_launcher/data/services/vibe_file_storage_service.dart';
import 'package:nai_launcher/data/services/vibe_library_entry_reader.dart';
import 'package:nai_launcher/data/services/vibe_library_storage_protocol.dart';

class _MockEntry extends Mock implements VibeLibraryEntry {}

class _MockRepository extends Mock implements VibeLibraryRepositoryProtocol {}

class _MockFiles extends Mock implements VibeFileStorageService {}

class _MockDisplayCache extends Mock implements VibeDisplayCacheRepository {}

typedef _EntryTest = bool Function(VibeLibraryEntry);

_MockEntry _probeEntry({required String name, required String encoding}) {
  final entry = _MockEntry();
  when(() => entry.displayName).thenReturn(name);
  when(() => entry.vibeEncoding).thenReturn(encoding);
  when(() => entry.rawImageData).thenReturn(Uint8List(64));
  return entry;
}

VibeLibraryEntry _libraryEntry({
  required String id,
  String name = 'Library Vibe',
  String encoding = 'encoded-before',
  Uint8List? rawImageData,
  Uint8List? thumbnail,
}) => VibeLibraryEntry(
  id: id,
  name: name,
  vibeDisplayName: name,
  vibeEncoding: encoding,
  thumbnail: thumbnail,
  rawImageData: rawImageData,
  strength: 0.6,
  infoExtracted: 0.2,
  sourceTypeIndex: VibeSourceType.naiv4vibe.index,
  createdAt: DateTime(2026, 4, 15),
);

void main() {
  setUpAll(() {
    registerFallbackValue((VibeLibraryEntry _) => false);
  });

  group('isVibeOverwriteCandidate', () {
    test('名称不同或编码相同时不读取原图字节', () {
      final vibe = VibeReference(
        displayName: 'Vibe',
        vibeEncoding: 'encoded',
        rawImageData: Uint8List(64),
      );
      final otherName = _probeEntry(name: 'Other', encoding: 'different');
      final sameEncoding = _probeEntry(name: 'Vibe', encoding: 'encoded');

      expect(isVibeOverwriteCandidate(otherName, vibe), isFalse);
      expect(isVibeOverwriteCandidate(sameEncoding, vibe), isTrue);
      verifyNever(() => otherName.rawImageData);
      verifyNever(() => sameEncoding.rawImageData);
    });

    test('同名但编码不同时按原图内容判定', () {
      final raw = Uint8List.fromList(List.generate(48, (i) => i));
      VibeReference vibeWith(Uint8List? bytes) => VibeReference(
        displayName: 'Library Vibe',
        vibeEncoding: 'encoded-after',
        rawImageData: bytes,
      );
      final entry = _libraryEntry(id: 'entry', rawImageData: raw);
      final sameLengthOtherContent = Uint8List.fromList(raw)..[40] ^= 0xff;

      expect(
        isVibeOverwriteCandidate(entry, vibeWith(Uint8List.fromList(raw))),
        isTrue,
      );
      expect(
        isVibeOverwriteCandidate(entry, vibeWith(sameLengthOtherContent)),
        isFalse,
      );
      expect(isVibeOverwriteCandidate(entry, vibeWith(Uint8List(47))), isFalse);
      expect(isVibeOverwriteCandidate(entry, vibeWith(null)), isFalse);
      expect(
        isVibeOverwriteCandidate(_libraryEntry(id: 'no-raw'), vibeWith(null)),
        isTrue,
      );
    });
  });

  group('VibeLibraryEntryReader', () {
    late _MockRepository repository;
    late VibeLibraryEntryReader reader;
    var entries = <VibeLibraryEntry>[];

    setUp(() {
      repository = _MockRepository();
      reader = VibeLibraryEntryReader(
        repository,
        _MockFiles(),
        _MockDisplayCache(),
      );
      entries = [];
      when(() => repository.firstEntryWhere(any())).thenAnswer((invocation) {
        final test = invocation.positionalArguments.single as _EntryTest;
        for (final entry in entries) {
          if (test(entry)) return Future.value(entry);
        }
        return Future.value();
      });
    });

    test('单个来自库的 Vibe 会匹配到可覆盖的原始条目', () async {
      final imageBytes = Uint8List.fromList(const [1, 2, 3, 4]);
      final entry = _libraryEntry(
        id: 'library-entry',
        rawImageData: imageBytes,
        thumbnail: imageBytes,
      );
      entries = [entry];

      final candidate = await reader.findOverwriteCandidate([
        entry.toVibeReference(),
      ]);

      expect(candidate?.id, 'library-entry');
    });

    test('多个 Vibe 保存到库时不会显示覆盖原条目的入口', () async {
      final entry = _libraryEntry(
        id: 'library-entry',
        rawImageData: Uint8List.fromList(const [1, 2, 3, 4]),
      );
      entries = [entry];

      final candidate = await reader.findOverwriteCandidate([
        entry.toVibeReference(),
        entry.toVibeReference().copyWith(displayName: 'Other'),
      ]);

      expect(candidate, isNull);
      verifyNever(() => repository.firstEntryWhere(any()));
    });

    test('遍历整个库时只为同名且编码不同的条目读取原图', () async {
      final otherName = _probeEntry(name: 'Other', encoding: 'different');
      final sameEncoding = _probeEntry(name: 'Vibe', encoding: 'encoded');
      entries = [otherName, sameEncoding];

      final candidate = await reader.findOverwriteCandidate([
        VibeReference(
          displayName: 'Vibe',
          vibeEncoding: 'encoded',
          rawImageData: Uint8List(64),
        ),
      ]);

      expect(candidate, same(sameEncoding));
      verifyNever(() => otherName.rawImageData);
      verifyNever(() => sameEncoding.rawImageData);
    });

    test('无编码的 Vibe 按缩略图内容匹配库条目', () async {
      final thumbnail = Uint8List.fromList(List.generate(40, (i) => i * 3));
      final sameLength = Uint8List.fromList(thumbnail)..[39] ^= 0x01;
      entries = [
        _libraryEntry(id: 'other', thumbnail: sameLength),
        _libraryEntry(id: 'match', thumbnail: Uint8List.fromList(thumbnail)),
      ];

      final match = await reader.findMatching(
        VibeReference(
          displayName: 'Dropped',
          vibeEncoding: '',
          thumbnail: thumbnail,
        ),
      );

      expect(match?.id, 'match');
    });
  });
}
