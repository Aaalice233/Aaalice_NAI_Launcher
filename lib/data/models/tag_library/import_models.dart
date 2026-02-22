import 'package:freezed_annotation/freezed_annotation.dart';

import 'tag_library_category.dart';
import 'tag_library_entry.dart';

part 'import_models.freezed.dart';
part 'import_models.g.dart';

/// 导入预览数据
@freezed
class ImportPreview with _$ImportPreview {
  const ImportPreview._();

  const factory ImportPreview({
    /// 导出文件版本
    required String version,

    /// 导出时间
    required DateTime exportDate,

    /// 导出应用版本
    String? appVersion,

    /// 条目列表
    @Default([]) List<TagLibraryEntry> entries,

    /// 分类列表
    @Default([]) List<TagLibraryCategory> categories,

    /// 是否包含预览图
    @Default(false) bool hasThumbnails,
  }) = _ImportPreview;

  factory ImportPreview.fromJson(Map<String, dynamic> json) =>
      _$ImportPreviewFromJson(json);

  /// 条目数量
  int get entryCount => entries.length;

  /// 分类数量
  int get categoryCount => categories.length;

  /// 是否有效
  bool get isValid => entries.isNotEmpty || categories.isNotEmpty;
}

/// 冲突类型
enum ConflictType {
  /// 条目冲突
  @JsonValue('entry')
  entry,

  /// 分类冲突
  @JsonValue('category')
  category,
}

/// 冲突解决方案
enum ConflictResolution {
  /// 覆盖现有数据
  @JsonValue('overwrite')
  overwrite,

  /// 跳过，保留现有数据
  @JsonValue('skip')
  skip,

  /// 重命名后导入
  @JsonValue('rename')
  rename,
}

/// 导入冲突信息
@freezed
class ImportConflict with _$ImportConflict {
  const ImportConflict._();

  const factory ImportConflict({
    /// 冲突类型
    required ConflictType type,

    /// 导入项名称
    required String importName,

    /// 导入项ID
    required String importId,

    /// 导入项内容预览
    String? importContentPreview,

    /// 现有项ID
    required String existingId,

    /// 现有项内容预览
    String? existingContentPreview,

    /// 选择的解决方案
    @Default(ConflictResolution.skip) ConflictResolution resolution,
  }) = _ImportConflict;

  factory ImportConflict.fromJson(Map<String, dynamic> json) =>
      _$ImportConflictFromJson(json);

  /// 是否为条目冲突
  bool get isEntryConflict => type == ConflictType.entry;

  /// 是否为分类冲突
  bool get isCategoryConflict => type == ConflictType.category;

  /// 更新解决方案
  ImportConflict withResolution(ConflictResolution newResolution) {
    return copyWith(resolution: newResolution);
  }
}

/// 导入结果
@freezed
class ImportResult with _$ImportResult {
  const ImportResult._();

  const factory ImportResult({
    /// 成功导入的条目数
    @Default(0) int importedEntries,

    /// 成功导入的分类数
    @Default(0) int importedCategories,

    /// 跳过的冲突数
    @Default(0) int skippedConflicts,

    /// 覆盖更新的数量
    @Default(0) int overwrittenCount,

    /// 重命名导入的数量
    @Default(0) int renamedCount,

    /// 错误列表
    @Default([]) List<String> errors,

    /// 是否成功
    @Default(true) bool success,
  }) = _ImportResult;

  factory ImportResult.fromJson(Map<String, dynamic> json) =>
      _$ImportResultFromJson(json);

  /// 是否有错误
  bool get hasErrors => errors.isNotEmpty;

  /// 总处理数量
  int get totalProcessed =>
      importedEntries +
      importedCategories +
      skippedConflicts +
      overwrittenCount +
      renamedCount;
}

/// 导出清单数据
@freezed
class ExportManifest with _$ExportManifest {
  const ExportManifest._();

  const factory ExportManifest({
    /// 版本
    @Default('1.0') String version,

    /// 导出时间
    required DateTime exportDate,

    /// 应用版本
    String? appVersion,

    /// 条目数量
    @Default(0) int entryCount,

    /// 分类数量
    @Default(0) int categoryCount,

    /// 是否包含预览图
    @Default(false) bool includeThumbnails,
  }) = _ExportManifest;

  factory ExportManifest.fromJson(Map<String, dynamic> json) =>
      _$ExportManifestFromJson(json);
}
