import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/tag_template_storage.dart';
import '../../core/utils/app_logger.dart';
import '../../data/models/prompt/prompt_tag.dart';
import '../../data/models/prompt/tag_template.dart';

part 'tag_template_provider.g.dart';

/// 标签模板状态
class TagTemplateState {
  final List<TagTemplate> templates;
  final bool isLoading;
  final String? error;

  const TagTemplateState({
    this.templates = const [],
    this.isLoading = false,
    this.error,
  });

  TagTemplateState copyWith({
    List<TagTemplate>? templates,
    bool? isLoading,
    String? error,
  }) {
    return TagTemplateState(
      templates: templates ?? this.templates,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// 标签模板 Provider
///
/// 管理标签模板列表，支持创建、保存、删除模板
/// 自动持久化到 Hive 存储
@riverpod
class TagTemplateNotifier extends _$TagTemplateNotifier {
  /// 存储服务
  late TagTemplateStorage _storage;

  @override
  TagTemplateState build() {
    _storage = ref.watch(tagTemplateStorageProvider);

    // 加载模板列表
    _loadTemplates();

    return const TagTemplateState();
  }

  /// 从存储加载模板列表
  void _loadTemplates() {
    try {
      final templates = _storage.getTemplates();
      // 按更新时间排序（最新的在前）
      final sortedTemplates = templates.sortByUpdatedAt();
      state = TagTemplateState(templates: sortedTemplates);
      AppLogger.d('Loaded ${templates.length} templates', 'TagTemplateProvider');
    } catch (e, stack) {
      AppLogger.e('Failed to load templates: $e', e, stack, 'TagTemplateProvider');
      state = TagTemplateState(
        templates: [],
        error: e.toString(),
      );
    }
  }

  /// 保存模板
  ///
  /// [name] 模板名称
  /// [tags] 标签列表
  /// [description] 模板描述（可选）
  /// [overwrite] 如果名称已存在，是否覆盖（默认为 false）
  /// 返回：保存的模板，如果名称冲突且 overwrite=false 则返回 null
  Future<TagTemplate?> saveTemplate({
    required String name,
    required List<PromptTag> tags,
    String? description,
    bool overwrite = false,
  }) async {
    try {
      state = state.copyWith(isLoading: true);

      // 检查名称是否已存在
      final existing = _storage.getTemplateByName(name);

      if (existing != null && !overwrite) {
        // 名称冲突且不允许覆盖
        AppLogger.w('Template name already exists: $name', 'TagTemplateProvider');
        state = state.copyWith(isLoading: false);
        return null;
      }

      TagTemplate template;
      if (existing != null && overwrite) {
        // 更新现有模板
        template = existing.updateTags(tags).updateName(name);
        if (description != null) {
          template = template.updateDescription(description);
        }
        AppLogger.d('Updating template: $name', 'TagTemplateProvider');
      } else {
        // 创建新模板
        template = TagTemplate.create(
          name: name,
          tags: tags,
          description: description,
        );
        AppLogger.d('Creating new template: $name', 'TagTemplateProvider');
      }

      await _storage.saveTemplate(template);
      _loadTemplates();

      return template;
    } catch (e, stack) {
      AppLogger.e('Failed to save template: $e', e, stack, 'TagTemplateProvider');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
      return null;
    }
  }

  /// 删除模板
  ///
  /// [templateId] 模板 ID
  Future<void> deleteTemplate(String templateId) async {
    try {
      state = state.copyWith(isLoading: true);

      await _storage.deleteTemplate(templateId);
      AppLogger.d('Deleted template: $templateId', 'TagTemplateProvider');

      _loadTemplates();
    } catch (e, stack) {
      AppLogger.e('Failed to delete template: $e', e, stack, 'TagTemplateProvider');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 根据ID获取模板
  ///
  /// [templateId] 模板 ID
  TagTemplate? getTemplate(String templateId) {
    try {
      return _storage.getTemplate(templateId);
    } catch (e) {
      AppLogger.e('Failed to get template: $e', e, null, 'TagTemplateProvider');
      return null;
    }
  }

  /// 获取所有模板
  List<TagTemplate> getTemplates() {
    return state.templates;
  }

  /// 根据名称获取模板
  ///
  /// [name] 模板名称
  TagTemplate? getTemplateByName(String name) {
    try {
      return _storage.getTemplateByName(name);
    } catch (e) {
      AppLogger.e('Failed to get template by name: $e', e, null, 'TagTemplateProvider');
      return null;
    }
  }

  /// 检查模板名称是否已存在
  ///
  /// [name] 模板名称
  bool hasTemplateName(String name) {
    return _storage.hasTemplateName(name);
  }

  /// 获取模板的标签列表（用于插入到提示词）
  ///
  /// [templateId] 模板 ID
  List<PromptTag> getTemplateTags(String templateId) {
    final template = getTemplate(templateId);
    return template?.tags ?? [];
  }

  /// 清空所有模板
  Future<void> clearTemplates() async {
    try {
      state = state.copyWith(isLoading: true);

      await _storage.clearTemplates();
      AppLogger.d('Cleared all templates', 'TagTemplateProvider');

      _loadTemplates();
    } catch (e, stack) {
      AppLogger.e('Failed to clear templates: $e', e, stack, 'TagTemplateProvider');
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// 重新加载模板列表
  void refresh() {
    _loadTemplates();
  }

  /// 获取模板数量
  int get templatesCount => state.templates.length;

  /// 清除错误状态
  void clearError() {
    if (state.error != null) {
      state = state.copyWith(error: null);
    }
  }
}

/// 便捷方法：获取当前模板列表
@riverpod
List<TagTemplate> currentTemplates(Ref ref) {
  final state = ref.watch(tagTemplateNotifierProvider);
  return state.templates;
}

/// 便捷方法：检查是否正在加载
@riverpod
bool isTemplateLoading(Ref ref) {
  final state = ref.watch(tagTemplateNotifierProvider);
  return state.isLoading;
}

/// 便捷方法：获取模板数量
@riverpod
int templatesCount(Ref ref) {
  final state = ref.watch(tagTemplateNotifierProvider);
  return state.templates.length;
}
