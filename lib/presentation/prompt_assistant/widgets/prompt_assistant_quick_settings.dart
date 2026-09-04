import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/localization_extension.dart';
import '../../adaptive/adaptive_presenter.dart';
import '../providers/prompt_assistant_config_provider.dart';

class PromptAssistantQuickSettings {
  const PromptAssistantQuickSettings._();

  static Future<void> show(BuildContext context) {
    return AdaptivePresenter.showPanel<void>(
      context: context,
      title: context.l10n.promptAssistant_assistantSettings,
      initialChildSize: 0.42,
      minChildSize: 0.32,
      dialogWidth: 440,
      builder: (context, scrollController) => Consumer(
        builder: (context, ref, _) {
          final config = ref.watch(promptAssistantConfigProvider);
          final notifier = ref.read(promptAssistantConfigProvider.notifier);
          return ListView(
            controller: scrollController,
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              SwitchListTile(
                title: Text(context.l10n.promptAssistant_enableAssistant),
                value: config.enabled,
                onChanged: notifier.setEnabled,
              ),
              SwitchListTile(
                title: Text(context.l10n.promptAssistant_desktopOverlay),
                value: config.desktopOverlayEnabled,
                onChanged: notifier.setDesktopOverlayEnabled,
              ),
            ],
          );
        },
      ),
    );
  }
}
