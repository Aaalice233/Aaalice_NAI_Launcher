import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../../core/enums/precise_ref_type.dart';

part 'precise_ref_library_entry.freezed.dart';
part 'precise_ref_library_entry.g.dart';

/// 精准参考库条目数据模型
///
/// 保存可复用的精准参考图片配置（原图存文件，Hive 仅存元数据），
/// 记住每张图的默认类型、强度与保真度，发送到生成参数时直接套用。
///
/// 注意：Hive typeId 26 已被本模型占用，勿在其他模型中复用。
@HiveType(typeId: 26)
@freezed
class PreciseRefLibraryEntry with _$PreciseRefLibraryEntry {
  const PreciseRefLibraryEntry._();

  const factory PreciseRefLibraryEntry({
    /// 唯一标识 (UUID)
    @HiveField(0) required String id,

    /// 显示名称（仅元数据，不参与磁盘文件命名）
    @HiveField(1) required String name,

    /// 原图绝对路径（文件名为 {id}.{实际图片扩展名}）
    @HiveField(2) required String imagePath,

    /// 参考类型索引 (PreciseRefType 的索引，默认 characterAndStyle)
    @HiveField(3) @Default(2) int typeIndex,

    /// 参考强度（数值输入不设前端上下限，滑条范围 0-1）
    @HiveField(4) @Default(1.0) double strength,

    /// 保真度（数值输入不设前端上下限，滑条范围 0-1）
    @HiveField(5) @Default(1.0) double fidelity,

    /// 是否收藏
    @HiveField(6) @Default(false) bool isFavorite,

    /// 使用次数
    @HiveField(7) @Default(0) int usedCount,

    /// 最后使用时间
    @HiveField(8) DateTime? lastUsedAt,

    /// 创建时间
    @HiveField(9) required DateTime createdAt,
  }) = _PreciseRefLibraryEntry;

  /// 创建新条目（自动生成 id 与创建时间）
  factory PreciseRefLibraryEntry.create({
    String? id,
    required String name,
    required String imagePath,
    PreciseRefType type = PreciseRefType.characterAndStyle,
    double strength = 1.0,
    double fidelity = 1.0,
    DateTime? createdAt,
  }) {
    final resolvedId = id ?? const Uuid().v4();
    final trimmedName = name.trim();
    return PreciseRefLibraryEntry(
      id: resolvedId,
      name: trimmedName.isEmpty
          ? (resolvedId.length <= 8 ? resolvedId : resolvedId.substring(0, 8))
          : trimmedName,
      imagePath: imagePath,
      typeIndex: type.index,
      strength: strength,
      fidelity: fidelity,
      createdAt: createdAt ?? DateTime.now(),
    );
  }

  /// 参考类型（索引越界时回退为 characterAndStyle）
  PreciseRefType get type {
    if (typeIndex < 0 || typeIndex >= PreciseRefType.values.length) {
      return PreciseRefType.characterAndStyle;
    }
    return PreciseRefType.values[typeIndex];
  }

  /// 记录一次使用
  PreciseRefLibraryEntry recordUsage() {
    return copyWith(usedCount: usedCount + 1, lastUsedAt: DateTime.now());
  }

  /// 切换收藏状态
  PreciseRefLibraryEntry toggleFavorite() {
    return copyWith(isFavorite: !isFavorite);
  }
}

/// 精准参考库条目列表扩展
extension PreciseRefLibraryEntryListExtension on List<PreciseRefLibraryEntry> {
  /// 获取收藏的条目
  List<PreciseRefLibraryEntry> get favorites =>
      where((e) => e.isFavorite).toList();

  /// 按创建时间排序
  List<PreciseRefLibraryEntry> sortedByCreatedAt({bool descending = true}) {
    final sorted = [...this]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return descending ? sorted.reversed.toList() : sorted;
  }

  /// 按最后使用时间排序（未使用的排在最后）
  List<PreciseRefLibraryEntry> sortedByLastUsed({bool descending = true}) {
    final sorted = [...this]
      ..sort((a, b) {
        final aTime = a.lastUsedAt;
        final bTime = b.lastUsedAt;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        final cmp = aTime.compareTo(bTime);
        return descending ? -cmp : cmp;
      });
    return sorted;
  }

  /// 按使用次数排序
  List<PreciseRefLibraryEntry> sortedByUsedCount({bool descending = true}) {
    final sorted = [...this]
      ..sort((a, b) => a.usedCount.compareTo(b.usedCount));
    return descending ? sorted.reversed.toList() : sorted;
  }

  /// 按名称排序
  List<PreciseRefLibraryEntry> sortedByName({bool descending = false}) {
    final sorted = [...this]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return descending ? sorted.reversed.toList() : sorted;
  }

  /// 按关键词搜索名称
  List<PreciseRefLibraryEntry> search(String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return this;
    return where((e) => e.name.toLowerCase().contains(trimmed)).toList();
  }
}
