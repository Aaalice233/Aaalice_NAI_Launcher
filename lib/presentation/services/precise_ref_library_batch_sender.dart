import 'dart:typed_data';

import '../../data/models/precise_ref/precise_ref_library_entry.dart';

class PreciseRefLibraryBatchSendResult {
  const PreciseRefLibraryBatchSendResult({
    required this.successfulEntries,
    required this.failedEntries,
    required this.usageRecordFailures,
  });

  final List<PreciseRefLibraryEntry> successfulEntries;
  final List<PreciseRefLibraryEntry> failedEntries;
  final List<PreciseRefLibraryEntry> usageRecordFailures;
}

class PreciseRefLibraryBatchSender {
  const PreciseRefLibraryBatchSender();

  Future<PreciseRefLibraryBatchSendResult> send({
    required Iterable<PreciseRefLibraryEntry> orderedEntries,
    required Set<String> selectedIds,
    required Future<Uint8List?> Function(String id) loadBytes,
    required Future<void> Function(
      Uint8List bytes,
      PreciseRefLibraryEntry entry,
    )
    sendEntry,
    required Future<void> Function(String id) recordUsage,
  }) async {
    final successful = <PreciseRefLibraryEntry>[];
    final failed = <PreciseRefLibraryEntry>[];
    final usageRecordFailures = <PreciseRefLibraryEntry>[];
    for (final entry in orderedEntries) {
      if (!selectedIds.contains(entry.id)) continue;
      try {
        final bytes = await loadBytes(entry.id);
        if (bytes == null || bytes.isEmpty) {
          failed.add(entry);
          continue;
        }
        await sendEntry(bytes, entry);
        successful.add(entry);
        try {
          await recordUsage(entry.id);
        } on Object {
          usageRecordFailures.add(entry);
        }
      } on Object {
        failed.add(entry);
      }
    }
    return PreciseRefLibraryBatchSendResult(
      successfulEntries: successful,
      failedEntries: failed,
      usageRecordFailures: usageRecordFailures,
    );
  }
}
