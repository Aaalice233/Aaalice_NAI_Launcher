import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../core/utils/nai_prompt_formatter.dart';
import '../../../../core/utils/sd_to_nai_converter.dart';
import '../../../../data/models/character/character_prompt.dart';
import '../../autocomplete/autocomplete_wrapper.dart';
import '../../autocomplete/autocomplete_strategy.dart';
import '../../autocomplete/strategies/local_tag_strategy.dart';
import '../../autocomplete/strategies/alias_strategy.dart';
import '../../common/app_toast.dart';
import '../comfyui_import_wrapper.dart';
import '../nai_syntax_controller.dart';
import 'unified_prompt_config.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';

/// 统一提示词输入组件
///
/// 文本输入组件，支持：
/// - 自动补全
/// - 语法高亮
/// - 自动格式化
///
/// 使用示例：
/// ```dart
/// UnifiedPromptInput(
///   config: UnifiedPromptConfig.characterEditor,
///   controller: _promptController,
///   onChanged: (text) => print('Text changed: $text'),
/// )
/// ```
class UnifiedPromptInput extends ConsumerStatefulWidget {
  /// 配置
  final UnifiedPromptConfig config;

  /// 外部文本控制器（可选）
  /// 如果提供，组件将使用此控制器并同步状态
  final TextEditingController? controller;

  /// 焦点节点（可选）
  final FocusNode? focusNode;

  /// 输入装饰
  final InputDecoration? decoration;

  /// 文本变化回调
  final ValueChanged<String>? onChanged;

  /// 提交回调（按 Enter 键时触发，不阻止 Shift+Enter 换行）
  final ValueChanged<String>? onSubmitted;

  /// 最大行数
  final int? maxLines;

  /// 最小行数
  final int? minLines;

  /// 是否扩展填满空间
  final bool expands;

  /// ComfyUI 多角色导入回调
  ///
  /// 当用户确认导入 ComfyUI 格式的多角色提示词时触发。
  /// [globalPrompt] 全局提示词，用于替换主输入框内容
  /// [characters] 角色列表，用于替换角色配置
  final void Function(String globalPrompt, List<CharacterPrompt> characters)?
      onComfyuiImport;

  const UnifiedPromptInput({
    super.key,
    this.config = const UnifiedPromptConfig(),
    this.controller,
    this.focusNode,
    this.decoration,
    this.onChanged,
    this.onSubmitted,
    this.maxLines,
    this.minLines,
    this.expands = false,
    this.onComfyuiImport,
  });

  @override
  ConsumerState<UnifiedPromptInput> createState() => _UnifiedPromptInputState();
}

class _UnifiedPromptInputState extends ConsumerState<UnifiedPromptInput> {
  /// 内部文本控制器（当未提供外部控制器时使用）
  TextEditingController? _internalController;

  /// 语法高亮控制器
  NaiSyntaxController? _syntaxController;

  /// 焦点节点
  FocusNode? _internalFocusNode;

  /// 自动补全策略（在 initState 中创建，避免每次 build 重新创建）
  CompositeStrategy? _autocompleteStrategy;

  /// 获取有效的文本控制器
  TextEditingController get _effectiveController {
    if (widget.config.enableSyntaxHighlight) {
      return _syntaxController!;
    }
    return widget.controller ?? _internalController!;
  }

  /// 获取有效的焦点节点
  FocusNode get _effectiveFocusNode {
    return widget.focusNode ?? _internalFocusNode!;
  }

  @override
  void initState() {
    super.initState();

    // 初始化内部控制器（如果需要）
    if (widget.controller == null) {
      _internalController = TextEditingController();
    }

    // 初始化语法高亮控制器
    if (widget.config.enableSyntaxHighlight) {
      final initialText = widget.controller?.text ?? '';
      _syntaxController = NaiSyntaxController(
        text: initialText,
        highlightEnabled: true,
      );
    }

    // 初始化焦点节点（如果需要）
    if (widget.focusNode == null) {
      _internalFocusNode = FocusNode();
    }

    // 监听外部控制器变化
    widget.controller?.addListener(_syncFromExternalController);

    // 监听焦点变化（用于失焦格式化）
    _effectiveFocusNode.addListener(_onFocusChanged);

    // 初始化自动补全策略（延迟到第一次 build 后，因为需要 ref）
    // 策略将在 _ensureAutocompleteStrategy 中惰性创建
  }

  @override
  void didUpdateWidget(UnifiedPromptInput oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 外部控制器变化
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_syncFromExternalController);
      widget.controller?.addListener(_syncFromExternalController);

      if (widget.controller == null && _internalController == null) {
        _internalController = TextEditingController();
      }

