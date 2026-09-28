import 'dart:io';

import 'package:path/path.dart' as p;

import '../../core/utils/app_logger.dart';
import '../../core/utils/vibe_file_parser.dart';
import '../models/vibe/vibe_library_entry.dart';
import '../models/vibe/vibe_reference.dart';
import 'vibe_file_storage_protocol.dart';
import 'vibe_file_storage_types.dart';

/// Reconciles the Vibe document folder with library entries.
class VibeFolderSync {
  VibeFolderSync(this._repository);

  static const _bundleFileExtension = '.naiv4vibebundle';
  static const _tag = 'VibeFileStorage';
  final VibeFileRepositoryProtocol _repository;

  Future<VibeFolderSyncResult> syncFolderToHive({
    required List<VibeLibraryEntry> existingEntries,
    required Future<void> Function(VibeLibraryEntry entry) onUpsertEntry,
    Future<void> Function(VibeLibraryEntry entry)? onDeleteEntry,
  }) async {
    final errors = <String>[];
    var scannedCount = 0;
    var upsertedCount = 0;
    var deletedCount = 0;
    var failedCount = 0;

    final existingPathMap = <String, VibeLibraryEntry>{
      for (final entry in existingEntries)
        if (entry.filePath != null && entry.filePath!.isNotEmpty)
          _normalizePath(entry.filePath!): entry,
    };

    final currentPathSet = <String>{};
    final files = await _repository.listVibeFiles();

    // 分批并行处理文件，避免同时打开太多文件句柄
    const batchSize = 4;
    final fileList = files.whereType<File>().toList();

    for (var i = 0; i < fileList.length; i += batchSize) {
      final batch = fileList.sublist(
        i,
        i + batchSize > fileList.length ? fileList.length : i + batchSize,
      );

      // 并行处理当前批次
      final batchResults = await Future.wait(
        batch.map((entity) async {
          final filePath = entity.path;
          final normalizedPath = _normalizePath(filePath);

          try {
            final existingEntry = existingPathMap[normalizedPath];
            final discovered = await _buildEntryFromFile(
              filePath,
              existingEntry,
            );

            return (
              path: normalizedPath,
              entry: discovered,
              error: discovered == null ? '解析失败: $filePath' : null,
            );
          } catch (e, stackTrace) {
            AppLogger.e('同步文件到 Hive 条目失败: $filePath', e, stackTrace, _tag);
            return (
              path: normalizedPath,
              entry: null,
              error: '同步失败: $filePath, error: $e',
            );
          }
        }),
      );

      // 处理批次结果
      for (final result in batchResults) {
        scannedCount++;
        currentPathSet.add(result.path);

        if (result.error != null) {
          failedCount++;
          errors.add(result.error!);
        } else if (result.entry != null) {
          await onUpsertEntry(result.entry!);
          upsertedCount++;
        }
      }
    }

    // 删除已不存在的条目
    if (onDeleteEntry != null) {
      for (final entry in existingEntries) {
        final filePath = entry.filePath;
        if (filePath == null || filePath.isEmpty) continue;

        final normalizedPath = _normalizePath(filePath);
        if (currentPathSet.contains(normalizedPath)) continue;

        try {
          await onDeleteEntry(entry);
          deletedCount++;
        } catch (e, stackTrace) {
          failedCount++;
          errors.add('删除失效条目失败: $filePath, error: $e');
          AppLogger.e('删除失效条目失败: $filePath', e, stackTrace, _tag);
        }
      }
    }

    return VibeFolderSyncResult(
      scannedCount: scannedCount,
      upsertedCount: upsertedCount,
      deletedCount: deletedCount,
      failedCount: failedCount,
      errors: errors,
    );
  }

  Future<VibeLibraryEntry?> _buildEntryFromFile(
    String filePath,
    VibeLibraryEntry? existingEntry,
  ) async {
    try {
      final extension = p.extension(filePath).toLowerCase();
      final fallbackName = p.basenameWithoutExtension(filePath);

      if (extension == _bundleFileExtension) {
        return await _buildBundleEntryFromFile(
          filePath,
          fallbackName,
          existingEntry,
        );
      }

      final vibe = await _repository.loadVibeFromFile(filePath);
      if (vibe == null) return null;

      return _mergeWithExistingEntry(
        generatedEntry: _buildSingleEntry(filePath, fallbackName, vibe),
        existingEntry: existingEntry,
        filePath: filePath,
      );
    } catch (e, stackTrace) {
      AppLogger.e('构建条目失败: $filePath', e, stackTrace, _tag);
      return null;
    }
  }

  Future<VibeLibraryEntry?> _buildBundleEntryFromFile(
    String filePath,
    String fallbackName,
    VibeLibraryEntry? existingEntry,
  ) async {
    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final vibes = await VibeFileParser.fromBundle(p.basename(filePath), bytes);
    if (vibes.isEmpty) return null;

    final previews = await _repository.extractPreviewsFromBundle(filePath);
    final names = vibes.map((item) => item.displayName).toList(growable: false);
    final generatedEntry = _buildBundleEntry(filePath, fallbackName, vibes);

    final encodings = vibes.map((v) => v.vibeEncoding).toList(growable: false);
    final strengths = vibes.map((v) => v.strength).toList(growable: false);
    final infoExtracted = vibes
        .map((v) => v.infoExtracted)
        .toList(growable: false);
    final encodingModels = vibes
        .map((v) => v.encodingModel)
        .toList(growable: false);

    return _mergeWithExistingEntry(
      generatedEntry: generatedEntry,
      existingEntry: existingEntry,
      filePath: filePath,
    ).copyWith(
      bundleId: p.basenameWithoutExtension(filePath),
      bundledVibeNames: names,
      bundledVibePreviews: previews.isEmpty ? null : previews,
      bundledVibeEncodings: encodings,
      bundledVibeStrengths: strengths,
      bundledVibeInfoExtracted: infoExtracted,
      bundledVibeEncodingModels: encodingModels,
    );
  }

  VibeLibraryEntry _buildBundleEntry(
    String filePath,
    String fileName,
    List<VibeReference> references,
  ) {
    final firstVibe = references.first;

    return VibeLibraryEntry.fromVibeReference(
      name: fileName,
      vibeData: firstVibe,
      thumbnail: firstVibe.thumbnail,
      filePath: filePath,
      isFavorite: false,
    );
  }

  VibeLibraryEntry _buildSingleEntry(
    String filePath,
    String fileName,
    VibeReference reference,
  ) {
    return VibeLibraryEntry.fromVibeReference(
      name: fileName,
      vibeData: reference,
      thumbnail: reference.thumbnail,
      filePath: filePath,
      isFavorite: false,
    );
  }

  VibeLibraryEntry _mergeWithExistingEntry({
    required VibeLibraryEntry generatedEntry,
    required VibeLibraryEntry? existingEntry,
    required String filePath,
  }) {
    if (existingEntry == null) {
      return generatedEntry.copyWith(filePath: filePath);
    }

    // 保留用户设置的元数据，但 name 保持与文件名一致（用户可以通过重命名文件来重命名条目）
    return generatedEntry.copyWith(
      id: existingEntry.id,
      categoryId: existingEntry.categoryId,
      tags: existingEntry.tags,
      isFavorite: existingEntry.isFavorite,
      usedCount: existingEntry.usedCount,
      lastUsedAt: existingEntry.lastUsedAt,
      createdAt: existingEntry.createdAt,
      thumbnail: existingEntry.thumbnail,
      filePath: filePath,
    );
  }

  String _normalizePath(String filePath) => p.normalize(filePath).toLowerCase();
}
