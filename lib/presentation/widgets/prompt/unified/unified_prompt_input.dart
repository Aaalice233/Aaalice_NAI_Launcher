import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../core/utils/nai_prompt_formatter.dart';
import '../../../../core/utils/prompt_regex_replacer.dart';
import '../../../../core/utils/sd_to_nai_converter.dart';
import '../../../../data/models/character/character_prompt.dart';
import '../../../../data/services/alias_resolver_service.dart';
import '../../../../presentation/utils/text_selection_utils.dart';
import '../../../providers/generation/generation_settings_notifiers.dart';
import '../../../providers/tag_library_page_provider.dart';
import '../../../screens/tag_library_page/widgets/entry_add_dialog.dart';
import '../../autocomplete/autocomplete_wrapper.dart';
import '../../common/app_toast.dart';
import '../../common/weight_adjust_toolbar.dart';
import '../../../prompt_assistant/models/prompt_assistant_models.dart';
import '../../../prompt_assistant/providers/prompt_assistant_config_provider.dart';
import '../../../prompt_assistant/providers/prompt_assistant_history_provider.dart';
import '../../../prompt_assistant/providers/prompt_assistant_state_provider.dart';
import '../../../prompt_assistant/services/prompt_assistant_service.dart';
import '../../../prompt_assistant/widgets/prompt_assistant_overlay.dart';
import '../../../providers/fixed_tags_provider.dart';
import '../../../providers/prompt_regex_rules_provider.dart';
import '../comfyui_import_wrapper.dart';
import '../nai_syntax_controller.dart';
import 'unified_prompt_config.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_text_selection_toolbar.dart';

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

  /// 输入区 Stack 适应内容高度而非撑满父级
  ///
  /// 用于随内容自增高的场景（如官网式布局的一体滚动列）：
  /// 父级高度无界时必须为 true，否则 StackFit.expand 会得到无穷高度约束。
  final bool fitContent;

  /// 输入框会话标识（用于历史栈隔离）
  final String? sessionId;

  /// 是否显示右下角助手
  final bool enableAssistant;

  /// 打开助手设置回调
  final VoidCallback? onOpenAssistantSettings;

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
    this.fitContent = false,
    this.sessionId,
    this.enableAssistant = true,
    this.onOpenAssistantSettings,
    this.onComfyuiImport,
  });

  @override
  ConsumerState<UnifiedPromptInput> createState() => _UnifiedPromptInputState();
}

class _UnifiedPromptInputState extends ConsumerState<UnifiedPromptInput> {
  late final ValueGetter<TextEditingController> _effectiveControllerProvider;

  /// 语法高亮控制器
  NaiSyntaxController? _syntaxController;
  bool _syncingControllerValue = false;

  /// 焦点节点
  FocusNode? _internalFocusNode;

  StreamSubscription<StreamingChunk>? _assistantStreamSub;
  late String _sessionId;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  late final TextEditingController _replaceController;
  late final FocusNode _replaceFocusNode;
  bool _searchVisible = false;
  bool _replaceVisible = false;
  List<TextRange> _searchMatches = const [];
  int _activeSearchMatchIndex = -1;
  String _lastSearchSourceText = '';

  /// 替换功能是否可用（只读模式下禁用）
  bool get _canReplace => !widget.config.readOnly;

  /// 复制/剪切时展开词库别名的 Action 映射
  ///
  /// 常量化持有，避免每帧新建 Map 触发 [Actions] 的无谓通知。
  /// 开关状态在 Action 内部按需读取，因此这里始终挂载，
  /// 切换开关不会改变 widget 树结构（不会导致输入框重建丢焦点）。
  late final Map<Type, Action<Intent>> _clipboardActions = {
    CopySelectionTextIntent: _AliasExpandingCopyAction(
      _handleExpandedClipboardAction,
    ),
  };

