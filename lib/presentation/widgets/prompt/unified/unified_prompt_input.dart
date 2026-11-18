import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../data/models/character/character_prompt.dart';
import '../../../../data/models/prompt_assistant/prompt_assistant_models.dart';
import '../../../prompt_assistant/providers/prompt_assistant_config_provider.dart';
import '../../../prompt_assistant/providers/prompt_assistant_history_provider.dart';
import '../../../providers/generation/generation_settings_notifiers.dart';
import '../../../providers/prompt_editor_preferences_provider.dart';
import '../../common/app_toast.dart';
import '../nai_syntax_controller.dart';
import 'prompt_search_session.dart';
import 'prompt_search_toolbar.dart';
import 'unified_prompt_clipboard.dart';
import 'unified_prompt_config.dart';
import 'unified_prompt_field_builder.dart';
import 'unified_prompt_text_actions.dart';

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

  /// 编辑色面；未指定时沿用共享输入框色面。
  final Color? surfaceColor;

  /// 文本变化回调；宿主经 [controller] 写入的文本不会回调
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

  /// 是否启用助手（输入框快捷键与内置入口）
  final bool enableAssistant;

  /// 是否在输入框右下角挂内置入口；宿主把助手放进自己的控件栏时关闭
  final bool showAssistantEntry;
  final bool showTagModeSwitch;
  final Object? assistantTapRegionGroupId;

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
    this.surfaceColor,
    this.onChanged,
    this.onSubmitted,
    this.maxLines,
    this.minLines,
    this.expands = false,
    this.fitContent = false,
    this.sessionId,
    this.enableAssistant = true,
    this.showAssistantEntry = true,
    this.showTagModeSwitch = true,
    this.assistantTapRegionGroupId,
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
  String _hostKnownText = '';
  Object get _modeId => widget.sessionId ?? _effectiveController;
  bool get _tagMode =>
      widget.config.enableTagMode && ref.read(promptTagModeProvider(_modeId));

  /// 焦点节点
  FocusNode? _internalFocusNode;
  final FocusNode _tagFocusNode = FocusNode();
  // Opening search reparents the input under a Column. Keep its editing session
  // and viewport instead of recreating the text/tag mode container.
  final GlobalKey _inputStackKey = GlobalKey();

  StreamSubscription<StreamingChunk>? _assistantStreamSub;
  late String _sessionId;
  late final PromptSearchSession _searchSession;

  /// 替换功能是否可用（只读模式下禁用）
  bool get _canReplace => !widget.config.readOnly;

  /// 复制/剪切时展开词库别名的 Action 映射
  ///
  /// 常量化持有，避免每帧新建 Map 触发 [Actions] 的无谓通知。
  /// 开关状态在 Action 内部按需读取，因此这里始终挂载，
  /// 切换开关不会改变 widget 树结构（不会导致输入框重建丢焦点）。
  late final Map<Type, Action<Intent>> _clipboardActions = {
    CopySelectionTextIntent: AliasExpandingCopyAction(
      _handleExpandedClipboardAction,
    ),
  };

  bool _handleHardwareKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return false;
    }

    final promptFocused = _effectiveFocusNode.hasFocus;
    final searchFocused = _searchSession.searchFocusNode.hasFocus;
    final replaceFocused = _searchSession.replaceFocusNode.hasFocus;
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
      _searchSession.open();
      return true;
    }

    if ((isCtrl || isMeta) &&
        !isShift &&
        _canReplace &&
        logicalKey == LogicalKeyboardKey.keyH) {
      _searchSession.open(showReplace: true);
      return true;
    }

    if (_searchSession.visible && (searchFocused || replaceFocused)) {
      if (_searchSession.handleSearchBarKey(
        logicalKey,
        isCtrl: isCtrl,
        isShift: isShift,
        isMeta: isMeta,
        replaceFocused: replaceFocused,
      )) {
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
  TextEditingController get _textFieldController => widget.config.enableTagMode
      ? _syntaxController!.displayController
      : _effectiveController;

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
      separateNumericWeightClosing: widget.config.separateNumericWeightClosing,
    );
    if (widget.controller != null) {
      _syntaxController!.value = widget.controller!.value;
    }
    _hostKnownText = _syntaxController!.text;
    _syntaxController!.addListener(_onSyntaxValueChanged);

    // 初始化焦点节点（如果需要）
    if (widget.focusNode == null) {
      _internalFocusNode = FocusNode();
    }

    _searchSession = PromptSearchSession(
      getEffectiveController: () => _effectiveController,
      getExternalController: () => widget.controller,
      getCanReplace: () => _canReplace,
      getIsMounted: () => mounted,
      getRestoreFocusNode: () => _tagMode ? _tagFocusNode : _effectiveFocusNode,
      onStateChanged: () {
        if (mounted) {
          setState(() {});
        }
      },
      onRecordReplaceAllHistory: (before, after) {
        ref
            .read(promptAssistantHistoryProvider.notifier)
            .recordExternalChange(_sessionId, before: before, after: after);
      },
      onReplaceAllDone: (replacedCount) {
        if (mounted) {
          AppToast.info(
            context,
            context.l10n.prompt_replaceAllDone(replacedCount),
          );
        }
      },
    )..init();

    // 监听外部控制器变化
    widget.controller?.addListener(_syncFromExternalController);

    // 监听焦点变化（用于失焦格式化）
    _effectiveFocusNode.addListener(_onFocusChanged);

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
    _syntaxController?.separateNumericWeightClosing =
        widget.config.separateNumericWeightClosing;
  }

  @override
  void dispose() {
    _assistantStreamSub?.cancel();
    _searchSession.detachBeforeSyntaxDispose();
    HardwareKeyboard.instance.removeHandler(_handleHardwareKeyEvent);
    _effectiveFocusNode.removeListener(_onFocusChanged);
    widget.controller?.removeListener(_syncFromExternalController);
    _syntaxController?.removeListener(_onSyntaxValueChanged);
    _syntaxController?.dispose();
    _internalFocusNode?.dispose();
    _tagFocusNode.dispose();
    _searchSession.disposeControllers();
    super.dispose();
  }

  Future<void> _runAssistantAction(AssistantTaskType taskType) async {
    _assistantStreamSub = await runUnifiedPromptAssistantAction(
      context: context,
      ref: ref,
      isMounted: () => mounted,
      effectiveController: _effectiveController,
      sessionId: _sessionId,
      tagMode: _tagMode,
      taskType: taskType,
      previousSubscription: _assistantStreamSub,
    );
  }

  /// 焦点变化回调
  void _onFocusChanged() {
    if (!_effectiveFocusNode.hasFocus) {
      if (_tagMode) return;
      formatUnifiedPromptOnBlur(
        context: context,
        ref: ref,
        isMounted: () => mounted,
        config: widget.config,
        effectiveController: _effectiveController,
      );
      ref
          .read(promptAssistantHistoryProvider.notifier)
          .push(_sessionId, _effectiveController.text);
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

    // 输入法组合输入（composing）期间被外部改写会摧毁组合区，并与系统输入法
    // 争夺编辑状态，表现为输入框卡死（iOS 中文输入法上可稳定复现）。组合期间
    // 跳过同步，组合结束后由后续输入自然同步回来。
    final composing = syntaxController.value.composing;
    if (composing.isValid &&
        !composing.isCollapsed &&
        externalValue.text != syntaxController.text) {
      return;
    }

    if (syntaxController.value != externalValue) {
      _syncingControllerValue = true;
      try {
        syntaxController.value = externalValue;
      } finally {
        _syncingControllerValue = false;
      }
    }

    if (_searchSession.visible &&
        externalValue.text != _searchSession.lastSourceText) {
      _searchSession.refreshMatches(
        preserveActive: true,
        selectActiveMatch: false,
      );
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

    if (_searchSession.visible &&
        syntaxController.text != _searchSession.lastSourceText) {
      _searchSession.refreshMatches(
        preserveActive: true,
        selectActiveMatch: false,
      );
    }
  }

  // 权重工具栏、替换等程序化改写不经过 TextField.onChanged，统一在此回调宿主
  void _onSyntaxValueChanged() {
    if (_syncingControllerValue) {
      _hostKnownText = _syntaxController!.text;
      return;
    }
    _syncToExternalController();
    _notifyTextChanged();
  }

  void _notifyTextChanged() {
    final text = _effectiveController.text;
    if (text == _hostKnownText) return;
    _hostKnownText = text;
    widget.onChanged?.call(text);
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

    widget.config.onClearPressed?.call();
  }

  bool _handleExpandedClipboardAction({required bool isCut}) {
    return handleExpandedPromptClipboardAction(
      ref: ref,
      syntaxController: _syntaxController!,
      externalController: widget.controller,
      enableTagMode: widget.config.enableTagMode,
      readOnly: widget.config.readOnly,
      isCut: isCut,
    );
  }

  Widget _buildContextMenu(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    return buildPromptInputContextMenu(
      context,
      editableTextState,
      ref: ref,
      effectiveController: _effectiveController,
      handleExpandedClipboardAction: _handleExpandedClipboardAction,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.config.enableTagMode) ref.watch(promptTagModeProvider(_modeId));
    final enableWheelAdjustment = ref.watch(promptWeightScrollSettingsProvider);

    final textField = buildUnifiedPromptTextField(
      context: context,
      config: widget.config,
      decoration: widget.decoration,
      surfaceColor: widget.surfaceColor,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      expands: widget.expands,
      fitContent: widget.fitContent,
      enableWheelAdjustment: enableWheelAdjustment,
      tagMode: _tagMode,
      modeId: _modeId,
      textFieldController: _textFieldController,
      effectiveController: _effectiveController,
      effectiveControllerProvider: _effectiveControllerProvider,
      effectiveFocusNode: _effectiveFocusNode,
      tagFocusNode: _tagFocusNode,
      clipboardActions: _clipboardActions,
      onSubmitted: widget.onSubmitted,
      onClear: _handleClear,
      contextMenuBuilder: _buildContextMenu,
      onOpenSearch: (replace) => _searchSession.open(showReplace: replace),
    );

    return buildUnifiedPromptEditorContainer(
      context: context,
      inputStackKey: _inputStackKey,
      textField: textField,
      config: widget.config,
      fitContent: widget.fitContent,
      expands: widget.expands,
      showAssistantEntry: widget.enableAssistant && widget.showAssistantEntry,
      showTagModeSwitch: widget.showTagModeSwitch,
      modeId: _modeId,
      sessionId: _sessionId,
      assistantTapRegionGroupId: widget.assistantTapRegionGroupId,
      effectiveController: _effectiveController,
      onOpenAssistantSettings: widget.onOpenAssistantSettings,
      onComfyuiImport: widget.onComfyuiImport,
      searchVisible: _searchSession.visible,
      buildSearchToolbar: () => PromptSearchToolbar(
        canReplace: _canReplace,
        replaceVisible: _searchSession.replaceVisible,
        searchController: _searchSession.searchController,
        searchFocusNode: _searchSession.searchFocusNode,
        replaceController: _searchSession.replaceController,
        replaceFocusNode: _searchSession.replaceFocusNode,
        matchCount: _searchSession.matches.length,
        activeMatchIndex: _searchSession.activeMatchIndex,
        canRunReplace: _searchSession.canRunReplace,
        onToggleReplaceVisible: _searchSession.toggleReplaceVisible,
        onPreviousMatch: () => _searchSession.goToMatch(previous: true),
        onNextMatch: () => _searchSession.goToMatch(previous: false),
        onClose: _searchSession.close,
        onReplaceActive: _searchSession.replaceActiveMatch,
        onReplaceAll: _searchSession.replaceAllMatches,
      ),
    );
  }
}
