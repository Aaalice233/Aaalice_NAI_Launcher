import 'dart:io';
import 'dart:typed_data';

import '../models/vibe/vibe_library_entry.dart';
import '../models/vibe/vibe_reference.dart';
import 'vibe_file_repository.dart';
import 'vibe_file_storage_protocol.dart';
import 'vibe_file_storage_types.dart';
import 'vibe_folder_sync.dart';
import 'vibe_portable_file_store.dart';

export 'vibe_file_storage_types.dart';

/// Backward-compatible file storage facade.
///
/// The class intentionally remains concrete and its methods remain overridable
/// so existing providers, test fakes, and downstream integrations keep working.
class VibeFileStorageService {
  VibeFileStorageService({
    VibeFileRepositoryProtocol? repository,
    VibeFolderSync? folderSync,
    VibePortableFileStore? portableFiles,
  }) : _repository = repository ?? VibeFileRepository(),
       _injectedFolderSync = folderSync,
       _portableFiles = portableFiles ?? VibePortableFileStore();

  final VibeFileRepositoryProtocol _repository;
  final VibeFolderSync? _injectedFolderSync;
  final VibePortableFileStore _portableFiles;

  VibeFolderSync get _folderSync =>
      _injectedFolderSync ?? VibeFolderSync(_repository);

  Future<String> saveVibeToFile(
    VibeReference vibe, {
    String? customName,
    String? defaultModel,
  }) => _repository.saveVibeToFile(
    vibe,
    customName: customName,
    defaultModel: defaultModel,
  );

  Future<void> overwriteVibeFile(
    String filePath,
    VibeReference vibe, {
    required String displayName,
    String? defaultModel,
  }) => _repository.overwriteVibeFile(
    filePath,
    vibe,
    displayName: displayName,
    defaultModel: defaultModel,
  );

  Future<String> saveBundleToFile(
    List<VibeReference> vibes, {
    String? bundleName,
    String? defaultModel,
  }) => _repository.saveBundleToFile(
    vibes,
    bundleName: bundleName,
    defaultModel: defaultModel,
  );

  Future<void> overwriteBundleFile(
    String filePath,
    List<VibeReference> vibes, {
    String? defaultModel,
    bool preserveExistingData = true,
  }) => _repository.overwriteBundleFile(
    filePath,
    vibes,
    defaultModel: defaultModel,
    preserveExistingData: preserveExistingData,
  );

  Future<VibeReference?> loadVibeFromFile(String filePath) =>
      _repository.loadVibeFromFile(filePath);

  Future<VibeStoredImportParams?> loadImportParams(String filePath) =>
      _repository.loadImportParams(filePath);

  Future<bool> deleteVibeFile(String filePath) =>
      _repository.deleteVibeFile(filePath);

  Future<String?> renameVibeFile(String oldPath, String newName) =>
      _repository.renameVibeFile(oldPath, newName);

  Future<List<VibeReference>> extractVibesFromBundle(
    String bundlePath, {
    int startIndex = 0,
    int? limit,
  }) => _repository.extractVibesFromBundle(
    bundlePath,
    startIndex: startIndex,
    limit: limit,
  );

  Future<VibeReference?> extractVibeFromBundle(String bundlePath, int index) =>
      _repository.extractVibeFromBundle(bundlePath, index);

  Future<List<Uint8List>> extractPreviewsFromBundle(
    String bundlePath, {
    int maxCount = 4,
  }) => _repository.extractPreviewsFromBundle(bundlePath, maxCount: maxCount);

  Future<List<FileSystemEntity>> listVibeFiles() => _repository.listVibeFiles();

  Future<int> portableFileLength(String filePath) =>
      _portableFiles.fileLength(filePath);

  Future<bool> portableFileExists(String filePath) =>
      _portableFiles.exists(filePath);

  Stream<List<int>> openPortableFile(String filePath) =>
      _portableFiles.openRead(filePath);

  Future<String> importPortableFile(
    Stream<List<int>> bytes, {
    required String fileName,
  }) => _portableFiles.import(bytes, fileName: fileName);

  Future<bool> deletePortableFile(String filePath) =>
      _repository.deleteVibeFile(filePath);

  Future<VibeFolderSyncResult> syncFolderToHive({
    required List<VibeLibraryEntry> existingEntries,
    required Future<void> Function(VibeLibraryEntry entry) onUpsertEntry,
    Future<void> Function(VibeLibraryEntry entry)? onDeleteEntry,
  }) => _folderSync.syncFolderToHive(
    existingEntries: existingEntries,
    onUpsertEntry: onUpsertEntry,
    onDeleteEntry: onDeleteEntry,
  );
}
