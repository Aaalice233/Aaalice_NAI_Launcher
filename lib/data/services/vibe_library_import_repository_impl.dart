import '../models/vibe/vibe_library_entry.dart';
import 'vibe_import_service.dart';

/// VibeLibraryNotifier 的导入仓库适配器
/// 实现 VibeLibraryImportRepository 接口以适配 VibeImportService
class VibeLibraryNotifierImportRepository implements VibeLibraryImportRepository {
  VibeLibraryNotifierImportRepository({
    required this.onGetAllEntries,
    required this.onSaveEntry,
  });

  final Future<List<VibeLibraryEntry>> Function() onGetAllEntries;
  final Future<VibeLibraryEntry?> Function(VibeLibraryEntry) onSaveEntry;

  @override
  Future<List<VibeLibraryEntry>> getAllEntries() async {
    return onGetAllEntries();
  }

  @override
  Future<VibeLibraryEntry> saveEntry(VibeLibraryEntry entry) async {
    final saved = await onSaveEntry(entry);
    if (saved == null) {
      throw StateError('Failed to save entry: ${entry.name}');
    }
    return saved;
  }
}