      _syncFromExternalController();
    }

    // 语法高亮配置变化
    if (widget.config.enableSyntaxHighlight !=
        oldWidget.config.enableSyntaxHighlight) {
      if (widget.config.enableSyntaxHighlight && _syntaxController == null) {
        // 使用旧的配置获取当前文本，避免在 _syntaxController 为 null 时访问 _effectiveController
        final currentText = oldWidget.config.enableSyntaxHighlight
            ? widget.controller?.text ?? _internalController?.text ?? ''
            : widget.controller?.text ?? _internalController?.text ?? '';
        _syntaxController = NaiSyntaxController(
          text: currentText,
          highlightEnabled: true,
        );
      } else if (!widget.config.enableSyntaxHighlight &&
          _syntaxController != null) {
        // 禁用语法高亮时，释放资源
        _syntaxController?.dispose();
        _syntaxController = null;
      }
    }
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_onFocusChanged);
    widget.controller?.removeListener(_syncFromExternalController);
    _internalController?.dispose();
    _syntaxController?.dispose();
    _internalFocusNode?.dispose();
    _autocompleteStrategy?.dispose();
    super.dispose();
  }

  /// 焦点变化回调
  void _onFocusChanged() {
    if (!_effectiveFocusNode.hasFocus) {
      _formatOnBlur();
    }
  }

  /// 失焦时格式化提示词
  void _formatOnBlur() {
    if (!widget.config.enableAutoFormat &&
        !widget.config.enableSdSyntaxAutoConvert) {
      return;
    }

    var text = _effectiveController.text;
    if (text.isEmpty) return;

    var changed = false;
    final messages = <String>[];

    // SD 语法自动转换（优先于格式化，因为格式化可能会影响转换结果）
    if (widget.config.enableSdSyntaxAutoConvert) {
      final converted = SdToNaiConverter.convert(text);
      if (converted != text) {
        text = converted;
        changed = true;
        messages.add('SD→NAI');
      }
    }

    // 自动格式化
    if (widget.config.enableAutoFormat) {
      final formatted = NaiPromptFormatter.format(text);
      if (formatted != text) {
        text = formatted;
        changed = true;
        if (!messages.contains('SD→NAI')) {
          messages.add(context.l10n.prompt_formatted);
        }
      }
    }

    if (changed) {
      _effectiveController.text = text;
      _handleTextChanged(text);
      if (mounted && messages.isNotEmpty) {
        AppToast.info(context, messages.join(' + '));
      }
    }
  }

  /// 确保自动补全策略已创建
  CompositeStrategy _ensureAutocompleteStrategy() {
    _autocompleteStrategy ??= CompositeStrategy(
      strategies: [
        LocalTagStrategy.create(ref, widget.config.autocompleteConfig),
        AliasStrategy.create(ref),
      ],
      strategySelector: defaultStrategySelector,
    );
    return _autocompleteStrategy!;
  }

  /// 同步外部控制器变化到内部状态
  void _syncFromExternalController() {
    if (widget.controller == null) return;

    final externalText = widget.controller!.text;

    // 同步到语法高亮控制器
    if (_syntaxController != null && _syntaxController!.text != externalText) {
      _syntaxController!.text = externalText;
    }
  }

  /// 处理文本变化
  void _handleTextChanged(String text) {
    // 同步到外部控制器
    if (widget.controller != null && widget.controller!.text != text) {
      widget.controller!.text = text;
    }

    // 触发回调
    widget.onChanged?.call(text);
  }

  /// 处理清空操作
  void _handleClear() {
    _effectiveController.clear();
    // 同步到外部控制器
    if (widget.controller != null) {
      widget.controller!.clear();
    }

    widget.onChanged?.call('');
    widget.config.onClearPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    Widget result = _buildTextField();

    // 如果启用 ComfyUI 导入，包装 ComfyuiImportWrapper
    if (widget.config.enableComfyuiImport && widget.onComfyuiImport != null) {
      result = ComfyuiImportWrapper(
        controller: _effectiveController,
        enabled: !widget.config.readOnly,
        onImport: widget.onComfyuiImport,
        child: result,
      );
    }

    return result;
  }

  /// 构建文本输入框
  Widget _buildTextField() {
    final effectiveDecoration = widget.decoration ??
        InputDecoration(
          hintText: widget.config.hintText,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        );

    // 构建基础 ThemedInput
    // 注意：focusNode 必须始终传给 ThemedInput，
    // 否则 TextField 会创建自己的内部 focusNode，
    // 导致 _onFocusChanged 监听不到失焦事件
    final baseInput = ThemedInput(
      controller: _effectiveController,
      focusNode: _effectiveFocusNode,
      decoration: effectiveDecoration,
      maxLines: widget.expands ? null : widget.maxLines,
      minLines: widget.expands ? null : (widget.minLines ?? 1),
      expands: widget.expands,
      textAlignVertical: widget.expands ? TextAlignVertical.top : null,
      readOnly: widget.config.readOnly,
      onChanged: widget.config.enableAutocomplete ? null : _handleTextChanged,
      onSubmitted: widget.onSubmitted,
      showClearButton: widget.config.showClearButton,
      onClearPressed: widget.config.showClearButton ? _handleClear : null,
      clearNeedsConfirm: widget.config.clearNeedsConfirm,
    );

    // 如果启用自动补全，使用 AutocompleteWrapper 包装
    if (widget.config.enableAutocomplete) {
      return AutocompleteWrapper(
        controller: _effectiveController,
        focusNode: _effectiveFocusNode,
        strategy: _ensureAutocompleteStrategy(),
        enabled: !widget.config.readOnly,
        onChanged: _handleTextChanged,
        contentPadding: effectiveDecoration.contentPadding,
        maxLines: widget.maxLines,
        expands: widget.expands,
        child: baseInput,
      );
    }

    // 不启用自动补全，直接返回基础输入框
    return baseInput;
  }
}
