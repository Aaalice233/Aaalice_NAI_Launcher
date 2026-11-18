import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/image/image_params.dart';
import '../../../prompt_assistant/providers/prompt_assistant_history_provider.dart';
import '../../../prompt_assistant/widgets/prompt_assistant_overlay.dart';
import '../../../providers/image_generation_provider.dart';
import 'prompt_input_controller.dart';
import 'prompt_input_models.dart';

/// 模型固定 UC 预设时负向提示词不会发送，只读保留给切回后的模型使用。
bool watchPromptInputLocked(WidgetRef ref, PromptInputController controller) =>
    controller.isNegativeMode &&
    ref.watch(
      generationParamsNotifierProvider.select(
        (params) => params.usesFixedSettings,
      ),
    );

/// Main prompt assistant, docked in the footer beside the token count.
PromptAssistantOverlay buildPromptInputAssistant(
  WidgetRef ref, {
  required Key key,
  required PromptInputController controller,
  required PromptInputCommands commands,
}) {
  final negative = controller.isNegativeMode;
  return PromptAssistantOverlay(
    key: key,
    placement: PromptAssistantPlacement.inline,
    iconOnly: true,
    supportsTagMode: true,
    enabled: !watchPromptInputLocked(ref, controller),
    sessionId: negative
        ? PromptHistorySessionIds.generationNegative
        : PromptHistorySessionIds.generationPrompt,
    controller: negative
        ? controller.negativeController
        : controller.promptController,
    onChanged: negative ? commands.updateNegativePrompt : commands.updatePrompt,
    onOpenSettings: commands.openAssistantSettings,
  );
}