  bool get _isDesktop {
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
        return true;
      default:
        return false;
    }
  }

  bool _handleHardwareKeyEvent(KeyEvent event) {
    if (!_isDesktop || event is! KeyDownEvent) {
      return false;
    }

    final promptFocused = _effectiveFocusNode.hasFocus;
    final searchFocused = _searchFocusNode.hasFocus;
    final replaceFocused = _replaceFocusNode.hasFocus;
    if (!promptFocused && !searchFocused && !replaceFocused) {
      return false;
    }

    final logicalKey = event.logicalKey;

    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isMeta = HardwareKeyboard.instance.isMetaPressed;

    if ((isCtrl || isMeta) &&
        !isShift &&
        logicalKey == LogicalKeyboardKey.keyF) {
      _openSearch();
      return true;
    }

    if ((isCtrl || isMeta) &&
        !isShift &&
        _canReplace &&
        logicalKey == LogicalKeyboardKey.keyH) {
      _openSearch(showReplace: true);
      return true;
    }

    if (_searchVisible && (searchFocused || replaceFocused)) {
      if (logicalKey == LogicalKeyboardKey.escape) {
        _closeSearch();
        return true;
      }
      if (logicalKey == LogicalKeyboardKey.enter) {
        // 搜索框回车跳转命中，替换框回车替换当前命中；
        // 替换框上叠加 Ctrl/Cmd 则执行全部替换（对齐常见编辑器）。
        if (replaceFocused) {
          if (isCtrl || isMeta) {
            _replaceAllMatches();
          } else {
            _replaceActiveMatch();
          }
        } else {
          _goToSearchMatch(previous: isShift);
        }
        return true;
      }
    }

    if (!promptFocused || searchFocused || replaceFocused) {
      return false;
    }

    if (!widget.enableAssistant) {
      return false;
    }

    final assistantConfig = ref.read(promptAssistantConfigProvider);
    if (!assistantConfig.enabled || !assistantConfig.desktopOverlayEnabled) {
      return false;
    }

    if (isCtrl && isShift && logicalKey == LogicalKeyboardKey.keyE) {
      unawaited(_runAssistantAction(AssistantTaskType.llm));
      return true;
    }
    if (isCtrl && isShift && logicalKey == LogicalKeyboardKey.keyT) {
      unawaited(_runAssistantAction(AssistantTaskType.translate));
      return true;
    }

    return false;
  }

  /// 获取有效的文本控制器
  TextEditingController get _effectiveController => _syntaxController!;

  /// 获取有效的焦点节点
  FocusNode get _effectiveFocusNode {
    return widget.focusNode ?? _internalFocusNode!;
  }

  String _resolveSessionId(String? sessionId) {
    final providedSessionId = sessionId?.trim();
    if (providedSessionId != null && providedSessionId.isNotEmpty) {
      return providedSessionId;
    }
    return 'prompt_${identityHashCode(this)}';
  }

  @override
  void initState() {
    super.initState();
    _effectiveControllerProvider = () => _effectiveController;
    _sessionId = _resolveSessionId(widget.sessionId);

    // 官网的竖线装饰独立于强调开关，因此始终使用语法控制器。
    final initialText = widget.controller?.text ?? '';
    _syntaxController = NaiSyntaxController(
      text: initialText,
      highlightEnabled: widget.config.enableSyntaxHighlight,
      numericEmphasisEnabled: widget.config.numericEmphasisEnabled,
    );
    if (widget.controller != null) {
      _syntaxController!.value = widget.controller!.value;
    }
    _syntaxController!.addListener(_syncToExternalController);

    // 初始化焦点节点（如果需要）
    if (widget.focusNode == null) {
      _internalFocusNode = FocusNode();
    }
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _searchController.addListener(_onSearchQueryChanged);
    _replaceController = TextEditingController();
    _replaceFocusNode = FocusNode();

    // 监听外部控制器变化
    widget.controller?.addListener(_syncFromExternalController);

    // 监听焦点变化（用于失焦格式化）
    _effectiveFocusNode.addListener(_onFocusChanged);

    // 初始化自动补全策略（延迟到第一次 build 后，因为需要 ref）
    // 策略将在 _ensureAutocompleteStrategy 中惰性创建
    HardwareKeyboard.instance.addHandler(_handleHardwareKeyEvent);
  }

  @override
  void didUpdateWidget(UnifiedPromptInput oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldEffectiveFocusNode = oldWidget.focusNode ?? _internalFocusNode!;
    final newEffectiveFocusNode = widget.focusNode ?? _internalFocusNode!;
    if (oldEffectiveFocusNode != newEffectiveFocusNode) {
      oldEffectiveFocusNode.removeListener(_onFocusChanged);
      newEffectiveFocusNode.addListener(_onFocusChanged);
    }

    if (widget.sessionId != oldWidget.sessionId) {
      _sessionId = _resolveSessionId(widget.sessionId);
    }

    // 外部控制器变化
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_syncFromExternalController);
      widget.controller?.addListener(_syncFromExternalController);

      final updatedController = widget.controller;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(widget.controller, updatedController)) {
          _syncFromExternalController();
        }
      });
    }

    _syntaxController?.highlightEnabled = widget.config.enableSyntaxHighlight;
    _syntaxController?.numericEmphasisEnabled =
        widget.config.numericEmphasisEnabled;
  }

  @override
  void dispose() {
    _assistantStreamSub?.cancel();
    _searchController.removeListener(_onSearchQueryChanged);
    _clearSearchHighlights();
    HardwareKeyboard.instance.removeHandler(_handleHardwareKeyEvent);
    _effectiveFocusNode.removeListener(_onFocusChanged);
    widget.controller?.removeListener(_syncFromExternalController);
    _syntaxController?.removeListener(_syncToExternalController);
    _syntaxController?.dispose();
    _internalFocusNode?.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _replaceController.dispose();
    _replaceFocusNode.dispose();
    super.dispose();
  }

  Future<void> _runAssistantAction(AssistantTaskType taskType) async {
    final text = _assistantInputText().trim();
    if (text.isEmpty) {
      if (mounted) {
        AppToast.warning(context, context.l10n.promptAssistant_needPrompt);
      }
      return;
    }

    final beforeText = _effectiveController.text;
    ref
        .read(promptAssistantHistoryProvider.notifier)
        .push(_sessionId, beforeText);

    final stateNotifier = ref.read(promptAssistantStateProvider.notifier);
    final label = taskType == AssistantTaskType.llm
        ? context.l10n.promptAssistant_optimizeProcessing
        : context.l10n.promptAssistant_translateProcessing;
    stateNotifier.startProcessing(_sessionId, label);

    final service = ref.read(promptAssistantServiceProvider);
    final buffer = StringBuffer();

    await _assistantStreamSub?.cancel();
    final stream = taskType == AssistantTaskType.llm
        ? service.optimizePrompt(text, sessionId: _sessionId)
        : service.translatePrompt(text, sessionId: _sessionId);

    _assistantStreamSub = stream.listen(
      (chunk) {
        if (chunk.done) return;
        if (chunk.delta.isEmpty) return;
        buffer.write(chunk.delta);
      },
      onError: (e) {
        stateNotifier.setError(_sessionId, e.toString());
        if (mounted) {
          AppToast.error(
            context,
            context.l10n.promptAssistant_requestFailed(e),
          );
        }
      },
      onDone: () {
        if (buffer.isNotEmpty) {
          final finalText = buffer.toString();
          _effectiveController.text = finalText;
          _effectiveController.selection = TextSelection.collapsed(
            offset: _effectiveController.text.length,
          );
        }
        stateNotifier.finishProcessing(_sessionId);
        final afterText = _effectiveController.text;
        ref
            .read(promptAssistantHistoryProvider.notifier)
            .recordExternalChange(
              _sessionId,
              before: beforeText,
              after: afterText,
            );
        ref
            .read(promptAssistantHistoryProvider.notifier)
            .push(_sessionId, afterText);
      },
      cancelOnError: true,
    );
  }

  String _assistantInputText() {
    return ref
        .read(fixedTagsNotifierProvider)
        .stripFromPrompt(_effectiveController.text);
  }

  /// 焦点变化回调
  void _onFocusChanged() {
    if (!_effectiveFocusNode.hasFocus) {
      _formatOnBlur();
      ref
          .read(promptAssistantHistoryProvider.notifier)
          .push(_sessionId, _effectiveController.text);
    }
  }

  /// 失焦时格式化提示词
  void _formatOnBlur() {
    if (!widget.config.enableAutoFormat &&
        !widget.config.enableSdSyntaxAutoConvert &&
        !widget.config.enableRegexReplace) {
      return;
    }

    final originalValue = _effectiveController.value;
    var text = originalValue.text;
    if (text.isEmpty) return;

    var changed = false;
    final messages = <String>[];

    // 正则替换（最先执行，规则匹配的是用户原样输入的文本）
    if (widget.config.enableRegexReplace) {
      final rules = ref.read(promptRegexRulesProvider);
      final result = PromptRegexReplacer.apply(text, rules);
      if (result.changed) {
        text = result.text;
        changed = true;
        messages.add(
          context.l10n.prompt_regexReplaceApplied(result.appliedRules.length),
        );
      }
      if (mounted && result.invalidRules.isNotEmpty) {
        AppToast.warning(
          context,
          context.l10n.prompt_regexInvalidRules(
            result.invalidRules.map((rule) => rule.displayLabel).join(', '),
          ),
        );
      }
    }

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
      final selection = TextSelectionUtils.preserveLineAndColumnSelection(
        oldText: originalValue.text,
        newText: text,
        selection: originalValue.selection,
      );
      _effectiveController.value = originalValue.copyWith(
        text: text,
        selection: selection,
        composing: TextRange.empty,
      );
      _handleTextChanged(text);
      if (mounted && messages.isNotEmpty) {
        AppToast.info(context, messages.join(' + '));
      }
    }
  }

  /// 同步外部控制器变化到内部状态
  void _syncFromExternalController() {
    final externalController = widget.controller;
    final syntaxController = _syntaxController;
    if (externalController == null ||
        syntaxController == null ||
        _syncingControllerValue) {
      return;
    }

    final externalValue = externalController.value;

    if (syntaxController.value != externalValue) {
      _syncingControllerValue = true;
      try {
        syntaxController.value = externalValue;
      } finally {
        _syncingControllerValue = false;
      }
    }

    if (_searchVisible && externalValue.text != _lastSearchSourceText) {
      _refreshSearchMatches(preserveActive: true, selectActiveMatch: false);
    }
  }

  void _syncToExternalController() {
    final externalController = widget.controller;
    final syntaxController = _syntaxController;
    if (syntaxController == null || _syncingControllerValue) {
      return;
    }

    if (externalController != null &&
        externalController.value != syntaxController.value) {
      _syncingControllerValue = true;
      try {
        externalController.value = syntaxController.value;
      } finally {
        _syncingControllerValue = false;
      }
    }

    if (_searchVisible && syntaxController.text != _lastSearchSourceText) {
      _refreshSearchMatches(preserveActive: true, selectActiveMatch: false);
    }
  }

  /// 处理文本变化
  void _handleTextChanged(String text) {
    // 触发回调
    widget.onChanged?.call(text);

    if (_searchVisible && text != _lastSearchSourceText) {
      _refreshSearchMatches(preserveActive: true, selectActiveMatch: false);
    }
  }

  /// 处理清空操作
  void _handleClear() {
    // 不用 controller.clear()：它把 selection 置为 -1（无效），
    // 光标会消失且后续键盘输入连接错乱，需要重新点击才能恢复。
    // 显式给出光标位置 0，清空后可直接继续输入。
    const clearedValue = TextEditingValue(
      text: '',
      selection: TextSelection.collapsed(offset: 0),
    );
    _effectiveController.value = clearedValue;
    // 同步到外部控制器
    if (widget.controller != null &&
        !identical(widget.controller, _effectiveController)) {
      widget.controller!.value = clearedValue;
    }

    widget.onChanged?.call('');
    widget.config.onClearPressed?.call();
  }

  void _openSearch({bool showReplace = false}) {
    final shouldShowReplace = showReplace && _canReplace;
    final selectedText = _selectedPromptText();
    final shouldUseSelection = !_searchVisible && selectedText.isNotEmpty;
    // 搜索栏已展开且已有查询词时，Ctrl+H 直接把焦点交给替换框，
    // 避免用户还要再点一次输入框。
    final focusReplaceField =
        shouldShowReplace &&
        _searchVisible &&
        !shouldUseSelection &&
        _searchController.text.trim().isNotEmpty;

    if (!_searchVisible || (shouldShowReplace && !_replaceVisible)) {
      setState(() {
        _searchVisible = true;
        if (shouldShowReplace) {
          _replaceVisible = true;
        }
      });
    }

    if (shouldUseSelection) {
      _searchController.text = selectedText;
    } else {
      _refreshSearchMatches(preserveActive: false);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (focusReplaceField) {
        _replaceFocusNode.requestFocus();
        _replaceController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _replaceController.text.length,
        );
        return;
      }
      _searchFocusNode.requestFocus();
      _searchController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _searchController.text.length,
      );
    });
  }

  void _closeSearch() {
    if (!_searchVisible) {
      return;
    }
    setState(() {
      _searchVisible = false;
      _searchMatches = const [];
      _activeSearchMatchIndex = -1;
    });
    _clearSearchHighlights();
    _effectiveFocusNode.requestFocus();
  }

  void _toggleReplaceVisible() {
    if (!_canReplace) {
      return;
    }
    final nextVisible = !_replaceVisible;
    setState(() {
      _replaceVisible = nextVisible;
    });
    if (!nextVisible) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _replaceFocusNode.requestFocus();
    });
  }

  String _selectedPromptText() {
    final selection = _effectiveController.selection;
    final text = _effectiveController.text;
    if (!selection.isValid || selection.isCollapsed) {
      return '';
    }
    final start = selection.start.clamp(0, text.length);
    final end = selection.end.clamp(0, text.length);
    if (start >= end) {
      return '';
    }
    return text.substring(start, end);
  }

  void _onSearchQueryChanged() {
    if (!_searchVisible) {
      return;
    }
    _refreshSearchMatches(preserveActive: false);
  }

  void _refreshSearchMatches({
    required bool preserveActive,
    bool selectActiveMatch = true,
  }) {
    final sourceText = _effectiveController.text;
    final matches = _findSearchMatches(sourceText, _searchController.text);
    final activeIndex = _resolveActiveSearchIndex(
      matches,
      preserveActive: preserveActive,
    );

    setState(() {
      _searchMatches = matches;
      _activeSearchMatchIndex = activeIndex;
      _lastSearchSourceText = sourceText;
    });
    _syncSearchHighlights();
    if (selectActiveMatch) {
      _selectActiveSearchMatch();
    }
  }

  List<TextRange> _findSearchMatches(String source, String query) {
    final needle = query.trim();
    if (source.isEmpty || needle.isEmpty) {
      return const [];
    }

    final lowerSource = source.toLowerCase();
    final lowerNeedle = needle.toLowerCase();
    final matches = <TextRange>[];
    var start = 0;

    while (start < lowerSource.length) {
      final index = lowerSource.indexOf(lowerNeedle, start);
      if (index < 0) {
        break;
      }
      matches.add(TextRange(start: index, end: index + needle.length));
      start = index + needle.length;
    }

    return matches;
  }

  int _resolveActiveSearchIndex(
    List<TextRange> matches, {
    required bool preserveActive,
  }) {
    if (matches.isEmpty) {
      return -1;
    }
    if (preserveActive &&
        _activeSearchMatchIndex >= 0 &&
        _activeSearchMatchIndex < matches.length) {
      return _activeSearchMatchIndex;
    }
    final selection = _effectiveController.selection;
    if (selection.isValid) {
      final index = matches.indexWhere((match) => match.start >= selection.end);
      if (index >= 0) {
        return index;
      }
    }
    return 0;
  }

  void _goToSearchMatch({required bool previous}) {
    if (_searchMatches.isEmpty) {
      return;
    }
    final nextIndex = previous
        ? (_activeSearchMatchIndex - 1 + _searchMatches.length) %
              _searchMatches.length
        : (_activeSearchMatchIndex + 1) % _searchMatches.length;

    setState(() {
      _activeSearchMatchIndex = nextIndex;
    });
    _syncSearchHighlights();
    _selectActiveSearchMatch();
  }

  void _selectActiveSearchMatch() {
    if (_activeSearchMatchIndex < 0 ||
        _activeSearchMatchIndex >= _searchMatches.length) {
      return;
    }
    final match = _searchMatches[_activeSearchMatchIndex];
    _effectiveController.selection = TextSelection(
      baseOffset: match.start,
      extentOffset: match.end,
    );
  }

  bool get _canRunReplace =>
      _canReplace && _searchMatches.isNotEmpty && _searchQueryIsValid;

  bool get _searchQueryIsValid => _searchController.text.trim().isNotEmpty;

  /// 替换当前命中，并把光标折叠到替换文本末尾。
  ///
  /// 光标位置决定了 [_resolveActiveSearchIndex] 选中的下一个命中，
  /// 因此替换后会自然跳到后一处，替换文本本身包含查询词时也不会自我循环。
  void _replaceActiveMatch() {
    if (!_canRunReplace) {
      return;
    }
    if (_activeSearchMatchIndex < 0 ||
        _activeSearchMatchIndex >= _searchMatches.length) {
      return;
    }

    final source = _effectiveController.text;
    final match = _searchMatches[_activeSearchMatchIndex];
    if (match.start < 0 || match.end > source.length) {
      return;
    }

    final replacement = _replaceController.text;
    final newText = source.replaceRange(match.start, match.end, replacement);
    _applyReplacedText(
      newText,
      caretOffset: match.start + replacement.length,
      selectNextMatch: true,
    );
  }

  /// 全部替换。
  ///
  /// 命中区间由 [_findSearchMatches] 保证互不重叠且按升序排列，
  /// 因此可以一次线性拼接，不必反向逐个 replaceRange。
  void _replaceAllMatches() {
    if (!_canRunReplace) {
      return;
    }

    final source = _effectiveController.text;
    final replacement = _replaceController.text;
    final buffer = StringBuffer();
    var cursor = 0;
    var replacedCount = 0;
    var caretOffset = 0;

    for (final match in _searchMatches) {
      if (match.start < cursor || match.end > source.length) {
        continue;
      }
      buffer.write(source.substring(cursor, match.start));
      buffer.write(replacement);
      cursor = match.end;
      caretOffset = buffer.length;
      replacedCount++;
    }
    if (replacedCount == 0) {
      return;
    }
    buffer.write(source.substring(cursor));

    final newText = _postProcessReplacedText(buffer.toString());
    _applyReplacedText(
      newText,
      caretOffset: caretOffset,
      selectNextMatch: false,
      // 全部替换是一次性的批量改写，纳入外部历史栈后可用助手浮层撤销。
      recordHistory: true,
    );

    if (mounted) {
      AppToast.info(context, context.l10n.prompt_replaceAllDone(replacedCount));
    }
  }

  /// 全部替换后的文本清理。
  ///
  /// 提示词是逗号分隔的标签串，把某个标签整体替换为空串后会残留
  /// `alpha, , beta` 这样的空位。这里决定要不要以及如何收拾残局。
  ///
  /// TODO(用户实现)：见下方说明，可选择保持原样、收敛空标签，或整体格式化。
  String _postProcessReplacedText(String text) {
    return text;
  }

  /// 写回替换结果，并保持内部/外部控制器与搜索高亮一致。
  void _applyReplacedText(
    String newText, {
    required int caretOffset,
    required bool selectNextMatch,
    bool recordHistory = false,
  }) {
    final beforeText = _effectiveController.text;
    if (newText == beforeText) {
      return;
    }

    final value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: caretOffset.clamp(0, newText.length),
      ),
    );
    _effectiveController.value = value;
    // 与 _handleClear 一致：外部控制器不是同一实例时显式同步。
    if (widget.controller != null &&
        !identical(widget.controller, _effectiveController)) {
      widget.controller!.value = value;
    }

    // 程序化改写不会触发 TextField.onChanged，需要手动通知外部。
    widget.onChanged?.call(newText);

    if (recordHistory) {
      ref
          .read(promptAssistantHistoryProvider.notifier)
          .recordExternalChange(_sessionId, before: beforeText, after: newText);
    }

    _refreshSearchMatches(
      preserveActive: false,
      selectActiveMatch: selectNextMatch,
    );
  }

  void _syncSearchHighlights() {
    final controller = _effectiveController;
    if (controller is NaiSyntaxController) {
      controller.updateSearchHighlights(
        matches: _searchMatches,
        activeMatchIndex: _activeSearchMatchIndex,
      );
    }
  }

  void _clearSearchHighlights() {
    final controller = _effectiveController;
    if (controller is NaiSyntaxController) {
      controller.clearSearchHighlights();
    }
  }

  /// 构建自定义上下文菜单，添加"保存到词库"选项
  /// 接管复制/剪切，把选区里的 `<词库名>` 展开后写入剪贴板
  ///
  /// 返回 true 表示已完全接管，调用方**不得**再执行系统默认的复制实现。
  ///
  /// 必须完全接管而不是"先默认、后覆盖"：Windows 剪贴板是全局独占资源，
  /// 紧挨着的第二次写入可能因 `OpenClipboard` 被上一次的锁或剪贴板管理器
  /// 抢占而静默失败，结果剪贴板里留下的是未展开的原文。
  /// 只写一次才能保证结果确定。
  ///
  /// 以下情况返回 false，交回默认行为（此时默认行为是唯一的一次写入）：
  /// 开关关闭、没有选区、选区里不含可解析的 `<词库名>`。
  /// 未在词库中找到的引用由 [AliasResolverService] 原样保留，同样走默认路径。
  bool _handleExpandedClipboardAction({required bool isCut}) {
    if (!ref.read(resolveAliasOnCopySettingsProvider)) return false;

    final controller = _effectiveController;
    final selection = controller.selection;
    if (!selection.isValid || selection.isCollapsed) return false;

    final text = controller.text;
    final selectedText = selection.textInside(text);
    if (selectedText.isEmpty) return false;

    final expanded = ref
        .read(aliasResolverServiceProvider.notifier)
        .resolveAliases(selectedText);
    if (expanded == selectedText) return false;

    unawaited(Clipboard.setData(ClipboardData(text: expanded)));

    // 剪切需要自行删除选中文本：默认实现会连带再写一次剪贴板，不能复用
    if (isCut && !widget.config.readOnly) {
      final newValue = TextEditingValue(
        text: selection.textBefore(text) + selection.textAfter(text),
        selection: TextSelection.collapsed(offset: selection.start),
      );
      controller.value = newValue;
      // 同步到外部控制器（与 _handleClear 保持一致）
      if (widget.controller != null &&
          !identical(widget.controller, controller)) {
        widget.controller!.value = newValue;
      }
      _handleTextChanged(newValue.text);
    }

    return true;
  }

  Widget _buildContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    final selectedText = TextSelectionUtils.getSelectedText(
      _effectiveController,
    );
    final hasSelection = selectedText.isNotEmpty;

    // 获取默认的上下文菜单项
    final List<ContextMenuButtonItem> buttonItems =
        editableTextState.contextMenuButtonItems;

    // 右键菜单的复制/剪切直接调用 EditableTextState，不经过 Actions 系统，
    // 因此需要在这里单独接管，保证与 Ctrl+C / Ctrl+X 行为一致
    for (var i = 0; i < buttonItems.length; i++) {
      final item = buttonItems[i];
      if (item.type != ContextMenuButtonType.copy &&
          item.type != ContextMenuButtonType.cut) {
        continue;
      }
      final defaultOnPressed = item.onPressed;
      final isCut = item.type == ContextMenuButtonType.cut;
      buttonItems[i] = ContextMenuButtonItem(
        type: item.type,
        label: item.label,
        onPressed: () {
          if (_handleExpandedClipboardAction(isCut: isCut)) {
            editableTextState.hideToolbar();
            return;
          }
          defaultOnPressed?.call();
        },
      );
    }

    // 如果有选中文本，添加"保存到词库"选项
    if (hasSelection) {
      buttonItems.insert(
        0,
        ContextMenuButtonItem(
          onPressed: () {
            editableTextState.hideToolbar();
            _showSaveToLibraryDialog(context, selectedText);
          },
          label: context.l10n.tagLibrary_saveToLibrary,
        ),
      );
    }

    return buildThemedTextSelectionToolbar(
      context,
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: buttonItems,
    );
  }

  /// 显示保存到词库对话框
  Future<void> _showSaveToLibraryDialog(
    BuildContext context,
    String selectedText,
  ) async {
    final categories = ref.read(tagLibraryPageCategoriesProvider);

    await showDialog<void>(
      context: context,
      builder: (context) => EntryAddDialog(
        categories: categories,
        entry: null,
        initialContent: selectedText,
      ),
    );

    // 注意：EntryAddDialog 会自己处理保存逻辑并显示 toast
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

    final inputStack = Stack(
      fit: widget.fitContent ? StackFit.loose : StackFit.expand,
      children: [
        result,
        if (widget.enableAssistant)
          PromptAssistantOverlay(
            sessionId: _sessionId,
            controller: _effectiveController,
            onOpenSettings: widget.onOpenAssistantSettings,
          ),
      ],
    );

    if (!_searchVisible) {
      return inputStack;
    }

    if (widget.expands) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSearchToolbar(context),
          const SizedBox(height: 8),
          Expanded(child: inputStack),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSearchToolbar(context),
        const SizedBox(height: 8),
        inputStack,
      ],
    );
  }

  Widget _buildSearchToolbar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final showReplaceRow = _canReplace && _replaceVisible;

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: _canReplace ? 400 : 360),
        child: Material(
          elevation: 0,
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.7),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_canReplace)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: _PromptSearchIconButton(
                      key: const ValueKey('prompt_input_replace_toggle'),
                      icon: _replaceVisible
                          ? Icons.keyboard_arrow_down
                          : Icons.keyboard_arrow_right,
                      tooltip: context.l10n.prompt_replaceToggle,
                      onPressed: _toggleReplaceVisible,
                    ),
                  ),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSearchRow(context, theme, colorScheme),
                      if (showReplaceRow) ...[
                        const SizedBox(height: 6),
                        _buildReplaceRow(context, theme, colorScheme),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchRow(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final total = _searchMatches.length;
    final current = total == 0 ? 0 : _activeSearchMatchIndex + 1;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: _buildToolbarField(
            context: context,
            theme: theme,
            colorScheme: colorScheme,
            fieldKey: const ValueKey('prompt_input_search_field'),
            controller: _searchController,
            focusNode: _searchFocusNode,
            hintText: context.l10n.prompt_searchHint,
            prefixIcon: Icons.search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _goToSearchMatch(previous: false),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          context.l10n.prompt_searchMatchCount(current, total),
          style: theme.textTheme.labelMedium?.copyWith(
            color: total == 0 && _searchController.text.isNotEmpty
                ? colorScheme.error
                : colorScheme.onSurfaceVariant,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(width: 2),
        _PromptSearchIconButton(
          icon: Icons.keyboard_arrow_up,
          tooltip: context.l10n.prompt_searchPrevious,
          onPressed: total == 0 ? null : () => _goToSearchMatch(previous: true),
        ),
        _PromptSearchIconButton(
          icon: Icons.keyboard_arrow_down,
          tooltip: context.l10n.prompt_searchNext,
          onPressed: total == 0
              ? null
              : () => _goToSearchMatch(previous: false),
        ),
        _PromptSearchIconButton(
          icon: Icons.close,
          tooltip: context.l10n.prompt_searchClose,
          onPressed: _closeSearch,
        ),
      ],
    );
  }

  Widget _buildReplaceRow(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
  ) {
    final canRun = _canRunReplace;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(
          child: _buildToolbarField(
            context: context,
            theme: theme,
            colorScheme: colorScheme,
            fieldKey: const ValueKey('prompt_input_replace_field'),
            controller: _replaceController,
            focusNode: _replaceFocusNode,
            hintText: context.l10n.prompt_replaceHint,
            prefixIcon: Icons.find_replace,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _replaceActiveMatch(),
          ),
        ),
        const SizedBox(width: 2),
        _PromptSearchIconButton(
          key: const ValueKey('prompt_input_replace_current'),
          icon: Icons.find_replace,
          tooltip: context.l10n.prompt_replaceCurrent,
          onPressed: canRun ? _replaceActiveMatch : null,
        ),
        _PromptSearchIconButton(
          key: const ValueKey('prompt_input_replace_all'),
          icon: Icons.done_all,
          tooltip: context.l10n.prompt_replaceAll,
          onPressed: canRun ? _replaceAllMatches : null,
        ),
      ],
    );
  }

  Widget _buildToolbarField({
    required BuildContext context,
    required ThemeData theme,
    required ColorScheme colorScheme,
    required Key fieldKey,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hintText,
    required IconData prefixIcon,
    required TextInputAction textInputAction,
    required ValueChanged<String> onSubmitted,
  }) {
    return SizedBox(
      height: 34,
      child: TextField(
        key: fieldKey,
        controller: controller,
        focusNode: focusNode,
        textInputAction: textInputAction,
        style: theme.textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(prefixIcon, size: 18),
          isDense: true,
          filled: true,
          fillColor: colorScheme.surface.withValues(alpha: 0.86),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(9),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
        ),
        onSubmitted: onSubmitted,
      ),
    );
  }

  /// 构建文本输入框
  Widget _buildTextField() {
    final enableWheelAdjustment = ref.watch(promptWeightScrollSettingsProvider);
    final assistantConfig = widget.enableAssistant
        ? ref.watch(promptAssistantConfigProvider)
        : null;
    final shouldReserveAssistantSpace =
        assistantConfig != null &&
        assistantConfig.enabled &&
        (!_isDesktop || assistantConfig.desktopOverlayEnabled);
    final requestedContentPadding =
        widget.decoration?.contentPadding ??
        const EdgeInsets.symmetric(horizontal: 12, vertical: 10);
    final effectiveContentPadding = _withAssistantBottomClearance(
      requestedContentPadding,
      reserveSpace: shouldReserveAssistantSpace,
    );

    // 合并 decoration：优先使用传入的 decoration，但保留 config 中的 hintText
    final effectiveDecoration =
        InputDecoration(
          hintText: widget.config.hintText,
          contentPadding: effectiveContentPadding,
        ).copyWith(
          hintText: widget.config.hintText,
          filled: widget.decoration?.filled,
          fillColor: widget.decoration?.fillColor,
          border: widget.decoration?.border,
          enabledBorder: widget.decoration?.enabledBorder,
          focusedBorder: widget.decoration?.focusedBorder,
          errorBorder: widget.decoration?.errorBorder,
          focusedErrorBorder: widget.decoration?.focusedErrorBorder,
          prefixIcon: widget.decoration?.prefixIcon,
          suffixIcon: widget.decoration?.suffixIcon,
          prefix: widget.decoration?.prefix,
          suffix: widget.decoration?.suffix,
          labelText: widget.decoration?.labelText,
          labelStyle: widget.decoration?.labelStyle,
          floatingLabelStyle: widget.decoration?.floatingLabelStyle,
          helperText: widget.decoration?.helperText,
          helperStyle: widget.decoration?.helperStyle,
          errorText: widget.decoration?.errorText,
          errorStyle: widget.decoration?.errorStyle,
          counterText: widget.decoration?.counterText,
          counterStyle: widget.decoration?.counterStyle,
          isDense: widget.decoration?.isDense,
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
      scrollPhysics:
          enableWheelAdjustment &&
              supportsPromptWeightScrollPhysics(defaultTargetPlatform)
          ? WeightAdjustScrollPhysics(
              controllerProvider: _effectiveControllerProvider,
            )
          : null,
      textAlignVertical: widget.expands ? TextAlignVertical.top : null,
      readOnly: widget.config.readOnly,
      inputFormatters: widget.config.readOnly
          ? null
          : [
              TextInputFormatter.withFunction((oldValue, newValue) {
                return TextSelectionUtils.wrapSelectionOnBracketReplacement(
                  oldValue,
                  newValue,
                );
              }),
            ],
      onChanged: widget.config.enableAutocomplete ? null : _handleTextChanged,
      onSubmitted: widget.onSubmitted,
      showClearButton: widget.config.showClearButton,
      onClearPressed: widget.config.showClearButton ? _handleClear : null,
      clearNeedsConfirm: widget.config.clearNeedsConfirm,
      contextMenuBuilder: _buildContextMenu,
    );

    // 接管 Ctrl+C / Ctrl+X：覆盖 EditableText 内置的 CopySelectionTextIntent
    final clipboardAwareInput = Actions(
      actions: _clipboardActions,
      child: baseInput,
    );

    // 包装权重调整工具条
    Widget result = WeightAdjustToolbarWrapper(
      controller: _effectiveController,
      focusNode: _effectiveFocusNode,
      enableWheelAdjustment: enableWheelAdjustment,
      child: clipboardAwareInput,
    );

    // 如果启用自动补全，使用 AutocompleteWrapper 包装
    if (widget.config.enableAutocomplete) {
      result = AutocompleteWrapper(
        controller: _effectiveController,
        focusNode: _effectiveFocusNode,
        config: widget.config.autocompleteConfig,
        enabled: !widget.config.readOnly,
        onChanged: _handleTextChanged,
        contentPadding: effectiveDecoration.contentPadding,
        maxLines: widget.maxLines,
        expands: widget.expands,
        child: result,
      );
    }

    return result;
  }

  EdgeInsetsGeometry _withAssistantBottomClearance(
    EdgeInsetsGeometry contentPadding, {
    required bool reserveSpace,
  }) {
    if (!reserveSpace) {
      return contentPadding;
    }

    final resolved = contentPadding.resolve(Directionality.of(context));
    if (resolved.bottom >= PromptAssistantOverlay.contentBottomClearance) {
      return resolved;
    }
    return resolved.copyWith(
      bottom: PromptAssistantOverlay.contentBottomClearance,
    );
  }
}

