import 'package:flutter/material.dart';

import '../../../core/utils/comfyui_prompt_parser.dart';
import '../../../data/models/character/character_prompt.dart';
import 'comfyui_import_dialog.dart';

/// ComfyUI 导入包装器
///
/// 监听文本变化，检测 ComfyUI 多角色语法并弹出导入确认框
class ComfyuiImportWrapper extends StatefulWidget {
  /// 被包装的子组件
  final Widget child;

  /// 文本控制器
  final TextEditingController controller;

  /// 是否启用检测
  final bool enabled;

  /// 导入成功回调
  ///
  /// [globalPrompt] 全局提示词，用于替换主输入框内容
  /// [characters] 角色列表，用于替换角色配置
  final void Function(String globalPrompt, List<CharacterPrompt> characters)?
      onImport;

  const ComfyuiImportWrapper({
    super.key,
    required this.child,
    required this.controller,
    this.enabled = true,
    this.onImport,
  });

  @override
  State<ComfyuiImportWrapper> createState() => _ComfyuiImportWrapperState();
}

class _ComfyuiImportWrapperState extends State<ComfyuiImportWrapper> {
  String _previousText = '';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _previousText = widget.controller.text;
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(ComfyuiImportWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      _previousText = widget.controller.text;
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    if (!widget.enabled || _isProcessing) return;

    final newText = widget.controller.text;
    final oldText = _previousText;
    _previousText = newText;

    // 检测粘贴行为：文本长度变化超过阈值
    // 粘贴通常是一次性添加大量文本
    final lengthDiff = newText.length - oldText.length;
    if (lengthDiff < 20) return; // 忽略小的文本变化

    // 快速检测是否为 ComfyUI 语法
    if (!ComfyuiPromptParser.isComfyuiMultiCharacter(newText)) return;

    // 尝试解析
    final parseResult = ComfyuiPromptParser.tryParse(newText);
    if (parseResult == null || !parseResult.hasCharacters) return;

    // 弹出确认框
    _showImportDialog(parseResult);
  }

  Future<void> _showImportDialog(ComfyuiParseResult parseResult) async {
    _isProcessing = true;

    try {
      final result = await ComfyuiImportDialog.show(
        context: context,
        parseResult: parseResult,
      );

      if (result != null && mounted) {
        // 转换为 NAI 角色列表
        final characters = ComfyuiPromptParser.toNaiCharacters(
          result.parseResult,
          usePosition: result.usePosition,
        );

        // 触发回调
        widget.onImport?.call(
          result.parseResult.globalPrompt,
          characters,
        );

        // 更新输入框内容为全局提示词
        widget.controller.text = result.parseResult.globalPrompt;
      }
    } finally {
      _isProcessing = false;
      _previousText = widget.controller.text;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
