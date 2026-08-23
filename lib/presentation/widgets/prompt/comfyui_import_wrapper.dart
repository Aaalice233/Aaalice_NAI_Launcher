import 'package:flutter/material.dart';

import '../../../core/utils/comfyui_prompt_parser.dart';
import '../../../core/utils/nai_multi_character_prompt_codec.dart';
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
    final insertedText = _insertedText(oldText, newText);
    if (insertedText.contains('|')) {
      final naiPrompt = NaiMultiCharacterPromptCodec.tryDecode(newText);
      if (naiPrompt != null) {
        _applyNaiMultiCharacterPrompt(naiPrompt);
        return;
      }
    }

    final lengthDiff = newText.length - oldText.length;
    if (lengthDiff < 20) return; // 忽略较短的非 NAI 文本变化
    if (!ComfyuiPromptParser.isComfyuiMultiCharacter(newText)) return;
    final parseResult = ComfyuiPromptParser.tryParse(newText);
    if (parseResult == null || !parseResult.hasCharacters) return;
    _showImportDialog(parseResult);
  }

  void _applyNaiMultiCharacterPrompt(NaiMultiCharacterPrompt prompt) {
    _isProcessing = true;
    try {
      final characters = [
        for (var index = 0; index < prompt.characterPrompts.length; index++)
          CharacterPrompt.create(
            name: 'Character ${index + 1}',
            prompt: prompt.characterPrompts[index],
            negativePrompt: '',
          ),
      ];
      widget.onImport?.call(prompt.basePrompt, characters);
      widget.controller.value = TextEditingValue(
        text: prompt.basePrompt,
        selection: TextSelection.collapsed(offset: prompt.basePrompt.length),
      );
    } finally {
      _isProcessing = false;
      _previousText = widget.controller.text;
    }
  }

  String _insertedText(String before, String after) {
    var prefixLength = 0;
    final commonLength = before.length < after.length
        ? before.length
        : after.length;
    while (prefixLength < commonLength &&
        before.codeUnitAt(prefixLength) == after.codeUnitAt(prefixLength)) {
      prefixLength++;
    }

    var suffixLength = 0;
    while (suffixLength < before.length - prefixLength &&
        suffixLength < after.length - prefixLength &&
        before.codeUnitAt(before.length - suffixLength - 1) ==
            after.codeUnitAt(after.length - suffixLength - 1)) {
      suffixLength++;
    }
    return after.substring(prefixLength, after.length - suffixLength);
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
        widget.onImport?.call(result.parseResult.globalPrompt, characters);

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
