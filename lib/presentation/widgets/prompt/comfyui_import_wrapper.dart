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
  TextEditingValue _previousValue = const TextEditingValue();
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _previousValue = widget.controller.value;
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(ComfyuiImportWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      _previousValue = widget.controller.value;
      widget.controller.addListener(_onTextChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final newValue = widget.controller.value;
    final oldValue = _previousValue;
    _previousValue = newValue;
    if (!widget.enabled || _isProcessing || newValue.text == oldValue.text) {
      return;
    }

    final newText = newValue.text;
    final insertedText = _insertedText(oldValue, newValue);
    if (insertedText.contains('|')) {
      final naiPrompt = NaiMultiCharacterPromptCodec.tryDecode(newText);
      if (naiPrompt != null) {
        _showImportDialog(
          _toPipeParseResult(naiPrompt),
          useEmptyNegativePrompts: true,
        );
        return;
      }
    }

    // Use the inserted payload rather than net length growth. Replacing a
    // selection with a paste may leave the total length unchanged or shorter.
    if (insertedText.length < 20) return;
    if (!ComfyuiPromptParser.isComfyuiMultiCharacter(newText)) return;
    final parseResult = ComfyuiPromptParser.tryParse(newText);
    if (parseResult == null || !parseResult.hasCharacters) return;
    _showImportDialog(parseResult);
  }

  ComfyuiParseResult _toPipeParseResult(NaiMultiCharacterPrompt prompt) {
    return ComfyuiParseResult(
      globalPrompt: prompt.basePrompt,
      characters: [
        for (final characterPrompt in prompt.characterPrompts)
          ParsedCharacter(prompt: characterPrompt),
      ],
      syntaxType: ComfyuiSyntaxType.pipe,
    );
  }

  String _insertedText(TextEditingValue before, TextEditingValue after) {
    final selection = before.selection;
    if (selection.isValid && selection.end <= before.text.length) {
      final prefix = before.text.substring(0, selection.start);
      final suffix = before.text.substring(selection.end);
      final suffixStart = after.text.length - suffix.length;
      if (suffixStart >= prefix.length &&
          after.text.startsWith(prefix) &&
          after.text.endsWith(suffix)) {
        return after.text.substring(prefix.length, suffixStart);
      }
    }

    return _insertedTextFromDiff(before.text, after.text);
  }

  String _insertedTextFromDiff(String before, String after) {
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

  Future<void> _showImportDialog(
    ComfyuiParseResult parseResult, {
    bool useEmptyNegativePrompts = false,
  }) async {
    _isProcessing = true;

    try {
      final result = await ComfyuiImportDialog.show(
        context: context,
        parseResult: parseResult,
      );

      if (result != null && mounted) {
        // 转换为 NAI 角色列表
        var characters = ComfyuiPromptParser.toNaiCharacters(
          result.parseResult,
          usePosition: result.usePosition,
        );
        if (useEmptyNegativePrompts) {
          characters = [
            for (final character in characters)
              character.copyWith(negativePrompt: ''),
          ];
        }

        // 触发回调
        widget.onImport?.call(result.parseResult.globalPrompt, characters);

        // 更新输入框内容为全局提示词
        widget.controller.text = result.parseResult.globalPrompt;
      }
    } finally {
      _isProcessing = false;
      _previousValue = widget.controller.value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
