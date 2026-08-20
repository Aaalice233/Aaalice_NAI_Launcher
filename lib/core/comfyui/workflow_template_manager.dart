import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../utils/app_logger.dart';
import 'comfyui_api_service.dart';
import 'workflow_template.dart';
import 'builtin_workflows.dart';
import 'workflow_node_validator.dart';

/// 工作流模板管理器
///
/// 负责：
/// - 加载内置模板
/// - 加载/保存用户自定义模板
/// - 参数注入：将用户输入/参数写入 workflow JSON 副本
/// - 图像上传与文件名注入
class WorkflowTemplateManager {
  static const String _tag = 'WFManager';
  static const String _customDir = 'comfyui_workflows';

  final List<WorkflowTemplate> _templates = [];

  List<WorkflowTemplate> get templates => List.unmodifiable(_templates);

  List<WorkflowTemplate> get customTemplates =>
      _templates.where((t) => !t.isBuiltin).toList();

  /// 按分类筛选
  List<WorkflowTemplate> getByCategory(WorkflowCategory category) =>
      _templates.where((t) => t.category == category).toList();

  /// 初始化：加载内置模板 + 用户自定义模板
  Future<void> loadAllTemplates() async {
    _templates.clear();
    for (final builtin in BuiltinWorkflows.all) {
      _templates.add(builtin);
    }
    await _loadCustomTemplates();
    AppLogger.i(
      'Loaded ${_templates.length} workflow(s): '
      '${_templates.where((t) => t.isBuiltin).length} builtin, '
      '${customTemplates.length} custom',
      _tag,
    );
  }

  /// 兼容旧接口（同步，仅加载内置模板）
  void loadBuiltinTemplates() {
    _templates.clear();
    for (final builtin in BuiltinWorkflows.all) {
      _templates.add(builtin);
    }
    AppLogger.i('Loaded ${_templates.length} builtin workflow(s)', _tag);
  }

  /// 添加用户自定义模板并持久化
  Future<void> addCustomTemplate(WorkflowTemplate template) async {
    _templates.removeWhere((t) => t.id == template.id);
    _templates.add(template);
    await _saveCustomTemplate(template);
    AppLogger.i(
      'Added custom workflow: ${template.name} (${template.id})',
      _tag,
    );
  }

  /// 删除用户自定义模板
  Future<void> removeCustomTemplate(String templateId) async {
    _templates.removeWhere((t) => t.id == templateId && !t.isBuiltin);
    await _deleteCustomTemplateFile(templateId);
    AppLogger.i('Removed custom workflow: $templateId', _tag);
  }

