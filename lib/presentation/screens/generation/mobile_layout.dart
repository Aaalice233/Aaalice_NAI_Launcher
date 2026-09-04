import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/api_constants.dart';
import '../../../core/platform/platform_capabilities.dart';
import '../../../core/utils/localization_extension.dart';
import '../../providers/auth_provider.dart';
import '../../providers/character_prompt_provider.dart';
import '../../providers/fixed_tags_provider.dart';
import '../../providers/generation/image_workflow_controller.dart';
import '../../providers/image_generation_provider.dart';
import '../../providers/krita/krita_bridge_notifier.dart';
import '../../providers/prompt_maximize_provider.dart';
import '../../providers/quality_preset_provider.dart';
import '../../providers/uc_preset_provider.dart';
import '../../widgets/common/owned_scroll_controller.dart';
import 'mobile_generation_controller.dart';
import 'mobile_generation_shell.dart';
import 'mobile_generation_view_data.dart';
import 'widgets/prompt_input_controller.dart';

/// Stable mobile generation entry point. Stateful interaction and rendering
/// responsibilities live in dedicated controller and component classes.
class MobileGenerationLayout extends ConsumerStatefulWidget {
  const MobileGenerationLayout({
    super.key,
    this.historyViewport,
    this.promptInputController,
    this.promptInputKey,
  });

  final OwnedViewportOffset? historyViewport;
  final PromptInputController? promptInputController;
  final GlobalKey? promptInputKey;

  @override
  ConsumerState<MobileGenerationLayout> createState() =>
      _MobileGenerationLayoutState();
}

class _MobileGenerationLayoutState
    extends ConsumerState<MobileGenerationLayout> {
  late final MobileGenerationController _controller;
  late final OwnedViewportOffset _historyViewport;
  late final PromptInputController _promptInputController;
  late final GlobalKey _promptInputKey;
  late final bool _ownsPromptInputController;

  @override
  void initState() {
    super.initState();
    _controller = MobileGenerationController(ref);
    _historyViewport = widget.historyViewport ?? OwnedViewportOffset();
    _ownsPromptInputController = widget.promptInputController == null;
    _promptInputKey =
        widget.promptInputKey ??
        GlobalKey(debugLabel: 'mobile-generation-prompt');
    final params = ref.read(generationParamsNotifierProvider);
    _promptInputController =
        widget.promptInputController ??
        PromptInputController(
          prompt: params.prompt,
          negativePrompt: params.negativePrompt,
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_ownsPromptInputController) _promptInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final generationState = ref.watch(imageGenerationNotifierProvider);
    final cooldownState = ref.watch(generationCooldownProvider);
    final isAuthenticated = ref.watch(
      authNotifierProvider.select((state) => state.isAuthenticated),
    );
    final supportsKrita = PlatformCapabilities.current.supportsKritaBridge;
    final isKritaGenerating = supportsKrita
        ? ref.watch(kritaBridgeNotifierProvider).isBridgeGenerating
        : false;
    final isPromptMaximized = ref.watch(promptMaximizeNotifierProvider);
    final showRandomTools = ref.watch(randomPromptToolsVisibilityProvider);
    final isUpscaleMode = ref.watch(
      imageWorkflowControllerProvider.select((workflow) => workflow.isUpscale),
    );
    final randomModeEnabled = ref.watch(randomPromptModeProvider);
    final promptSummary = ref.watch(
      generationParamsNotifierProvider.select((params) => params.prompt.trim()),
    );
    final enabledCharacterCount = ref.watch(
      characterPromptNotifierProvider.select(
        (config) =>
            config.characters.where((character) => character.enabled).length,
      ),
    );
    final qualityEnabled = ref.watch(
      qualityPresetNotifierProvider.select((state) => state.isEnabled),
    );
    final ucPresetState = ref.watch(ucPresetNotifierProvider);
    final fixedTagCount = ref.watch(
      fixedTagsNotifierProvider.select(
        (state) => state.enabledCount + state.negativeEnabledCount,
      ),
    );

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // The outer navigation Scaffold may consume the descendant MediaQuery
        // inset, so IME visibility intentionally uses both sources.
        final keyboardVisible =
            MediaQuery.viewInsetsOf(context).bottom > 0 ||
            View.of(context).viewInsets.bottom > 0;
        _controller.updateKeyboardVisibility(keyboardVisible);
        final isLauncherGenerating = generationState.isGenerating;
        final isGenerating = isLauncherGenerating || isKritaGenerating;
        final negativePresetLabel = ucPresetState.isCustom
            ? context.l10n.ucPreset_label
            : switch (ucPresetState.presetType) {
                UcPresetType.heavy => context.l10n.ucPreset_heavy,
                UcPresetType.light => context.l10n.ucPreset_light,
                UcPresetType.furryFocus => context.l10n.ucPreset_furryFocus,
                UcPresetType.humanFocus => context.l10n.ucPreset_humanFocus,
                UcPresetType.none => null,
              };
        final data = MobileGenerationViewData(
          generationState: generationState,
          cooldownRemainingSeconds: cooldownState.remainingSeconds,
          isPromptMaximized: isPromptMaximized,
          keyboardVisible: keyboardVisible,
          isGenerating: isGenerating,
          isLauncherGenerating: isLauncherGenerating,
          requiresLogin: !isAuthenticated && !isGenerating,
          showRandomTools: showRandomTools,
          isUpscaleMode: isUpscaleMode,
          randomModeEnabled: randomModeEnabled,
          promptSummary: promptSummary,
          enabledCharacterCount: enabledCharacterCount,
          qualityEnabled: qualityEnabled,
          negativePresetLabel: negativePresetLabel,
          fixedTagCount: fixedTagCount,
        );
        return MobileGenerationShell(
          controller: _controller,
          data: data,
          historyViewport: _historyViewport,
          promptInputController: _promptInputController,
          promptInputKey: _promptInputKey,
        );
      },
    );
  }
}
