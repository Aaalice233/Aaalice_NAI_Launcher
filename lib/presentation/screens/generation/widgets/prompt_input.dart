import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/utils/localization_extension.dart';
import '../../../adaptive/interaction_policy.dart';
import '../../../prompt_assistant/providers/prompt_assistant_config_provider.dart';
import '../../../prompt_assistant/providers/prompt_assistant_history_provider.dart';
import '../../../prompt_assistant/providers/prompt_assistant_state_provider.dart';
import '../../../prompt_assistant/widgets/prompt_assistant_overlay.dart';
import '../../../providers/image_generation_provider.dart';
import '../../../providers/pending_prompt_provider.dart';
import '../../../providers/prompt_maximize_provider.dart';
import '../../../providers/prompt_token_counter_provider.dart';
import '../../../providers/queue_execution_provider.dart';
import 'prompt_input_controller.dart';
import 'prompt_input_coordinator.dart';
import 'prompt_input_editor.dart';
import 'prompt_input_footer.dart';
import 'prompt_input_models.dart';
import 'prompt_input_toolbar.dart';
import 'prompt_type_switch.dart';

bool _isPromptAssistantVisible(BuildContext context, WidgetRef ref) {
  final config = ref.watch(promptAssistantConfigProvider);
  return config.enabled &&
      (!context.interactionPolicy.usesAnchoredMenus ||
          config.desktopOverlayEnabled);
}

class PromptInputWidget extends ConsumerStatefulWidget {
  const PromptInputWidget({
    super.key,
    this.compact = false,
    this.onToggleMaximize,
    this.isMaximized = false,
    this.showMaximizeButton = true,
    this.autofocus = false,
    this.negativeModeNotifier,
    this.controller,
    this.autoGrow = false,
    this.active = true,
  });

  final bool compact;
  final VoidCallback? onToggleMaximize;
  final bool isMaximized;
  final bool showMaximizeButton;
  final bool autofocus;
  final ValueNotifier<bool>? negativeModeNotifier;
  final PromptInputController? controller;
  final bool autoGrow;
  final bool active;

  @override
  ConsumerState<PromptInputWidget> createState() => _PromptInputWidgetState();
}

class _PromptInputWidgetState extends ConsumerState<PromptInputWidget> {
  late final PromptInputController _controller;
  late final bool _ownsController;
  late final PromptInputCoordinator _coordinator;
  final _editorKey = GlobalKey(debugLabel: 'generation-prompt-editor');

  @override
  void initState() {
    super.initState();
    final params = ref.read(generationParamsNotifierProvider);
    _ownsController = widget.controller == null;
    _controller =
        widget.controller ??
        PromptInputController(
          prompt: params.prompt,
          negativePrompt: params.negativePrompt,
          negativeModeNotifier: widget.negativeModeNotifier,
        );
    _controller.addListener(_onControllerChanged);
    _coordinator = PromptInputCoordinator(
      ref: ref,
      controller: _controller,
      context: () => context,
      mounted: () => mounted,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _coordinator.consumePendingPrompt();
      if (widget.autofocus) _controller.promptFocusNode.requestFocus();
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant PromptInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(
      identical(oldWidget.controller, widget.controller),
      'PromptInputWidget.controller cannot change during the widget lifetime.',
    );
    if (_ownsController &&
        !identical(
          oldWidget.negativeModeNotifier,
          widget.negativeModeNotifier,
        )) {
      _controller.bindNegativeModeNotifier(widget.negativeModeNotifier);
    }
    if (oldWidget.active && !widget.active) {
      _controller.promptFocusNode.unfocus();
      _controller.negativeFocusNode.unfocus();
    }
    if (widget.active &&
        widget.autofocus &&
        (!oldWidget.active || !oldWidget.autofocus)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !widget.active) return;
        final focusNode = _controller.isNegativeMode
            ? _controller.negativeFocusNode
            : _controller.promptFocusNode;
        focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(
      generationParamsNotifierProvider.select(
        (params) =>
            (prompt: params.prompt, negativePrompt: params.negativePrompt),
      ),
      (previous, next) {
        var queueActive = false;
        try {
          final queue = ref.read(queueExecutionNotifierProvider);
          queueActive = queue.isRunning || queue.isReady;
        } catch (_) {
          // Some focused widget tests intentionally omit queue dependencies.
        }
        if (queueActive) return;
        if (previous?.prompt != next.prompt) {
          _controller.syncPrompt(next.prompt);
        }
        if (previous?.negativePrompt != next.negativePrompt) {
          _controller.syncNegativePrompt(next.negativePrompt);
        }
      },
    );
    ref.listen(hasPendingPromptProvider, (previous, next) {
      if (!next) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _coordinator.consumePendingPrompt();
        setState(() {});
      });
    });

