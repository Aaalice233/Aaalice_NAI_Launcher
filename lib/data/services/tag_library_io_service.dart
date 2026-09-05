import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as path;

import '../models/tag_library/import_models.dart';
import '../models/tag_library/tag_library_category.dart';
import '../models/tag_library/tag_library_entry.dart';
import 'tag_library_portable_thumbnail_store.dart';

/// 词库导入导出服务
class TagLibraryIOService {
  TagLibraryIOService({TagLibraryPortableThumbnailStore? portableThumbnails})
    : _portableThumbnails =
          portableThumbnails ?? const TagLibraryPortableThumbnailStore();

  static const _thumbnailsPrefix = 'thumbnails/';

  static final _driveLetterPattern = RegExp(r'^[A-Za-z]:');

  final TagLibraryPortableThumbnailStore _portableThumbnails;

  Future<int?> thumbnailLength(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return null;
    final file = File(filePath);
    return await file.exists() ? file.length() : null;
  }

  Stream<List<int>> openThumbnail(String filePath) => File(filePath).openRead();

  Future<String> importPortableThumbnail(
    String entryId,
    String extension,
    Stream<List<int>> bytes,
  ) async {
    final mutation = await stagePortableThumbnail(
      entryId,
      extension: extension,
      bytes: bytes,
    );
    await mutation.commit();
    return mutation.path!;
  }

  Future<PortableThumbnailMutation> stagePortableThumbnail(
    String entryId, {
    required String? extension,
    required Stream<List<int>>? bytes,
    String? existingPath,
  }) => _portableThumbnails.stage(
    entryId,
    extension: extension,
    bytes: bytes,
    existingPath: existingPath,
  );

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
    final manifestBytes = utf8.encode(manifestJson);
    archive.addFile(
      ArchiveFile('manifest.json', manifestBytes.length, manifestBytes),
    );
    currentStep++;
    onProgress?.call(currentStep / totalSteps, '已创建清单');

    // 导出分类
    onProgress?.call(currentStep / totalSteps, '导出分类...');
    final categoriesJson = jsonEncode(
      categories.map((c) => c.toJson()).toList(),
    );
    final categoriesBytes = utf8.encode(categoriesJson);
    archive.addFile(
      ArchiveFile('categories.json', categoriesBytes.length, categoriesBytes),
    );
    currentStep++;
    onProgress?.call(currentStep / totalSteps, '已导出分类');

    // 导出条目
    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      onProgress?.call(currentStep / totalSteps, '导出条目: ${entry.displayName}');

      // 导出条目 JSON
      final entryJson = jsonEncode(entry.toJson());
      final entryBytes = utf8.encode(entryJson);
      archive.addFile(
        ArchiveFile('entries/${entry.id}.json', entryBytes.length, entryBytes),
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
    late Archive archive;
    try {
      final bytes = await zipFile.readAsBytes();

      // 检查文件是否为空
      if (bytes.isEmpty) {
        throw Exception('词库文件为空');
      }

      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw Exception('无法解压词库文件：${e.toString()}');
    }

    _preflightArchive(archive);

    // 读取 manifest
    final manifestFile = archive.findFile('manifest.json');
    if (manifestFile == null) {
      throw Exception('无效的词库文件：缺少 manifest.json');
    }

    late Map<String, dynamic> manifestData;
    try {
      final manifestJson = utf8.decode(manifestFile.content as List<int>);
      manifestData = jsonDecode(manifestJson) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('manifest.json 解析失败：${e.toString()}');
    }

    // 读取分类
    final categoriesFile = archive.findFile('categories.json');
    List<TagLibraryCategory> categories = [];
    if (categoriesFile != null) {
      try {
        final categoriesJson = utf8.decode(categoriesFile.content as List<int>);
        final categoriesData = jsonDecode(categoriesJson) as List<dynamic>;
        categories = categoriesData
            .map(
              (c) => TagLibraryCategory.fromJson(Map<String, dynamic>.from(c)),
            )
            .toList();
      } catch (e) {
        throw Exception('categories.json 解析失败：${e.toString()}');
      }
    }

    // 读取条目
    final entries = <TagLibraryEntry>[];
    for (final file in archive.files) {
      if (file.name.startsWith('entries/') && file.name.endsWith('.json')) {
        try {
          final entryJson = utf8.decode(file.content as List<int>);
          final entryData = jsonDecode(entryJson) as Map<String, dynamic>;
          entries.add(TagLibraryEntry.fromJson(entryData));
        } catch (e) {
          // 记录解析失败的条目，但继续处理其他条目
          continue;
        }
      }
    }

    _verifyIdentifiers(entries: entries, categories: categories);

    // 检查是否有预览图
    final hasThumbnails = archive.files.any(
      (f) => f.name.startsWith(_thumbnailsPrefix),
    );

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

    // 归档与预览都由调用方提供，落盘前必须重新校验而不是沿用解析阶段的结论
    final thumbnailMembers = _preflightArchive(archive);
    _verifyIdentifiers(
      entries: preview.entries,
      categories: preview.categories,
    );

    // 获取应用文档目录用于保存预览图
    final thumbnailsDir =
        await TagLibraryPortableThumbnailStore.resolveDirectory();
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
        final existing = existingCategories
            .cast<TagLibraryCategory?>()
            .firstWhere(
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

    // 存储更新后的条目（key: 原始条目ID, value: 更新后的条目）
    final updatedEntries = <String, TagLibraryEntry>{};

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

      // 提取预览图并更新缩略图路径
      String? newThumbnailPath;
      if (entry.hasThumbnail) {
        final member = thumbnailMembers[entry.id];
        if (member != null) {
          final ext = path.url.extension(member.name).toLowerCase();
          _verifyThumbnailTarget(thumbnailsDir, entry.id, ext);
          newThumbnailPath = await importPortableThumbnail(
            entry.id,
            ext,
            Stream.value(member.content as List<int>),
          );
        }
      }

      // 创建更新后的条目（使用新的缩略图路径）
      final updatedEntry = entry.copyWith(
        thumbnail:
            newThumbnailPath ??
            _retainedThumbnail(thumbnailsDir, entry.thumbnail),
      );
      updatedEntries[entry.id] = updatedEntry;

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
      updatedEntries: updatedEntries,
    );
  }