/// 复制/剪切时把 `<词库名>` 展开为词库内容的 Action
///
/// [EditableText] 的内置编辑 Action 均由 [Action.overridable] 注册，
/// 祖先节点提供同类型 Action 即可合法覆盖，并通过 [callingAction]
/// 回调到默认实现。
///
/// 需要展开时完全接管（默认实现一次都不调用），否则剪贴板会被写两次，
/// 而 Windows 上第二次写入可能静默失败；不需要展开时原样交回默认实现，
/// 平台相关的选区折叠、工具栏隐藏等行为保持不变。
class _AliasExpandingCopyAction extends Action<CopySelectionTextIntent> {
  _AliasExpandingCopyAction(this.handleExpanded);

  /// 返回 true 表示已接管本次复制/剪切
  final bool Function({required bool isCut}) handleExpanded;

  @override
  Object? invoke(CopySelectionTextIntent intent) {
    // collapseSelection 为 true 即剪切
    if (handleExpanded(isCut: intent.collapseSelection)) {
      return null;
    }
    return callingAction?.invoke(intent);
  }

  @override
  bool get isActionEnabled => callingAction?.isActionEnabled ?? false;

  @override
  bool consumesKey(CopySelectionTextIntent intent) =>
      callingAction?.consumesKey(intent) ?? false;
}

class _PromptSearchIconButton extends StatelessWidget {
  const _PromptSearchIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 18),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 30, height: 30),
    );
  }
}
