import 'dart:io';
import 'dart:typed_data';

import '../models/vibe/vibe_reference.dart';
import 'vibe_file_storage_types.dart';

abstract interface class VibeFileRepositoryProtocol {
  Future<String> saveVibeToFile(
    VibeReference vibe, {
    String? customName,
    String? defaultModel,
  });
  Future<void> overwriteVibeFile(
    String filePath,
    VibeReference vibe, {
    required String displayName,
    String? defaultModel,
  });
  Future<String> saveBundleToFile(
    List<VibeReference> vibes, {
    String? bundleName,
    String? defaultModel,
  });
  Future<void> overwriteBundleFile(
    String filePath,
    List<VibeReference> vibes, {
    String? defaultModel,
    bool preserveExistingData = true,
  });
  Future<VibeReference?> loadVibeFromFile(String filePath);
  Future<VibeStoredImportParams?> loadImportParams(String filePath);
  Future<bool> deleteVibeFile(String filePath);
  Future<String?> renameVibeFile(String oldPath, String newName);
  Future<List<VibeReference>> extractVibesFromBundle(
    String bundlePath, {
    int startIndex = 0,
    int? limit,
  });
  Future<VibeReference?> extractVibeFromBundle(String bundlePath, int index);
  Future<List<Uint8List>> extractPreviewsFromBundle(
    String bundlePath, {
    int maxCount = 4,
  });
  Future<List<FileSystemEntity>> listVibeFiles();
}