    final highlight = ref.watch(highlightEmphasisSettingsProvider);
    final numericEmphasis = ImageModels.isV4Model(
      ref.watch(
        generationParamsNotifierProvider.select((params) => params.model),
      ),
    );
    _controller.configureHighlighting(
      enabled: highlight,
      numericEmphasisEnabled: numericEmphasis,
    );
    final viewData = PromptInputViewData(
      autoGrow: widget.autoGrow,
      isMaximized: widget.isMaximized,
      showMaximizeButton: widget.showMaximizeButton,
      numericEmphasisEnabled: numericEmphasis,
    );
    final commands = PromptInputCommands(
      setNegativeMode: _controller.setNegativeMode,
      updatePrompt: _coordinator.updatePrompt,
      updateNegativePrompt: _coordinator.updateNegativePrompt,
      importComfyuiPrompt: _coordinator.importComfyuiPrompt,
      clearPrompt: _coordinator.clearPrompt,
      clearNegativePrompt: _coordinator.clearNegativePrompt,
      generateRandomPrompt: _coordinator.generateRandomPrompt,
      showRandomModeSelector: _coordinator.showRandomModeSelector,
      openAssistantSettings: _coordinator.openAssistantSettings,
      showMobileCharacterManager: _coordinator.showMobileCharacterManager,
      toggleMaximize:
          widget.onToggleMaximize ??
          () => ref.read(promptMaximizeNotifierProvider.notifier).toggle(),
    );

    if (widget.compact) {
      return _CompactPromptInput(
        editorKey: _editorKey,
        controller: _controller,
        commands: commands,
        viewData: viewData,
      );
    }
    return _FullPromptInput(
      editorKey: _editorKey,
      controller: _controller,
      commands: commands,
      viewData: viewData,
    );
  }
}

class _FullPromptInput extends ConsumerWidget {
  const _FullPromptInput({
    required this.editorKey,
    required this.controller,
    required this.commands,
    required this.viewData,
  });

  final GlobalKey editorKey;
  final PromptInputController controller;
  final PromptInputCommands commands;
  final PromptInputViewData viewData;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final negative = controller.isNegativeMode;
    final assistantSessionId = negative
        ? PromptHistorySessionIds.generationNegative
        : PromptHistorySessionIds.generationPrompt;
    final assistantVisible = _isPromptAssistantVisible(context, ref);
    final assistantExpanded =
        assistantVisible &&
        ref.watch(
          promptAssistantStateProvider.select(
            (states) => states[assistantSessionId]?.expanded ?? false,
          ),
        );
    final editor = PromptInputEditor(
      key: editorKey,
      controller: controller,
      commands: commands,
      viewData: viewData,
    );
    PromptInputFooter buildFooter({bool includeBottomActions = false}) =>
        PromptInputFooter(
          target: negative
              ? PromptTokenCountTarget.negative
              : PromptTokenCountTarget.positive,
          topPadding: 6,
          assistant: assistantVisible
              ? PromptAssistantOverlay(
                  sessionId: assistantSessionId,
                  controller: negative
                      ? controller.negativeController
                      : controller.promptController,
                  interactionPolicy: context.interactionPolicy,
                  onChanged: negative
                      ? commands.updateNegativePrompt
                      : commands.updatePrompt,
                  onOpenSettings: commands.openAssistantSettings,
                  floatOverEditor: false,
                )
              : null,
          assistantExpanded: assistantExpanded,
          assistantToolbarHeight: assistantVisible
              ? PromptAssistantOverlay.effectiveInlineToolbarHeight(
                  context.interactionPolicy,
                )
              : 0,
          assistantExpandedWidth: assistantVisible
              ? PromptAssistantOverlay.expandedInlineToolbarWidth(
                  context.interactionPolicy,
                )
              : 0,
          leading: includeBottomActions
              ? PromptInputBottomActions(
                  controller: controller,
                  commands: commands,
                )
              : null,
        );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (viewData.isMaximized && constraints.maxWidth < 600) {
          return PromptInputToolbar(
            controller: controller,
            commands: commands,
            viewData: viewData,
            mobileFullscreen: true,
            mobileEditor: editor,
            mobileFooter: buildFooter(),
          );
        }
        return Column(
          mainAxisSize: viewData.autoGrow ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: constraints.maxWidth,
              child: PromptInputToolbar(
                controller: controller,
                commands: commands,
                viewData: viewData,
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              fit: viewData.autoGrow ? FlexFit.loose : FlexFit.tight,
              child: editor,
            ),
            buildFooter(includeBottomActions: true),
          ],
        );
      },
    );
  }
}

