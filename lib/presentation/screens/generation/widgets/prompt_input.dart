import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/platform/platform_capabilities.dart';
import '../../../../core/utils/localization_extension.dart';
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

bool usesRichPromptTypeTooltip(TargetPlatform platform) =>
    shouldUseRichPromptTypeTooltip(platform);

bool _isPromptAssistantVisible(WidgetRef ref) {
  final config = ref.watch(promptAssistantConfigProvider);
  return config.enabled &&
      (!PlatformCapabilities.current.hasPrecisePointer ||
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
    this.autoGrow = false,
  });

  final bool compact;
  final VoidCallback? onToggleMaximize;
  final bool isMaximized;
  final bool showMaximizeButton;
  final bool autofocus;
  final ValueNotifier<bool>? negativeModeNotifier;
  final bool autoGrow;

  @override
  ConsumerState<PromptInputWidget> createState() => _PromptInputWidgetState();
}

class _PromptInputWidgetState extends ConsumerState<PromptInputWidget> {
  late final PromptInputController _controller;
  late final PromptInputCoordinator _coordinator;

  @override
  void initState() {
    super.initState();
    final params = ref.read(generationParamsNotifierProvider);
    _controller = PromptInputController(
      prompt: params.prompt,
      negativePrompt: params.negativePrompt,
      negativeModeNotifier: widget.negativeModeNotifier,
    )..addListener(_onControllerChanged);
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
    if (!identical(
      oldWidget.negativeModeNotifier,
      widget.negativeModeNotifier,
    )) {
      _controller.bindNegativeModeNotifier(widget.negativeModeNotifier);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
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
      compact: widget.compact,
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
        controller: _controller,
        commands: commands,
        viewData: viewData,
      );
    }
    return _FullPromptInput(
      controller: _controller,
      commands: commands,
      viewData: viewData,
    );
  }
}

class _FullPromptInput extends ConsumerWidget {
  const _FullPromptInput({
    required this.controller,
    required this.commands,
    required this.viewData,
  });

  final PromptInputController controller;
  final PromptInputCommands commands;
  final PromptInputViewData viewData;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final negative = controller.isNegativeMode;
    final assistantSessionId = negative
        ? PromptHistorySessionIds.generationNegative
        : PromptHistorySessionIds.generationPrompt;
    final assistantVisible = _isPromptAssistantVisible(ref);
    final assistantExpanded =
        assistantVisible &&
        ref.watch(
          promptAssistantStateProvider.select(
            (states) => states[assistantSessionId]?.expanded ?? false,
          ),
        );
    final editor = PromptInputEditor(
      controller: controller,
      commands: commands,
      viewData: viewData,
    );
    final footer = PromptInputFooter(
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
              onChanged: negative
                  ? commands.updateNegativePrompt
                  : commands.updatePrompt,
              onOpenSettings: commands.openAssistantSettings,
              floatOverEditor: false,
            )
          : null,
      assistantExpanded: assistantExpanded,
      assistantCollapsedWidth: assistantVisible
          ? PromptAssistantOverlay.inlineCollapsedWidth
          : 0,
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
            mobileFooter: footer,
          );
        }
        return Column(
          mainAxisSize: viewData.autoGrow ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PromptInputToolbar(
              controller: controller,
              commands: commands,
              viewData: viewData,
            ),
            const SizedBox(height: 8),
            if (viewData.autoGrow) editor else Expanded(child: editor),
            footer,
          ],
        );
      },
    );
  }
}

class _CompactPromptInput extends ConsumerWidget {
  const _CompactPromptInput({
    required this.controller,
    required this.commands,
    required this.viewData,
  });

  final PromptInputController controller;
  final PromptInputCommands commands;
  final PromptInputViewData viewData;

  @override
  Widget build(BuildContext context, WidgetRef ref) => LayoutBuilder(
    builder: (context, constraints) {
      final assistantVisible = _isPromptAssistantVisible(ref);
      final showFooter = constraints.maxHeight >= 112;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: PromptInputEditor(
              controller: controller,
              commands: commands,
              viewData: viewData,
              compact: true,
            ),
          ),
          if (showFooter)
            PromptInputFooter(
              target: PromptTokenCountTarget.positive,
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
                  if (controller.promptController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 20),
                      tooltip: context.l10n.common_clear,
                      onPressed: commands.clearPrompt,
                    ),
                ],
              ),
              assistant: assistantVisible
                  ? PromptAssistantOverlay(
                      sessionId: PromptHistorySessionIds.generationPrompt,
                      controller: controller.promptController,
                      onChanged: commands.updatePrompt,
                      onOpenSettings: commands.openAssistantSettings,
                      floatOverEditor: false,
                      expandInPlace: false,
                    )
                  : null,
              assistantCollapsedWidth: assistantVisible
                  ? PromptAssistantOverlay.inlineCollapsedWidth
                  : 0,
            ),
        ],
      );
    },
  );
}
