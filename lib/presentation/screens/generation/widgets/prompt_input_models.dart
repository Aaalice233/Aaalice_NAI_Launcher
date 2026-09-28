import 'package:flutter/foundation.dart';

import '../../../../data/models/character/character_prompt.dart';

@immutable
class PromptInputViewData {
  const PromptInputViewData({
    required this.autoGrow,
    required this.isMaximized,
    required this.showMaximizeButton,
    required this.numericEmphasisEnabled,
  });

  final bool autoGrow;
  final bool isMaximized;
  final bool showMaximizeButton;
  final bool numericEmphasisEnabled;
}

typedef PromptImportCallback =
    void Function(String globalPrompt, List<CharacterPrompt> characters);

@immutable
class PromptInputCommands {
  const PromptInputCommands({
    required this.setNegativeMode,
    required this.updatePrompt,
    required this.updateNegativePrompt,
    required this.importComfyuiPrompt,
    required this.clearPrompt,
    required this.clearNegativePrompt,
    required this.generateRandomPrompt,
    required this.openAssistantSettings,
    required this.showMobileCharacterManager,
    required this.toggleMaximize,
  });

  final ValueChanged<bool> setNegativeMode;
  final ValueChanged<String> updatePrompt;
  final ValueChanged<String> updateNegativePrompt;
  final PromptImportCallback importComfyuiPrompt;
  final VoidCallback clearPrompt;
  final VoidCallback clearNegativePrompt;
  final Future<void> Function() generateRandomPrompt;
  final VoidCallback openAssistantSettings;
  final Future<void> Function() showMobileCharacterManager;
  final VoidCallback toggleMaximize;
}
