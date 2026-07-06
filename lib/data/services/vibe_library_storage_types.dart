part of 'vibe_library_storage_service.dart';

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
