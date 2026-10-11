import '../../providers/generation/image_generation_selectors.dart';

class MobileGenerationViewData {
  const MobileGenerationViewData({
    required this.batchStatus,
    required this.cooldownRemainingSeconds,
    required this.isPromptMaximized,
    required this.keyboardVisible,
    required this.isGenerating,
    required this.isLauncherGenerating,
    required this.requiresLogin,
    required this.showRandomTools,
    required this.isUpscaleMode,
    required this.randomModeEnabled,
    required this.promptSummary,
    required this.enabledCharacterCount,
    required this.qualityEnabled,
    required this.negativePresetLabel,
    required this.fixedTagCount,
  });

  final GenerationButtonViewData batchStatus;
  final int cooldownRemainingSeconds;
  final bool isPromptMaximized;
  final bool keyboardVisible;
  final bool isGenerating;
  final bool isLauncherGenerating;
  final bool requiresLogin;
  final bool showRandomTools;
  final bool isUpscaleMode;
  final bool randomModeEnabled;
  final String promptSummary;
  final int enabledCharacterCount;
  final bool qualityEnabled;
  final String? negativePresetLabel;
  final int fixedTagCount;
}
