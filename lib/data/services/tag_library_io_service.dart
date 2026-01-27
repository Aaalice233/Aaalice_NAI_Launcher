import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../models/tag_library/import_models.dart';
import '../models/tag_library/tag_library_category.dart';
import '../models/tag_library/tag_library_entry.dart';

/// 词库导入导出服务
class TagLibraryIOService {
  /// 导出词库到 ZIP 文件
  Future<File> exportLibrary({
    required List<TagLibraryEntry> entries,
    required List<TagLibraryCategory> categories,
    required bool includeThumbnails,
    required String outputPath,
    void Function(double progress, String message)? onProgress,
  }) async {
    final archive = Archive();
    final totalSteps = entries.length + 2; // entries + manifest + categories
    var currentStep = 0;

    // 创建 manifest
    onProgress?.call(0, '创建清单...');
    final manifest = ExportManifest(
      version: '1.0',
      exportDate: DateTime.now(),
      appVersion: '1.0.0',
      entryCount: entries.length,
      categoryCount: categories.length,
      includeThumbnails: includeThumbnails,
    );
    final manifestJson = jsonEncode(manifest.toJson());
    archive.addFile(
      ArchiveFile(
        'manifest.json',
        manifestJson.length,
        utf8.encode(manifestJson),
      ),
    );
    currentStep++;
    onProgress?.call(currentStep / totalSteps, '已创建清单');

    // 导出分类
    onProgress?.call(currentStep / totalSteps, '导出分类...');
    final categoriesJson =
        jsonEncode(categories.map((c) => c.toJson()).toList());
    archive.addFile(
      ArchiveFile(
        'categories.json',
        categoriesJson.length,
        utf8.encode(categoriesJson),
      ),
    );
    currentStep++;
    onProgress?.call(currentStep / totalSteps, '已导出分类');

    // 导出条目
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      onProgress?.call(
        currentStep / totalSteps,
        '导出条目: ${entry.displayName}',
      );

      // 导出条目 JSON
      final entryJson = jsonEncode(entry.toJson());
      archive.addFile(
        ArchiveFile(
          'entries/${entry.id}.json',
          entryJson.length,
          utf8.encode(entryJson),
        ),
      );

      // 导出预览图
      if (includeThumbnails && entry.hasThumbnail) {
        final thumbnailFile = File(entry.thumbnail!);
        if (await thumbnailFile.exists()) {
          final thumbnailBytes = await thumbnailFile.readAsBytes();
          final ext = path.extension(entry.thumbnail!);
          archive.addFile(
            ArchiveFile(
              'thumbnails/${entry.id}$ext',
              thumbnailBytes.length,
              thumbnailBytes,
            ),
          );
        }
      }

      currentStep++;
    }

    onProgress?.call(1.0, '正在压缩...');

    // 压缩并保存
    final zipEncoder = ZipEncoder();
    final zipData = zipEncoder.encode(archive);
    if (zipData == null) {
      throw Exception('压缩失败');
    }

    final outputFile = File(outputPath);
    await outputFile.writeAsBytes(zipData);

