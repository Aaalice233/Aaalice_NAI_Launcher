import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nai_launcher/presentation/widgets/common/themed_input.dart';

import '../../../../data/models/character/character_prompt.dart';
import '../../../../presentation/utils/text_selection_utils.dart';
import '../../../adaptive/interaction_policy.dart';
import '../../../prompt_assistant/widgets/prompt_assistant_overlay.dart';
import '../../autocomplete/autocomplete_wrapper.dart';
import '../../common/weight_adjust_toolbar.dart';
import '../comfyui_import_wrapper.dart';
import '../prompt_tag_mode_toggle.dart';
import '../prompt_weight_editing.dart';
import '../tag_mode_prompt_field.dart';
import 'prompt_scroll_coordinator.dart';
import 'unified_prompt_config.dart';

/// 构建统一提示词输入区内部文本字段与功能包装层。
Widget buildUnifiedPromptTextField({
  required BuildContext context,
  required UnifiedPromptConfig config,
  required InputDecoration? decoration,
  required Color? surfaceColor,
  required int? maxLines,
  required int? minLines,
  required bool expands,
  required bool fitContent,
  required bool enableWheelAdjustment,
  required bool tagMode,
  required Object modeId,
  required TextEditingController textFieldController,
  required TextEditingController effectiveController,
  required ValueGetter<TextEditingController> effectiveControllerProvider,
  required FocusNode effectiveFocusNode,
  required FocusNode tagFocusNode,
  required Map<Type, Action<Intent>> clipboardActions,
  required ValueChanged<String>? onSubmitted,
  required VoidCallback onClear,
  required EditableTextContextMenuBuilder contextMenuBuilder,
  required ValueChanged<bool> onOpenSearch,
}) {
  final requestedContentPadding =
      decoration?.contentPadding ??
      const EdgeInsets.symmetric(horizontal: 12, vertical: 10);

  // 合并 decoration：优先使用传入的 decoration，但保留 config 中的 hintText
  final effectiveDecoration =
      InputDecoration(
        hintText: config.hintText,
        contentPadding: requestedContentPadding,
      ).copyWith(
        hintText: config.hintText,
        prefixIcon: decoration?.prefixIcon,
        suffixIcon: decoration?.suffixIcon,
        prefix: decoration?.prefix,
        suffix: decoration?.suffix,
        labelText: decoration?.labelText,
        labelStyle: decoration?.labelStyle,
        floatingLabelStyle: decoration?.floatingLabelStyle,
        helperText: decoration?.helperText,
        helperStyle: decoration?.helperStyle,
        errorText: decoration?.errorText,
        errorStyle: decoration?.errorStyle,
        counterText: decoration?.counterText,
        counterStyle: decoration?.counterStyle,
        isDense: decoration?.isDense,
      );

  // 构建基础 ThemedInput
  // 注意：focusNode 必须始终传给 ThemedInput，
  // 否则 TextField 会创建自己的内部 focusNode，
  // 导致 _onFocusChanged 监听不到失焦事件
  final baseInput = ThemedInput(
    controller: textFieldController,
    focusNode: effectiveFocusNode,
    decoration: effectiveDecoration,
    surfaceColor: surfaceColor,
    maxLines: expands ? null : maxLines,
    minLines: expands ? null : (minLines ?? 1),
    expands: expands,
    scrollPhysics:
        enableWheelAdjustment &&
            context.interactionPolicy.precisePointerAvailable
        ? WeightAdjustScrollPhysics(
            controllerProvider: effectiveControllerProvider,
          )
        : null,
    textAlignVertical: expands ? TextAlignVertical.top : null,
    readOnly: config.readOnly,
    inputFormatters: config.readOnly
        ? null
        : [
            TextInputFormatter.withFunction((oldValue, newValue) {
              return TextSelectionUtils.wrapSelectionOnBracketReplacement(
                oldValue,
                newValue,
              );
            }),
          ],
    onSubmitted: (_) => onSubmitted?.call(effectiveController.text),
    showClearButton: config.showClearButton,
    onClearPressed: config.showClearButton ? onClear : null,
    clearNeedsConfirm: config.clearNeedsConfirm,
    contextMenuBuilder: contextMenuBuilder,
  );

  // 接管 Ctrl+C / Ctrl+X：覆盖 EditableText 内置的 CopySelectionTextIntent
  Widget clipboardAwareInput = Actions(
    actions: clipboardActions,
    child: baseInput,
  );

  if (config.enableTagMode) {
    clipboardAwareInput = TagModePromptField(
      sessionId: modeId,
      fitContent: fitContent && !expands,
      bottomPadding: config.showClearButton ? 58 : 12,
      showModeSwitch: false,
      controller: effectiveController,
      sourceFocusNode: effectiveFocusNode,
      tagFocusNode: tagFocusNode,
      onClear: config.showClearButton ? onClear : null,
      clearNeedsConfirm: config.clearNeedsConfirm,
      surfaceColor: surfaceColor,
      enabled: !config.readOnly,
      enableAutocomplete: config.enableAutocomplete,
      enableWheelAdjustment: enableWheelAdjustment,
      onSearch: onOpenSearch,
      child: clipboardAwareInput,
    );
  }

  // 包装权重调整工具条
  Widget result = config.enableTagMode
      ? clipboardAwareInput
      : WeightAdjustToolbarWrapper(
          controller: effectiveController,
          focusNode: effectiveFocusNode,
          enableWheelAdjustment: enableWheelAdjustment,
          enabled: !tagMode && !config.readOnly,
          child: clipboardAwareInput,
        );

  // 如果启用自动补全，使用 AutocompleteWrapper 包装
  if (config.enableAutocomplete) {
    result = AutocompleteWrapper(
      controller: textFieldController,
      focusNode: effectiveFocusNode,
      config: config.autocompleteConfig,
      enabled: !config.readOnly && !tagMode,
      contentPadding: effectiveDecoration.contentPadding,
      maxLines: maxLines,
      expands: expands,
      child: result,
    );
  }

  return PromptScrollCoordinator(
    tagMode: tagMode,
    textWheelAdjustmentActive: () =>
        !config.readOnly &&
        enableWheelAdjustment &&
        promptWeightWheelActive(effectiveController) &&
        PromptWeightEditing.protectNegativeBlockSyntax(effectiveController),
    focused: () => effectiveFocusNode.hasFocus || tagFocusNode.hasFocus,
    child: result,
  );
}

