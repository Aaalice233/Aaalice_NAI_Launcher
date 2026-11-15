import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';

import '../../../../core/utils/prompt_edit_document.dart';
import '../../../../presentation/utils/text_selection_utils.dart';
import '../../../../presentation/widgets/common/themed_text_selection_toolbar.dart';
import '../../../providers/alias_resolver_service.dart';
import '../../../providers/generation/generation_settings_notifiers.dart';
import '../../../providers/tag_library_page_provider.dart';
import '../../../screens/tag_library_page/widgets/entry_add_dialog.dart';
import '../nai_syntax_controller.dart';
import '../prompt_text_selection_actions.dart';

/// 接管复制/剪切，把选区里的 `<词库名>` 展开后写入剪贴板。
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
bool handleExpandedPromptClipboardAction({
  required WidgetRef ref,
  required NaiSyntaxController syntaxController,
  required TextEditingController? externalController,
  required bool enableTagMode,
  required bool readOnly,
  required bool isCut,
}) {
  final selection = syntaxController.selection;
  if (!selection.isValid || selection.isCollapsed) return false;

  final text = syntaxController.text;
  final selectedText = selection.textInside(text);
  if (selectedText.isEmpty) return false;

  final display = enableTagMode ? syntaxController.displayController : null;
  final expanded = ref.read(resolveAliasOnCopySettingsProvider)
      ? PromptEditDocument.mapActiveText(
          selectedText,
          ref.read(aliasResolverServiceProvider.notifier).resolveAliases,
        )
      : selectedText;
  if (expanded == selectedText && !(display?.hasProjectedSelection ?? false)) {
    return false;
  }

  unawaited(Clipboard.setData(ClipboardData(text: expanded)));

  // 剪切需要自行删除选中文本：默认实现会连带再写一次剪贴板，不能复用
  if (isCut && !readOnly) {
    if (display != null) {
      display.deleteSelection();
      return true;
    }
    final newValue = TextEditingValue(
      text: selection.textBefore(text) + selection.textAfter(text),
      selection: TextSelection.collapsed(offset: selection.start),
    );
    syntaxController.value = newValue;
    // 同步到外部控制器（与 _handleClear 保持一致）
    if (externalController != null &&
        !identical(externalController, syntaxController)) {
      externalController.value = newValue;
    }
  }

  return true;
}

/// 构建统一提示词输入框的自定义上下文菜单（展开复制/剪切 + 保存到词库）。
Widget buildPromptInputContextMenu(
  BuildContext context,
  EditableTextState editableTextState, {
  required WidgetRef ref,
  required TextEditingController effectiveController,
  required bool Function({required bool isCut}) handleExpandedClipboardAction,
}) {
  final selectedText = TextSelectionUtils.getSelectedText(effectiveController);
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
        if (handleExpandedClipboardAction(isCut: isCut)) {
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
          unawaited(_showSaveToLibraryDialog(context, ref, selectedText));
        },
        label: context.l10n.tagLibrary_saveToLibrary,
      ),
    );
  }

  final enabledAction = promptTextSelectionEnabledAction(
    context,
    editableTextState,
  );
  if (enabledAction != null) buttonItems.insert(0, enabledAction);

  return buildThemedTextSelectionToolbar(
    context,
    anchors: editableTextState.contextMenuAnchors,
    buttonItems: buttonItems,
  );
}

Future<void> _showSaveToLibraryDialog(
  BuildContext context,
  WidgetRef ref,
  String selectedText,
) async {
  final categories = ref.read(tagLibraryPageCategoriesProvider);

  await EntryAddDialog.show(
    context,
    categories: categories,
    initialContent: selectedText,
  );

  // 注意：EntryAddDialog 会自己处理保存逻辑并显示 toast
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
class AliasExpandingCopyAction extends Action<CopySelectionTextIntent> {
  AliasExpandingCopyAction(this.handleExpanded);

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
