import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/data/services/vibe_bulk_import_service.dart';
import 'package:nai_launcher/data/services/vibe_bulk_operation_types.dart';
import 'package:nai_launcher/data/services/vibe_library_storage_service.dart';

class _ProgressEvent {
  const _ProgressEvent({
    required this.current,
    required this.total,
    required this.isComplete,
  });

  final int current;
  final int total;
  final bool isComplete;
}

class _FakeVibeLibraryStorageService extends VibeLibraryStorageService {
  _FakeVibeLibraryStorageService({this.failName});

  final String? failName;
  final List<VibeLibraryEntry> entries = <VibeLibraryEntry>[];

  @override
  Future<List<VibeLibraryEntry>> getAllEntries() async => entries;

  @override
  Future<VibeLibraryEntry?> findEntryByName(String name) async {
    for (final entry in entries) {
      if (entry.name == name) return entry;
    }
    return null;
  }

  @override
  Future<VibeLibraryEntry> saveEntry(VibeLibraryEntry entry) async {
    if (entry.name == failName) {
      throw StateError('save failed for ${entry.name}');
    }
    entries.add(entry);
    return entry;
  }

  @override
  Future<VibeLibraryEntry> saveBundleEntry(
    List<VibeReference> vibes, {
    required String name,
    String? categoryId,
    List<String>? tags,
    VibeLibraryEntry? replaceEntry,
  }) async {
    throw UnsupportedError('The test imports bundles as separate entries');
  }
}

Uint8List _bundleBytes(List<String> names) {
  return Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'identifier': 'novelai-vibe-transfer-bundle',
        'version': 1,
        'vibes': [
          for (final name in names)
            {
              'name': name,
              'encodings': {
                'nai-diffusion-4-full': {
                  'vibe': {'encoding': 'encoding-$name'},
                },
              },
            },
        ],
      }),
    ),
  );
}

void _expectStableProgress(List<_ProgressEvent> events) {
  expect(events, isNotEmpty);
  expect(events.map((event) => event.total).toSet(), hasLength(1));
  for (var i = 1; i < events.length; i++) {
    expect(events[i].current, greaterThanOrEqualTo(events[i - 1].current));
  }
  expect(events.where((event) => event.isComplete), hasLength(1));
  expect(events.last.isComplete, isTrue);
  expect(events.last.current, events.last.total);
}

void main() {
  group('VibeBulkImportService progress', () {
    test(
      'keeps one parsed-result unit across bundles, parse failures, and save failures',
      () async {
        final storage = _FakeVibeLibraryStorageService(failName: 'second');
        final service = VibeBulkImportService(storage);
        final validBundle = _bundleBytes(['first', 'second']);
        final emptyBundle = _bundleBytes(const []);
        final events = <_ProgressEvent>[];

        final result = await service.importFiles(
          [
            PlatformFile(
              name: 'batch.naiv4vibebundle',
              size: validBundle.length,
              bytes: validBundle,
            ),
            PlatformFile(
              name: 'empty.naiv4vibebundle',
              size: emptyBundle.length,
              bytes: emptyBundle,
            ),
            PlatformFile(
              name: 'broken.naiv4vibe',
              size: 3,
              bytes: Uint8List.fromList([1, 2, 3]),
            ),
          ],
          onProgress:
              ({
                required current,
                required total,
                required currentItem,
                required operationType,
                required isComplete,
              }) {
                expect(operationType, VibeBulkOperationType.import);
                events.add(
                  _ProgressEvent(
                    current: current,
                    total: total,
                    isComplete: isComplete,
                  ),
                );
              },
        );

        expect(result.successCount, 1);
        expect(result.failedCount, 3);
        expect(events.map((event) => event.current), [1, 2, 3, 4]);
        _expectStableProgress(events);
      },
    );

    test(
      'emits exactly one completed zero-total event for an empty import',
      () async {
        final service = VibeBulkImportService(_FakeVibeLibraryStorageService());
        final events = <_ProgressEvent>[];

        final result = await service.importFiles(
          const [],
          onProgress:
              ({
                required current,
                required total,
                required currentItem,
                required operationType,
                required isComplete,
              }) {
                events.add(
                  _ProgressEvent(
                    current: current,
                    total: total,
                    isComplete: isComplete,
                  ),
                );
              },
        );

        expect(result.totalCount, 0);
        expect(events, hasLength(1));
        _expectStableProgress(events);
      },
    );
  });
}