  /// 生成导出文件名
  String generateExportFileName() {
    final now = DateTime.now();
    final dateStr =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    return 'tag_library_export_$dateStr.zip';
  }

  /// 校验归档成员，返回按条目 ID 索引的预览图成员
  static Map<String, ArchiveFile> _preflightArchive(Archive archive) {
    final names = <String>{};
    final thumbnails = <String, ArchiveFile>{};

    for (final file in archive.files) {
      final name = file.name;
      if (file.isSymbolicLink) {
        throw FormatException('词库文件包含符号链接：${_excerpt(name)}');
      }
      if (!file.isFile) {
        throw FormatException('词库文件包含非文件条目：${_excerpt(name)}');
      }
      if (!_isSafeMemberPath(name)) {
        throw FormatException('词库文件包含不安全路径：${_excerpt(name)}');
      }
      if (!names.add(name.toLowerCase())) {
        throw FormatException('词库文件包含重复条目：${_excerpt(name)}');
      }
      if (!name.startsWith(_thumbnailsPrefix)) continue;

      final entryId = _thumbnailEntryId(name);
      if (entryId == null) {
        throw FormatException('词库文件包含无效预览图：${_excerpt(name)}');
      }
      if (thumbnails.containsKey(entryId)) {
        throw FormatException('词库文件为同一条目包含多张预览图：${_excerpt(name)}');
      }
      thumbnails[entryId] = file;
    }

    return thumbnails;
  }

  /// 解析 `thumbnails/<条目 ID><扩展名>`，不符合精确形式时返回 null
  static String? _thumbnailEntryId(String memberName) {
    final relative = memberName.substring(_thumbnailsPrefix.length);
    if (relative.contains('/')) return null;
    if (!TagLibraryPortableThumbnailStore.isSupportedExtension(
      path.url.extension(relative),
    )) {
      return null;
    }
    final entryId = path.url.basenameWithoutExtension(relative);
    return TagLibraryPortableThumbnailStore.isValidEntryId(entryId)
        ? entryId
        : null;
  }

  static bool _isSafeMemberPath(String value) {
    if (value.isEmpty || value.contains('\\')) return false;
    if (value.startsWith('/') || _driveLetterPattern.hasMatch(value)) {
      return false;
    }
    if (value.codeUnits.any((unit) => unit < 0x20 || unit == 0x7f)) {
      return false;
    }
    return value
        .split('/')
        .every((part) => part.isNotEmpty && part != '.' && part != '..');
  }

  static void _verifyIdentifiers({
    required List<TagLibraryEntry> entries,
    required List<TagLibraryCategory> categories,
  }) {
    for (final category in categories) {
      _verifyIdentifier(category.id, '分类 ID');
      final parentId = category.parentId;
      if (parentId != null) _verifyIdentifier(parentId, '父分类 ID');
    }
    for (final entry in entries) {
      _verifyIdentifier(entry.id, '条目 ID');
      final categoryId = entry.categoryId;
      if (categoryId != null) _verifyIdentifier(categoryId, '条目所属分类 ID');
    }
  }

  static void _verifyIdentifier(String value, String label) {
    if (!TagLibraryPortableThumbnailStore.isValidEntryId(value)) {
      throw FormatException('词库文件包含非法$label：${_excerpt(value)}');
    }
  }

  static void _verifyThumbnailTarget(
    Directory thumbnailsDir,
    String entryId,
    String extension,
  ) {
    final root = path.normalize(thumbnailsDir.absolute.path);
    final target = path.normalize(path.join(root, '$entryId$extension'));
    if (!path.isWithin(root, target)) {
      throw FormatException('预览图写入路径越界：${_excerpt(entryId)}');
    }
  }

  /// 包内条目自带的缩略图路径来自导出机器，只有仍位于本机缩略图目录内才保留
  static String? _retainedThumbnail(Directory thumbnailsDir, String? value) {
    if (value == null || value.isEmpty) return null;
    final root = path.normalize(thumbnailsDir.absolute.path);
    final normalized = path.normalize(path.absolute(value));
    return path.isWithin(root, normalized) ? normalized : null;
  }

  static String _excerpt(String value) =>
      value.length <= 64 ? value : '${value.substring(0, 64)}…';
}
