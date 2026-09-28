import '../../providers/image_generation_provider.dart';

class MobileGenerationViewData {
  const MobileGenerationViewData({
    required this.generationState,
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

  final ImageGenerationState generationState;
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
