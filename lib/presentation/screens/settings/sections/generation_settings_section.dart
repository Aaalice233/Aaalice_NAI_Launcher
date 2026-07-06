import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../providers/generation/generation_settings_notifiers.dart';
import '../widgets/settings_card.dart';

/// 生成设置板块
///
/// 放置直接影响生成页操作入口的设置。
class GenerationSettingsSection extends ConsumerWidget {
  const GenerationSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final showRandomTools = ref.watch(randomPromptToolsVisibilityProvider);

    return SettingsCard(
      title: l10n.settings_generation,
      icon: Icons.tune_outlined,
      child: SwitchListTile(
        secondary: const Icon(Icons.casino_outlined),
        title: Text(l10n.settings_showRandomPromptTools),
        subtitle: Text(l10n.settings_showRandomPromptToolsSubtitle),
        value: showRandomTools,
        onChanged: (value) {
          ref.read(randomPromptToolsVisibilityProvider.notifier).set(value);
        },
      ),
    );
  }
}