  /// 根据 ID 获取模板
  WorkflowTemplate? getById(String id) {
    try {
      return _templates.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }

  /// 准备可执行的工作流 JSON
  ///
  /// 将模板的 workflowJson 做一份深拷贝，然后注入参数值。
  /// [paramValues] 键为 slot.id，值为用户设置的值。
  /// [uploadedFiles] 键为 slot.id，值为上传后 ComfyUI 返回的文件名。
  Map<String, dynamic> buildExecutableWorkflow({
    required WorkflowTemplate template,
    Map<String, dynamic> paramValues = const {},
    Map<String, String> uploadedFiles = const {},
  }) {
    final workflow = _deepCopy(template.workflowJson);

    for (final slot in template.slots) {
      switch (slot.direction) {
        case SlotDirection.input:
          final filename = uploadedFiles[slot.id];
          if (filename != null && slot.field != null) {
            _setNodeInput(workflow, slot.nodeId, slot.field!, filename);
          }
          break;

        case SlotDirection.parameter:
          final value = paramValues[slot.id] ?? slot.defaultValue;
          if (value != null && slot.field != null) {
            _setNodeInput(workflow, slot.nodeId, slot.field!, value);
          }
          break;

        case SlotDirection.output:
          break;
      }
    }

    return workflow;
  }

  /// 校验当前 ComfyUI 的节点类型及其必需输入是否匹配 workflow。
  Future<void> validateWorkflowNodeTypes({
    required ComfyUIApiService api,
    required Map<String, dynamic> workflow,
  }) async {
    final objectInfo = await api.getObjectInfo();
    final missingNodeTypes = findMissingWorkflowNodeTypes(
      workflow: workflow,
      objectInfo: objectInfo,
    );
    if (missingNodeTypes.isNotEmpty) {
      throw ComfyUIApiException(
        formatMissingWorkflowNodeTypesMessage(missingNodeTypes),
      );
    }

    final missingRequiredInputs = findMissingWorkflowRequiredInputs(
      workflow: workflow,
      objectInfo: objectInfo,
    );
    if (missingRequiredInputs.isNotEmpty) {
      throw ComfyUIApiException(
        formatMissingWorkflowRequiredInputsMessage(missingRequiredInputs),
      );
    }
  }

  /// 上传输入图像并返回 {slotId: uploadedFilename}
  Future<Map<String, String>> uploadInputImages({
    required ComfyUIApiService api,
    required WorkflowTemplate template,
    required Map<String, Uint8List> imageData,
  }) async {
    final results = <String, String>{};

    for (final slot in template.inputSlots) {
      final data = imageData[slot.id];
      if (data == null) {
        if (slot.required) {
          throw ArgumentError('Required input image missing: ${slot.label}');
        }
        continue;
      }

      final filename =
          'nai_launcher_${slot.id}_${DateTime.now().millisecondsSinceEpoch}.png';
      AppLogger.d(
        'Uploading ${slot.id}: bytes=${data.length}, filename=$filename',
        _tag,
      );
      final uploaded = await api.uploadImage(
        imageBytes: data,
        filename: filename,
      );
      results[slot.id] = uploaded;
      AppLogger.d('Uploaded ${slot.id} as $uploaded', _tag);
    }

    return results;
  }

  void _setNodeInput(
    Map<String, dynamic> workflow,
    String nodeId,
    String field,
    dynamic value,
  ) {
    final node = workflow[nodeId] as Map<String, dynamic>?;
    if (node == null) {
      AppLogger.w('Node $nodeId not found in workflow', _tag);
      return;
    }
    final inputs = node['inputs'] as Map<String, dynamic>?;
    if (inputs == null) {
      AppLogger.w('Node $nodeId has no inputs', _tag);
      return;
    }

    final existing = inputs[field];
    if (existing is List) {
      AppLogger.w(
        'Skipping field $field on node $nodeId: is a connection, not a value',
        _tag,
      );
      return;
    }
    inputs[field] = value;
  }

  Map<String, dynamic> _deepCopy(Map<String, dynamic> source) {
    return json.decode(json.encode(source)) as Map<String, dynamic>;
  }

  // ==================== 自定义模板持久化 ====================

  Future<Directory> _getStorageDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/NAI_Launcher/$_customDir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<void> _loadCustomTemplates() async {
    try {
      final dir = await _getStorageDir();
      final files = dir.listSync().whereType<File>().where(
        (f) => f.path.endsWith('.json'),
      );

      for (final file in files) {
        try {
          final content = await file.readAsString();
          final data = json.decode(content) as Map<String, dynamic>;
          final manifest = data['manifest'] as Map<String, dynamic>;
          final workflowJson = data['workflow'] as Map<String, dynamic>;
          final template = WorkflowTemplate.fromJson(
            manifest,
            workflowJson,
            isBuiltin: false,
          );
          _templates.add(template);
        } catch (e) {
          AppLogger.w(
            'Failed to load custom workflow from ${file.path}: $e',
            _tag,
          );
        }
      }
    } catch (e) {
      AppLogger.w('Failed to load custom workflows: $e', _tag);
    }
  }

  Future<void> _saveCustomTemplate(WorkflowTemplate template) async {
    final dir = await _getStorageDir();
    final file = File('${dir.path}/${template.id}.json');
    final data = {
      'manifest': template.toManifestJson(),
      'workflow': template.workflowJson,
    };
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
  }

  Future<void> _deleteCustomTemplateFile(String templateId) async {
    final dir = await _getStorageDir();
    final file = File('${dir.path}/$templateId.json');
    if (await file.exists()) {
      await file.delete();
    }
  }
}
