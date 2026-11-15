import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../nai_syntax_controller.dart';
import 'prompt_search_utils.dart';

/// 管理统一提示词输入框的查找与替换会话状态、焦点与高亮同步。
class PromptSearchSession {
  PromptSearchSession({
    required this.getEffectiveController,
    required this.getExternalController,
    required this.getCanReplace,
    required this.getIsMounted,
    required this.getRestoreFocusNode,
    required this.onStateChanged,
    required this.onRecordReplaceAllHistory,
    required this.onReplaceAllDone,
  });

  final TextEditingController Function() getEffectiveController;
  final TextEditingController? Function() getExternalController;
  final bool Function() getCanReplace;
  final bool Function() getIsMounted;
  final FocusNode Function() getRestoreFocusNode;
  final VoidCallback onStateChanged;
  final void Function(String before, String after) onRecordReplaceAllHistory;
  final void Function(int count) onReplaceAllDone;

  late final TextEditingController searchController;
  late final FocusNode searchFocusNode;
  late final TextEditingController replaceController;
  late final FocusNode replaceFocusNode;

  bool visible = false;
  bool replaceVisible = false;
  List<TextRange> matches = const [];
  int activeMatchIndex = -1;
  String lastSourceText = '';

  bool get searchQueryIsValid => searchController.text.trim().isNotEmpty;
  bool get canRunReplace =>
      getCanReplace() && matches.isNotEmpty && searchQueryIsValid;

  void init() {
    searchController = TextEditingController();
    searchFocusNode = FocusNode();
    searchController.addListener(_onSearchQueryChanged);
    replaceController = TextEditingController();
    replaceFocusNode = FocusNode();
  }

  void detachBeforeSyntaxDispose() {
    searchController.removeListener(_onSearchQueryChanged);
    clearHighlights();
  }

  void disposeControllers() {
    searchController.dispose();
    searchFocusNode.dispose();
    replaceController.dispose();
    replaceFocusNode.dispose();
  }

