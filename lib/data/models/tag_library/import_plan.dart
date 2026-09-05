import 'import_models.dart';
import 'tag_library_category.dart';
import 'tag_library_entry.dart';

/// 单个导入项的动作
enum TagLibraryImportAction {
  /// 保留本地数据，不写入包内版本
  skip,

  /// 无冲突，按新身份写入
  create,

  /// 加后缀后按新身份写入
  rename,

  /// 删除现有项后写入包内版本
  overwrite,
}

/// 导入项类型
enum TagLibraryImportItemKind { category, entry }

/// 分类的逐条导入计划
class TagLibraryCategoryImportPlan {
  const TagLibraryCategoryImportPlan({
    required this.source,
    required this.action,
    required this.targetId,
    required this.targetName,
    this.targetParentId,
    this.replacedCategoryId,
    this.reassignedId = false,
  });

  final TagLibraryCategory source;
  final TagLibraryImportAction action;

  /// 跳过时为可供子项引用的现有分类 ID；本地已无同名分类时为 null
  final String? targetId;
  final String targetName;

  /// 已按分类映射解析的父级 ID
  final String? targetParentId;

  /// 覆盖时先删除的现有分类 ID
  final String? replacedCategoryId;

  /// 包内 ID 与本次不删除的本地分类冲突，已改用新 ID
  final bool reassignedId;

  bool get isApplied => action != TagLibraryImportAction.skip;
}

/// 条目的逐条导入计划
class TagLibraryEntryImportPlan {
  const TagLibraryEntryImportPlan({
    required this.source,
    required this.action,
    required this.targetId,
    required this.targetName,
    this.targetCategoryId,
    this.replacedEntryId,
    this.reassignedId = false,
  });

  final TagLibraryEntry source;
  final TagLibraryImportAction action;

  /// 跳过时为命中的现有条目 ID；本地已无同名条目时为 null
  final String? targetId;
  final String targetName;

  /// 已按分类映射解析的所属分类 ID
  final String? targetCategoryId;

  /// 覆盖时先删除的现有条目 ID
  final String? replacedEntryId;

  /// 包内 ID 与本次不删除的本地条目冲突，已改用新 ID
  final bool reassignedId;

  bool get isApplied => action != TagLibraryImportAction.skip;

  /// 预览图落盘使用的条目 ID，决定缩略图目录内的目标文件名
  String? get thumbnailEntryId => isApplied ? targetId : null;
}

/// 一次导入的完整计划，写入前已确定全部目标身份与引用
class TagLibraryImportPlan {
  TagLibraryImportPlan({
    required this.preview,
    required List<TagLibraryCategoryImportPlan> categories,
    required List<TagLibraryEntryImportPlan> entries,
  }) : categories = List.unmodifiable(categories),
       entries = List.unmodifiable(entries),
       categoryIdMapping = Map.unmodifiable(<String, String>{
         for (final item in categories)
           if (item.targetId != null) item.source.id: item.targetId!,
       });

  final ImportPreview preview;
  final List<TagLibraryCategoryImportPlan> categories;
  final List<TagLibraryEntryImportPlan> entries;

  /// 包内分类 ID -> 本地目标分类 ID
  final Map<String, String> categoryIdMapping;

  int get skippedCount =>
      _countCategories(TagLibraryImportAction.skip) +
      _countEntries(TagLibraryImportAction.skip);

  int get overwrittenCount =>
      _countCategories(TagLibraryImportAction.overwrite) +
      _countEntries(TagLibraryImportAction.overwrite);

  int get renamedCount =>
      _countCategories(TagLibraryImportAction.rename) +
      _countEntries(TagLibraryImportAction.rename);

  /// 覆盖分类沿用现有统计口径，只计入 overwrittenCount
  int get importedCategoryCount =>
      _countCategories(TagLibraryImportAction.create) +
      _countCategories(TagLibraryImportAction.rename);

  int get importedEntryCount => entries.where((e) => e.isApplied).length;

  int _countCategories(TagLibraryImportAction action) =>
      categories.where((item) => item.action == action).length;

  int _countEntries(TagLibraryImportAction action) =>
      entries.where((item) => item.action == action).length;
}

/// 应用计划时被拒绝的项：目标 ID 在当前数据中已被占用
class TagLibraryImportRejection {
  const TagLibraryImportRejection({
    required this.kind,
    required this.sourceId,
    required this.targetId,
  });

  final TagLibraryImportItemKind kind;
  final String sourceId;
  final String targetId;
}

/// 计划应用结果
class TagLibraryImportApplyResult {
  TagLibraryImportApplyResult({
    required List<String> appliedCategoryIds,
    required List<String> appliedEntryIds,
    required List<TagLibraryImportRejection> rejected,
  }) : appliedCategoryIds = List.unmodifiable(appliedCategoryIds),
       appliedEntryIds = List.unmodifiable(appliedEntryIds),
       rejected = List.unmodifiable(rejected);

  final List<String> appliedCategoryIds;
  final List<String> appliedEntryIds;
  final List<TagLibraryImportRejection> rejected;

  bool get success => rejected.isEmpty;
}
