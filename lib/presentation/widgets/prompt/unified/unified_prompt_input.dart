import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../core/utils/nai_prompt_formatter.dart';
import '../../../../core/utils/sd_to_nai_converter.dart';
import '../../../../data/models/character/character_prompt.dart';
import '../../../../presentation/utils/text_selection_utils.dart';
import '../../../providers/generation/generation_settings_notifiers.dart';
import '../../../providers/tag_library_page_provider.dart';
import '../../../screens/tag_library_page/widgets/entry_add_dialog.dart';
import '../../autocomplete/autocomplete_wrapper.dart';
import '../../autocomplete/autocomplete_strategy.dart';
import '../../autocomplete/strategies/local_tag_strategy.dart';
import '../../autocomplete/strategies/alias_strategy.dart';
import '../../autocomplete/strategies/cooccurrence_strategy.dart';
import '../../common/app_toast.dart';
import '../../common/weight_adjust_toolbar.dart';
import '../../../prompt_assistant/models/prompt_assistant_models.dart';
import '../../../prompt_assistant/providers/prompt_assistant_config_provider.dart';
import '../../../prompt_assistant/providers/prompt_assistant_history_provider.dart';
import '../../../prompt_assistant/providers/prompt_assistant_state_provider.dart';
import '../../../prompt_assistant/services/prompt_assistant_service.dart';
import '../../../prompt_assistant/widgets/prompt_assistant_overlay.dart';
import '../../../providers/fixed_tags_provider.dart';
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

  /// 自动补全策略 Future（异步初始化）
  Future<AutocompleteStrategy>? _autocompleteStrategyFuture;
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

  bool _shouldResetAutocompleteStrategy(UnifiedPromptInput oldWidget) {
    final oldConfig = oldWidget.config;
    final newConfig = widget.config;
    final oldAutocomplete = oldConfig.autocompleteConfig;
    final newAutocomplete = newConfig.autocompleteConfig;

    return oldConfig.enableAutocomplete != newConfig.enableAutocomplete ||
        oldAutocomplete.maxSuggestions != newAutocomplete.maxSuggestions ||
        oldAutocomplete.showTranslation != newAutocomplete.showTranslation ||
        oldAutocomplete.showCategory != newAutocomplete.showCategory ||
        oldAutocomplete.showCount != newAutocomplete.showCount ||
        oldAutocomplete.enableChineseSearch !=
            newAutocomplete.enableChineseSearch ||
        oldAutocomplete.debounceDelay != newAutocomplete.debounceDelay ||
        oldAutocomplete.minQueryLength != newAutocomplete.minQueryLength ||
        oldAutocomplete.autoInsertComma != newAutocomplete.autoInsertComma ||
        oldAutocomplete.replaceUnderscoreWithSpace !=
            newAutocomplete.replaceUnderscoreWithSpace;
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

    if (_shouldResetAutocompleteStrategy(oldWidget)) {
      _autocompleteStrategyFuture = null;
    }
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

  /// 确保自动补全策略 Future 已创建
  Future<AutocompleteStrategy> _ensureAutocompleteStrategyFuture() {
    _autocompleteStrategyFuture ??=
        LocalTagStrategy.create(ref, widget.config.autocompleteConfig).then((
          localTagStrategy,
        ) {
          return CompositeStrategy(
            strategies: [
              localTagStrategy,
              AliasStrategy.create(ref),
              CooccurrenceStrategy.create(
                ref,
                widget.config.autocompleteConfig,
              ),
            ],
            strategySelector: defaultStrategySelector,
          );
        });
    return _autocompleteStrategyFuture!;
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

    // 包装权重调整工具条
    Widget result = WeightAdjustToolbarWrapper(
      controller: _effectiveController,
      focusNode: _effectiveFocusNode,
      enableWheelAdjustment: enableWheelAdjustment,
      child: baseInput,
    );

    // 如果启用自动补全，使用 AutocompleteWrapper 包装
    if (widget.config.enableAutocomplete) {
      result = AutocompleteWrapper(
        controller: _effectiveController,
        focusNode: _effectiveFocusNode,
        asyncStrategy: _ensureAutocompleteStrategyFuture(),
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