class _CompactPromptModeSwitch extends StatelessWidget {
  const _CompactPromptModeSwitch({
    required this.negative,
    required this.positiveCount,
    required this.negativeCount,
    required this.onChanged,
  });

  final bool negative;
  final int positiveCount;
  final int negativeCount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    Widget button({
      required Key key,
      required String label,
      required int count,
      required bool value,
      required Color selectedColor,
    }) {
      final selected = negative == value;
      return Expanded(
        child: TextButton(
          key: key,
          onPressed: () => onChanged(value),
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            foregroundColor: selected ? selectedColor : colors.onSurfaceVariant,
            backgroundColor: selected
                ? selectedColor.withValues(alpha: 0.14)
                : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 5),
              PromptTagCountBadge(
                count: count,
                selected: selected,
                color: selectedColor,
                compact: true,
              ),
            ],
          ),
        ),
      );
    }

    return ColoredBox(
      color: colors.surfaceContainerHigh.withValues(alpha: 0.7),
      child: Row(
        children: [
          button(
            key: const ValueKey('generation_prompt_compact_positive_mode'),
            label: context.l10n.prompt_positive,
            count: positiveCount,
            value: false,
            selectedColor: colors.primary,
          ),
          const SizedBox(width: 6),
          button(
            key: const ValueKey('generation_prompt_compact_negative_mode'),
            label: context.l10n.prompt_negative,
            count: negativeCount,
            value: true,
            selectedColor: colors.error,
          ),
        ],
      ),
    );
  }
}

class _CompactPromptInput extends ConsumerWidget {
  const _CompactPromptInput({
    required this.editorKey,
    required this.controller,
    required this.commands,
    required this.viewData,
  });

  final GlobalKey editorKey;
  final PromptInputController controller;
  final PromptInputCommands commands;
  final PromptInputViewData viewData;

  @override
  Widget build(BuildContext context, WidgetRef ref) => LayoutBuilder(
    builder: (context, constraints) {
      final assistantVisible = _isPromptAssistantVisible(context, ref);
      final negative = controller.isNegativeMode;
      final showFooter = constraints.maxHeight >= 112;
      final showModeSwitch = constraints.maxHeight >= 180;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showModeSwitch) ...[
            ListenableBuilder(
              listenable: Listenable.merge([
                controller.promptController,
                controller.negativeController,
              ]),
              builder: (context, _) => _CompactPromptModeSwitch(
                negative: negative,
                positiveCount: controller.promptCount,
                negativeCount: controller.negativePromptCount,
                onChanged: commands.setNegativeMode,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Expanded(
            child: PromptInputEditor(
              key: editorKey,
              controller: controller,
              commands: commands,
              viewData: viewData,
              compact: true,
            ),
          ),
          if (showFooter)
            PromptInputFooter(
              target: negative
                  ? PromptTokenCountTarget.negative
                  : PromptTokenCountTarget.positive,
              topPadding: 4,
              leading: Row(
                key: const ValueKey('generation_prompt_compact_actions'),
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (viewData.showMaximizeButton)
                    IconButton(
                      icon: const Icon(Icons.fullscreen),
                      tooltip: context.l10n.tooltip_fullscreenEdit,
                      onPressed: commands.toggleMaximize,
                    ),
                  if ((negative
                          ? controller.negativeController
                          : controller.promptController)
                      .text
                      .isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      tooltip: context.l10n.common_clear,
                      onPressed: negative
                          ? commands.clearNegativePrompt
                          : commands.clearPrompt,
                    ),
                ],
              ),
              assistant: assistantVisible
                  ? PromptAssistantOverlay(
                      sessionId: negative
                          ? PromptHistorySessionIds.generationNegative
                          : PromptHistorySessionIds.generationPrompt,
                      controller: negative
                          ? controller.negativeController
                          : controller.promptController,
                      interactionPolicy: context.interactionPolicy,
                      onChanged: negative
                          ? commands.updateNegativePrompt
                          : commands.updatePrompt,
                      onOpenSettings: commands.openAssistantSettings,
                      floatOverEditor: false,
                      expandInPlace: false,
                    )
                  : null,
              assistantToolbarHeight: assistantVisible
                  ? PromptAssistantOverlay.effectiveInlineToolbarHeight(
                      context.interactionPolicy,
                    )
                  : 0,
              assistantExpandedWidth: assistantVisible
                  ? PromptAssistantOverlay.expandedInlineToolbarWidth(
                      context.interactionPolicy,
                    )
                  : 0,
            ),
        ],
      );
    },
  );
}
