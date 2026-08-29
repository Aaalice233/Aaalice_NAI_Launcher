import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../widgets/settings_card.dart';
import '../widgets/settings_page_layout.dart';
import '../widgets/shortcut_settings_panel.dart';

/// 快捷键设置板块
///
/// 显示快捷键设置入口，点击后打开快捷键设置面板
class ShortcutSettingsSection extends ConsumerStatefulWidget {
  const ShortcutSettingsSection({super.key});

  @override
  ConsumerState<ShortcutSettingsSection> createState() =>
      _ShortcutSettingsSectionState();
}

class _ShortcutSettingsSectionState
    extends ConsumerState<ShortcutSettingsSection> {
  @override
  Widget build(BuildContext context) {
    return SettingsPageLayout(
      title: context.l10n.settings_shortcuts,
      children: [
        SettingsCard(
          title: context.l10n.settings_shortcutManagementSection,
          child: ListTile(
            leading: const Icon(Icons.keyboard_outlined),
            title: Text(context.l10n.shortcut_settings_title),
            subtitle: Text(context.l10n.settings_shortcutsSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => ShortcutSettingsPanel.show(context),
          ),
        ),
      ],
    );
  }
}
