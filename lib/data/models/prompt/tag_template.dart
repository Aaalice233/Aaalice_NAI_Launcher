import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:uuid/uuid.dart';

import 'prompt_tag.dart';

part 'tag_template.freezed.dart';
part 'tag_template.g.dart';

/// 标签模板数据模型
/// 用于保存可复用的标签组合
@freezed
class TagTemplate with _$TagTemplate {
  const TagTemplate._();

  const factory TagTemplate({
    /// 唯一标识
    required String id,

    /// 模板名称
    required String name,

    /// 模板描述（可选）
    String? description,

    /// 标签列表
    required List<PromptTag> tags,

    /// 创建时间
    required DateTime createdAt,

    /// 更新时间
    required DateTime updatedAt,
  }) = _TagTemplate;

  factory TagTemplate.fromJson(Map<String, dynamic> json) =>
      _$TagTemplateFromJson(json);

  /// 创建新模板
  factory TagTemplate.create({
    required String name,
    required List<PromptTag> tags,
    String? description,
  }) {
    final now = DateTime.now();
    return TagTemplate(
      id: const Uuid().v4(),
      name: name.trim(),
      description: description?.trim(),
      tags: tags,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// 显示名称
  String get displayName => name.isNotEmpty ? name : '未命名模板';

  /// 是否有描述
  bool get hasDescription => description != null && description!.isNotEmpty;

  /// 标签数量
  int get tagCount => tags.length;

  /// 获取启用的标签
  List<PromptTag> get enabledTags => tags.where((tag) => tag.enabled).toList();

  /// 转换为提示词文本
  String toPromptString() {
    return tags.toPromptString();
  }

  /// 更新标签列表
  TagTemplate updateTags(List<PromptTag> newTags) {
    return copyWith(
      tags: newTags,
      updatedAt: DateTime.now(),
    );
  }

  /// 更新名称
  TagTemplate updateName(String newName) {
    return copyWith(
      name: newName.trim(),
      updatedAt: DateTime.now(),
    );
  }

  /// 更新描述
  TagTemplate updateDescription(String? newDescription) {
    return copyWith(
      description: newDescription?.trim(),
      updatedAt: DateTime.now(),
    );
  }

  /// 添加标签
  TagTemplate addTag(PromptTag tag) {
    return copyWith(
      tags: [...tags, tag],
      updatedAt: DateTime.now(),
    );
  }

  /// 移除标签
  TagTemplate removeTag(String tagId) {
    return copyWith(
      tags: tags.where((tag) => tag.id != tagId).toList(),
      updatedAt: DateTime.now(),
    );
  }

  /// 清空所有标签
  TagTemplate clearTags() {
    return copyWith(
      tags: [],
      updatedAt: DateTime.now(),
    );
  }
}

/// 标签模板列表扩展
extension TagTemplateListExtension on List<TagTemplate> {
  /// 按名称排序
  List<TagTemplate> sortByName() {
    final sorted = [...this];
    sorted.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return sorted;
  }

  /// 按更新时间排序（最新的在前）
  List<TagTemplate> sortByUpdatedAt() {
    final sorted = [...this];
    sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted;
  }

  /// 按创建时间排序（最新的在前）
  List<TagTemplate> sortByCreatedAt() {
    final sorted = [...this];
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  /// 按标签数量排序（最多的在前）
  List<TagTemplate> sortByTagCount() {
    final sorted = [...this];
    sorted.sort((a, b) => b.tagCount.compareTo(a.tagCount));
    return sorted;
  }

  /// 查找包含指定标签ID的模板
  List<TagTemplate> findContainingTag(String tagId) {
    return where((template) =>
        template.tags.any((tag) => tag.id == tagId),
    ).toList();
  }

  /// 按名称搜索
  List<TagTemplate> searchByName(String query) {
    if (query.isEmpty) return this;
    final lowerQuery = query.toLowerCase();
    return where((template) =>
        template.name.toLowerCase().contains(lowerQuery) ||
        (template.description?.toLowerCase().contains(lowerQuery) ?? false),
    ).toList();
  }
}