    onProgress?.call(1.0, '导出完成');
    return outputFile;
  }

  /// 解析导入文件
  Future<ImportPreview> parseImportFile(File zipFile) async {
    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // 读取 manifest
    final manifestFile = archive.findFile('manifest.json');
    if (manifestFile == null) {
      throw Exception('无效的词库文件：缺少 manifest.json');
    }
    final manifestJson = utf8.decode(manifestFile.content as List<int>);
    final manifestData = jsonDecode(manifestJson) as Map<String, dynamic>;

    // 读取分类
    final categoriesFile = archive.findFile('categories.json');
    List<TagLibraryCategory> categories = [];
    if (categoriesFile != null) {
      final categoriesJson = utf8.decode(categoriesFile.content as List<int>);
      final categoriesData = jsonDecode(categoriesJson) as List<dynamic>;
      categories = categoriesData
          .map((c) => TagLibraryCategory.fromJson(Map<String, dynamic>.from(c)))
          .toList();
    }

    // 读取条目
    final entries = <TagLibraryEntry>[];
    for (final file in archive.files) {
      if (file.name.startsWith('entries/') && file.name.endsWith('.json')) {
        final entryJson = utf8.decode(file.content as List<int>);
        final entryData = jsonDecode(entryJson) as Map<String, dynamic>;
        entries.add(TagLibraryEntry.fromJson(entryData));
      }
    }

    // 检查是否有预览图
    final hasThumbnails =
        archive.files.any((f) => f.name.startsWith('thumbnails/'));

    return ImportPreview(
      version: manifestData['version'] as String? ?? '1.0',
      exportDate:
          DateTime.tryParse(manifestData['exportDate'] as String? ?? '') ??
              DateTime.now(),
      appVersion: manifestData['appVersion'] as String?,
      entries: entries,
      categories: categories,
      hasThumbnails: hasThumbnails,
    );
  }

  /// 检测冲突
  Future<List<ImportConflict>> detectConflicts(
    ImportPreview preview,
    List<TagLibraryEntry> existingEntries,
    List<TagLibraryCategory> existingCategories,
  ) async {
    final conflicts = <ImportConflict>[];

    // 检测条目冲突（按名称）
    for (final importEntry in preview.entries) {
      final existing = existingEntries.cast<TagLibraryEntry?>().firstWhere(
            (e) => e?.name.toLowerCase() == importEntry.name.toLowerCase(),
            orElse: () => null,
          );
      if (existing != null) {
        conflicts.add(
          ImportConflict(
            type: ConflictType.entry,
            importName: importEntry.displayName,
            importId: importEntry.id,
            importContentPreview: importEntry.contentPreview,
            existingId: existing.id,
            existingContentPreview: existing.contentPreview,
          ),
        );
      }
    }

    // 检测分类冲突（按名称和父级）
    for (final importCategory in preview.categories) {
      final existing = existingCategories
          .cast<TagLibraryCategory?>()
          .firstWhere(
            (c) =>
                c?.name.toLowerCase() == importCategory.name.toLowerCase() &&
                c?.parentId == importCategory.parentId,
            orElse: () => null,
          );
      if (existing != null) {
        conflicts.add(
          ImportConflict(
            type: ConflictType.category,
            importName: importCategory.displayName,
            importId: importCategory.id,
            existingId: existing.id,
          ),
        );
      }
    }

    return conflicts;
  }

  /// 执行导入
  Future<ImportResult> executeImport({
    required File zipFile,
    required ImportPreview preview,
    required Set<String> selectedEntryIds,
    required Set<String> selectedCategoryIds,
    required Map<String, ConflictResolution> conflictResolutions,
    required List<TagLibraryEntry> existingEntries,
    required List<TagLibraryCategory> existingCategories,
    void Function(double progress, String message)? onProgress,
  }) async {
    var importedEntries = 0;
    var importedCategories = 0;
    var skippedConflicts = 0;
    var overwrittenCount = 0;
    var renamedCount = 0;
    final errors = <String>[];

    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    // 获取应用文档目录用于保存预览图
    final appDir = await getApplicationDocumentsDirectory();
    final thumbnailsDir =
        Directory(path.join(appDir.path, 'tag_library_thumbnails'));
    if (!await thumbnailsDir.exists()) {
      await thumbnailsDir.create(recursive: true);
    }

    final totalSteps = selectedEntryIds.length + selectedCategoryIds.length;
    var currentStep = 0;

    // 创建分类 ID 映射（旧 ID -> 新 ID）
    final categoryIdMapping = <String, String>{};

    // 导入分类
    for (final category in preview.categories) {
      if (!selectedCategoryIds.contains(category.id)) continue;

      onProgress?.call(
        currentStep / totalSteps,
        '导入分类: ${category.displayName}',
      );

      final resolution = conflictResolutions[category.id];
      if (resolution == ConflictResolution.skip) {
        skippedConflicts++;
        // 找到现有分类的 ID 用于映射
        final existing =
            existingCategories.cast<TagLibraryCategory?>().firstWhere(
                  (c) =>
                      c?.name.toLowerCase() == category.name.toLowerCase() &&
                      c?.parentId == category.parentId,
                  orElse: () => null,
                );
        if (existing != null) {
          categoryIdMapping[category.id] = existing.id;
        }
      } else if (resolution == ConflictResolution.overwrite) {
        overwrittenCount++;
        categoryIdMapping[category.id] = category.id;
      } else {
        // 新建或重命名
        String newName = category.name;
        if (resolution == ConflictResolution.rename) {
          newName = '${category.name} (导入)';
          renamedCount++;
        }
        final newCategory = TagLibraryCategory.create(
          name: newName,
          parentId: category.parentId != null
              ? categoryIdMapping[category.parentId]
              : null,
        );
        categoryIdMapping[category.id] = newCategory.id;
        importedCategories++;
      }

      currentStep++;
    }

    // 导入条目
    for (final entry in preview.entries) {
      if (!selectedEntryIds.contains(entry.id)) continue;

      onProgress?.call(currentStep / totalSteps, '导入条目: ${entry.displayName}');

      final resolution = conflictResolutions[entry.id];
      if (resolution == ConflictResolution.skip) {
        skippedConflicts++;
        currentStep++;
        continue;
      }

      // 提取预览图
      if (entry.hasThumbnail) {
        for (final file in archive.files) {
          if (file.name.startsWith('thumbnails/${entry.id}')) {
            final ext = path.extension(file.name);
            final newThumbnailPath =
                path.join(thumbnailsDir.path, '${entry.id}$ext');
            final thumbnailFile = File(newThumbnailPath);
            await thumbnailFile.writeAsBytes(file.content as List<int>);
            break;
          }
        }
      }

      if (resolution == ConflictResolution.overwrite) {
        overwrittenCount++;
      } else if (resolution == ConflictResolution.rename) {
        renamedCount++;
      }

      importedEntries++;
      currentStep++;
    }

    onProgress?.call(1.0, '导入完成');

    return ImportResult(
      importedEntries: importedEntries,
      importedCategories: importedCategories,
      skippedConflicts: skippedConflicts,
      overwrittenCount: overwrittenCount,
      renamedCount: renamedCount,
      errors: errors,
      success: errors.isEmpty,
    );
  }

  /// 生成导出文件名
  String generateExportFileName() {
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    return 'tag_library_export_$dateStr.zip';
  }
}