  void open({bool showReplace = false}) {
    final canReplace = getCanReplace();
    final shouldShowReplace = showReplace && canReplace;
    final selectedText = _selectedPromptText();
    final shouldUseSelection = !visible && selectedText.isNotEmpty;
    // 搜索栏已展开且已有查询词时，Ctrl+H 直接把焦点交给替换框，
    // 避免用户还要再点一次输入框。
    final focusReplaceField =
        shouldShowReplace &&
        visible &&
        !shouldUseSelection &&
        searchController.text.trim().isNotEmpty;

    if (!visible || (shouldShowReplace && !replaceVisible)) {
      visible = true;
      if (shouldShowReplace) {
        replaceVisible = true;
      }
      onStateChanged();
    }

    if (shouldUseSelection) {
      searchController.text = selectedText;
    } else {
      refreshMatches(preserveActive: false);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!getIsMounted()) return;
      if (focusReplaceField) {
        replaceFocusNode.requestFocus();
        replaceController.selection = TextSelection(
          baseOffset: 0,
          extentOffset: replaceController.text.length,
        );
        return;
      }
      searchFocusNode.requestFocus();
      searchController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: searchController.text.length,
      );
    });
  }

  void close() {
    if (!visible) {
      return;
    }
    visible = false;
    matches = const [];
    activeMatchIndex = -1;
    onStateChanged();
    clearHighlights();
    getRestoreFocusNode().requestFocus();
  }

  void toggleReplaceVisible() {
    if (!getCanReplace()) {
      return;
    }
    final nextVisible = !replaceVisible;
    replaceVisible = nextVisible;
    onStateChanged();
    if (!nextVisible) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!getIsMounted()) return;
      replaceFocusNode.requestFocus();
    });
  }

  bool handleSearchBarKey(
    LogicalKeyboardKey logicalKey, {
    required bool isCtrl,
    required bool isShift,
    required bool isMeta,
    required bool replaceFocused,
  }) {
    if (logicalKey == LogicalKeyboardKey.escape) {
      close();
      return true;
    }
    if (logicalKey == LogicalKeyboardKey.enter) {
      // 搜索框回车跳转命中，替换框回车替换当前命中；
      // 替换框上叠加 Ctrl/Cmd 则执行全部替换（对齐常见编辑器）。
      if (replaceFocused) {
        if (isCtrl || isMeta) {
          replaceAllMatches();
        } else {
          replaceActiveMatch();
        }
      } else {
        goToMatch(previous: isShift);
      }
      return true;
    }
    return false;
  }

  String _selectedPromptText() {
    final controller = getEffectiveController();
    final selection = controller.selection;
    final text = controller.text;
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
    if (!visible) {
      return;
    }
    refreshMatches(preserveActive: false);
  }

  void refreshMatches({
    required bool preserveActive,
    bool selectActiveMatch = true,
  }) {
    final controller = getEffectiveController();
    final sourceText = controller.text;
    final nextMatches = findPromptSearchMatches(
      sourceText,
      searchController.text,
    );
    final activeIndex = resolveActivePromptSearchIndex(
      nextMatches,
      currentActiveIndex: activeMatchIndex,
      selection: controller.selection,
      preserveActive: preserveActive,
    );

    matches = nextMatches;
    activeMatchIndex = activeIndex;
    lastSourceText = sourceText;
    onStateChanged();

    syncHighlights();
    if (selectActiveMatch) {
      _selectActiveSearchMatch();
    }
  }

  void goToMatch({required bool previous}) {
    if (matches.isEmpty) {
      return;
    }
    final nextIndex = previous
        ? (activeMatchIndex - 1 + matches.length) % matches.length
        : (activeMatchIndex + 1) % matches.length;

    activeMatchIndex = nextIndex;
    onStateChanged();
    syncHighlights();
    _selectActiveSearchMatch();
  }

  void _selectActiveSearchMatch() {
    if (activeMatchIndex < 0 || activeMatchIndex >= matches.length) {
      return;
    }
    final match = matches[activeMatchIndex];
    getEffectiveController().selection = TextSelection(
      baseOffset: match.start,
      extentOffset: match.end,
    );
  }

  /// 替换当前命中，并把光标折叠到替换文本末尾。
  ///
  /// 光标位置决定了 [resolveActivePromptSearchIndex] 选中的下一个命中，
  /// 因此替换后会自然跳到后一处，替换文本本身包含查询词时也不会自我循环。
  void replaceActiveMatch() {
    if (!canRunReplace) {
      return;
    }
    if (activeMatchIndex < 0 || activeMatchIndex >= matches.length) {
      return;
    }

    final source = getEffectiveController().text;
    final match = matches[activeMatchIndex];
    if (match.start < 0 || match.end > source.length) {
      return;
    }

    final replacement = replaceController.text;
    final newText = source.replaceRange(match.start, match.end, replacement);
    _applyReplacedText(
      newText,
      caretOffset: match.start + replacement.length,
      selectNextMatch: true,
    );
  }

  void replaceAllMatches() {
    if (!canRunReplace) {
      return;
    }

    final source = getEffectiveController().text;
    final result = buildReplaceAllPromptText(
      source: source,
      matches: matches,
      replacement: replaceController.text,
    );
    if (result.replacedCount == 0) {
      return;
    }

    _applyReplacedText(
      result.text,
      caretOffset: result.caretOffset,
      selectNextMatch: false,
      // 全部替换是一次性的批量改写，纳入外部历史栈后可用助手浮层撤销。
      recordHistory: true,
    );

    onReplaceAllDone(result.replacedCount);
  }

  /// 写回替换结果，并保持内部/外部控制器与搜索高亮一致。
  void _applyReplacedText(
    String newText, {
    required int caretOffset,
    required bool selectNextMatch,
    bool recordHistory = false,
  }) {
    final effectiveController = getEffectiveController();
    final beforeText = effectiveController.text;
    if (newText == beforeText) {
      return;
    }

    final value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: caretOffset.clamp(0, newText.length),
      ),
    );
    effectiveController.value = value;
    final externalController = getExternalController();
    // 与 _handleClear 一致：外部控制器不是同一实例时显式同步。
    if (externalController != null &&
        !identical(externalController, effectiveController)) {
      externalController.value = value;
    }

    if (recordHistory) {
      onRecordReplaceAllHistory(beforeText, newText);
    }

    refreshMatches(preserveActive: false, selectActiveMatch: selectNextMatch);
  }

  void syncHighlights() {
    final controller = getEffectiveController();
    if (controller is NaiSyntaxController) {
      controller.updateSearchHighlights(
        matches: matches,
        activeMatchIndex: activeMatchIndex,
      );
    }
  }

  void clearHighlights() {
    final controller = getEffectiveController();
    if (controller is NaiSyntaxController) {
      controller.clearSearchHighlights();
    }
  }
}