/// 组装输入栈、助手浮层、标签模式切换与搜索工具栏的外层布局。
Widget buildUnifiedPromptEditorContainer({
  required BuildContext context,
  required Key inputStackKey,
  required Widget textField,
  required UnifiedPromptConfig config,
  required bool fitContent,
  required bool expands,
  required bool showAssistantEntry,
  required bool showTagModeSwitch,
  required Object modeId,
  required String sessionId,
  required Object? assistantTapRegionGroupId,
  required TextEditingController effectiveController,
  required VoidCallback? onOpenAssistantSettings,
  required void Function(String globalPrompt, List<CharacterPrompt> characters)?
  onComfyuiImport,
  required bool searchVisible,
  required Widget Function() buildSearchToolbar,
}) {
  var result = textField;

  // 开关只切 enabled、不增删包装层：树形变化会重建 TextField 并丢失撤销历史
  if (onComfyuiImport != null) {
    result = ComfyuiImportWrapper(
      controller: effectiveController,
      enabled: config.enableComfyuiImport && !config.readOnly,
      onImport: onComfyuiImport,
      child: result,
    );
  }

  final inputStack = Stack(
    key: inputStackKey,
    fit: fitContent ? StackFit.loose : StackFit.expand,
    children: [
      result,
      if (showAssistantEntry)
        Positioned.fill(
          child: PromptAssistantOverlay(
            placement: PromptAssistantPlacement.viewport,
            supportsTagMode: config.enableTagMode,
            tagModeSessionId: modeId,
            tapRegionGroupId: assistantTapRegionGroupId,
            iconOnly: true,
            sessionId: sessionId,
            controller: effectiveController,
            interactionPolicy: context.interactionPolicy,
            onOpenSettings: onOpenAssistantSettings,
          ),
        ),
    ],
  );

  final editor = config.enableTagMode && showTagModeSwitch
      ? Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              fit: expands ? FlexFit.tight : FlexFit.loose,
              child: inputStack,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: PromptTagModeToggle(
                sessionId: modeId,
                enabled: !config.readOnly,
              ),
            ),
          ],
        )
      : inputStack;

  if (!searchVisible) {
    return editor;
  }

  if (expands) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildSearchToolbar(),
        const SizedBox(height: 8),
        Expanded(child: editor),
      ],
    );
  }

  return Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [buildSearchToolbar(), const SizedBox(height: 8), editor],
  );
}
