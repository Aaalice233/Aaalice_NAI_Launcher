part of 'vibe_library_storage_service.dart';

/// 详情页一次加载所需的完整条目和 Bundle 子项。
///
/// Bundle 子项只在详情页生命周期内持有，不写入 Hive，避免为了切换预览图
/// 再次读取和解析整份 Bundle 文件。
class VibeLibraryDetailData {
  const VibeLibraryDetailData({
    required this.entry,
    this.bundleVibes = const [],
  });

  final VibeLibraryEntry entry;
  final List<VibeReference> bundleVibes;
}

enum VibeEntryRenameError {
  invalidName,
  entryNotFound,
  nameConflict,
  filePathMissing,
  fileRenameFailed,
}

class VibeEntryRenameResult {
  const VibeEntryRenameResult._({this.entry, this.error});

  const VibeEntryRenameResult.success(VibeLibraryEntry entry)
    : this._(entry: entry);

  const VibeEntryRenameResult.failure(VibeEntryRenameError error)
    : this._(error: error);

  final VibeLibraryEntry? entry;
  final VibeEntryRenameError? error;

  bool get isSuccess => entry != null;
}
