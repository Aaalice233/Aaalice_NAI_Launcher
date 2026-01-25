import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/models/prompt/tag_template.dart';
import '../constants/storage_keys.dart';

part 'tag_template_storage.g.dart';

/// 标签模板存储服务 - 使用 Hive 持久化标签模板数据
class TagTemplateStorage {
  /// 获取已打开的 tag_templates box
  Box get _templatesBox => Hive.box(StorageKeys.tagTemplatesBox);

  /// 初始化存储 (box 应在 main.dart 中预先打开)
  Future<void> init() async {
    // Box 已在 main.dart 中预先打开
  }

  /// 保存模板
  /// 如果模板名称已存在，则覆盖旧模板
  Future<void> saveTemplate(TagTemplate template) async {
    try {
      await _templatesBox.put(template.id, template.toJson());
    } catch (e) {
      // 处理存储配额超限等错误
      if (e is HiveError) {
        throw TagTemplateStorageException('Storage quota exceeded or error: ${e.message}');
      }
      rethrow;
    }
  }

  /// 删除模板
  Future<void> deleteTemplate(String templateId) async {
    try {
      await _templatesBox.delete(templateId);
    } catch (e) {
      if (e is HiveError) {
        throw TagTemplateStorageException('Failed to delete template: ${e.message}');
      }
      rethrow;
    }
  }

  /// 根据ID获取模板
  TagTemplate? getTemplate(String templateId) {
    try {
      final json = _templatesBox.get(templateId);
      if (json == null) return null;
      return TagTemplate.fromJson(Map<String, dynamic>.from(json));
    } catch (e) {
      return null;
    }
  }

  /// 获取所有模板
  List<TagTemplate> getTemplates() {
    try {
      final templatesJson = _templatesBox.values.toList();
      return templatesJson.map((json) {
        return TagTemplate.fromJson(Map<String, dynamic>.from(json));
      }).toList();
    } catch (e) {
      // 如果反序列化失败，返回空列表
      return [];
    }
  }

  /// 根据名称查找模板
  TagTemplate? getTemplateByName(String name) {
    try {
      final templates = getTemplates();
      for (final template in templates) {
        if (template.name.toLowerCase() == name.toLowerCase()) {
          return template;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// 检查模板名称是否已存在
  bool hasTemplateName(String name) {
    return getTemplateByName(name) != null;
  }

  /// 清空所有模板
  Future<void> clearTemplates() async {
    try {
      await _templatesBox.clear();
    } catch (e) {
      if (e is HiveError) {
        throw TagTemplateStorageException('Failed to clear templates: ${e.message}');
      }
      rethrow;
    }
  }

  /// 获取模板数量
  int get templatesCount => _templatesBox.length;

  // ==================== Lifecycle ====================

  /// 关闭存储
  Future<void> close() async {
    await _templatesBox.close();
  }
}

/// TagTemplateStorage Provider
@riverpod
TagTemplateStorage tagTemplateStorage(Ref ref) {
  final service = TagTemplateStorage();
  // 注意：需要在应用启动时调用 init()
  return service;
}

/// 标签模板存储异常
class TagTemplateStorageException implements Exception {
  final String message;

  TagTemplateStorageException(this.message);

  @override
  String toString() => 'TagTemplateStorageException: $message';
}
