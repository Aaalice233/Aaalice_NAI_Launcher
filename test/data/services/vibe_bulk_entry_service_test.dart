import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/models/vibe/vibe_reference.dart';
import 'package:nai_launcher/data/services/vibe_bulk_entry_service.dart';
import 'package:nai_launcher/data/services/vibe_library_storage_service.dart';

void main() {
  test('读取和操作异常按项记录，并按已完成数量报告进度', () async {
    final progress = <({int current, bool complete})>[];
    final result = await VibeBulkEntryService(_FailingBulkStorageService())
        .delete(
          ['read-failure', 'operation-failure', 'success'],
          onProgress:
              ({
                required current,
                required total,
                required currentItem,
                required operationType,
                required isComplete,
              }) {
                progress.add((current: current, complete: isComplete));
              },
        );

    expect(result.successCount, 1);
    expect(result.failedCount, 2);
    expect(result.errors, hasLength(2));
    expect(result.errors.first.itemName, 'read-failure');
    expect(result.errors.first.details, contains('read failed'));
    expect(result.errors.last.itemName, 'Operation failure');
    expect(result.errors.last.details, contains('delete failed'));
    expect(progress, [
      (current: 1, complete: false),
      (current: 2, complete: false),
      (current: 3, complete: false),
      (current: 3, complete: true),
    ]);
  });
}

class _FailingBulkStorageService extends VibeLibraryStorageService {
  @override
  Future<VibeLibraryEntry?> getEntry(String id) async {
    if (id == 'read-failure') throw StateError('read failed');
    return _entry(id);
  }

  @override
  Future<bool> deleteEntry(String id) async {
    if (id == 'operation-failure') throw StateError('delete failed');
    return true;
  }
}

VibeLibraryEntry _entry(String id) => VibeLibraryEntry(
  id: id,
  name: id == 'operation-failure' ? 'Operation failure' : id,
  vibeDisplayName: id == 'operation-failure' ? 'Operation failure' : id,
  vibeEncoding: 'encoding',
  strength: 0.6,
  infoExtracted: 0.7,
  sourceTypeIndex: VibeSourceType.naiv4vibe.index,
  createdAt: DateTime(2026),
);
