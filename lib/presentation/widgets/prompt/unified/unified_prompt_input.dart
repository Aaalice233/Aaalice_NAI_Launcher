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
  /// 内部文本控制器（当未提供外部控制器时使用）
  TextEditingController? _internalController;
  late final ValueGetter<TextEditingController> _effectiveControllerProvider;

  /// 语法高亮控制器
  NaiSyntaxController? _syntaxController;

  /// 焦点节点
  FocusNode? _internalFocusNode;

  /// 自动补全策略 Future（异步初始化）
  Future<AutocompleteStrategy>? _autocompleteStrategyFuture;
  StreamSubscription<StreamingChunk>? _assistantStreamSub;
  late String _sessionId;
  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;
  bool _searchVisible = false;
  List<TextRange> _searchMatches = const [];
  int _activeSearchMatchIndex = -1;
  String _lastSearchSourceText = '';

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
    if (!promptFocused && !searchFocused) {
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

    if (_searchVisible && searchFocused) {
      if (logicalKey == LogicalKeyboardKey.escape) {
        _closeSearch();
        return true;
      }
      if (logicalKey == LogicalKeyboardKey.enter) {
        _goToSearchMatch(previous: isShift);
        return true;
      }
    }

    if (!promptFocused || searchFocused) {
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
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
    _searchController.addListener(_onSearchQueryChanged);

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
    _internalController?.dispose();
    _syntaxController?.dispose();
    _internalFocusNode?.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
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
    if (widget.controller == null) return;

    final externalText = widget.controller!.text;

    // 同步到语法高亮控制器
    if (_syntaxController != null && _syntaxController!.text != externalText) {
      _syntaxController!.text = externalText;
    }

    if (_searchVisible && externalText != _lastSearchSourceText) {
      _refreshSearchMatches(preserveActive: true);
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

    if (_searchVisible && text != _lastSearchSourceText) {
      _refreshSearchMatches(preserveActive: true);
    }
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

  void _openSearch() {
    final selectedText = _selectedPromptText();
    final shouldUseSelection = !_searchVisible && selectedText.isNotEmpty;

    if (!_searchVisible) {
      setState(() {
        _searchVisible = true;
      });
    }

    if (shouldUseSelection) {
      _searchController.text = selectedText;
    } else {
      _refreshSearchMatches(preserveActive: false);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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

  void _refreshSearchMatches({required bool preserveActive}) {
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
    _selectActiveSearchMatch();
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

    return AdaptiveTextSelectionToolbar.buttonItems(
      buttonItems: buttonItems,
      anchors: editableTextState.contextMenuAnchors,
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
    final total = _searchMatches.length;
    final current = total == 0 ? 0 : _activeSearchMatchIndex + 1;

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
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
              children: [
                Expanded(
                  child: SizedBox(
                    height: 34,
                    child: TextField(
                      key: const ValueKey('prompt_input_search_field'),
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      textInputAction: TextInputAction.search,
                      style: theme.textTheme.bodyMedium,
                      decoration: InputDecoration(
                        hintText: context.l10n.prompt_searchHint,
                        prefixIcon: const Icon(Icons.search, size: 18),
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
                      onSubmitted: (_) => _goToSearchMatch(previous: false),
                    ),
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
                  onPressed: total == 0
                      ? null
                      : () => _goToSearchMatch(previous: true),
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
            ),
          ),
        ),
      ),
    );
  }

  /// 构建文本输入框
  Widget _buildTextField() {
    final enableWheelAdjustment = ref.watch(promptWeightScrollSettingsProvider);

    // 合并 decoration：优先使用传入的 decoration，但保留 config 中的 hintText
    final effectiveDecoration =
        InputDecoration(
          hintText: widget.config.hintText,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
        ).copyWith(
          hintText: widget.config.hintText,
          contentPadding: widget.decoration?.contentPadding,
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
}

class _PromptSearchIconButton extends StatelessWidget {
  const _PromptSearchIconButton({
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
