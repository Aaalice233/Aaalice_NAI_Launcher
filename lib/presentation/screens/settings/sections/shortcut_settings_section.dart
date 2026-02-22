import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/settings_card.dart';
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
    return SettingsCard(
      title: '快捷键',
      icon: Icons.keyboard,
      child: ListTile(
        leading: const Icon(Icons.keyboard_outlined),
        title: const Text('快捷键'),
        subtitle: const Text('自定义键盘快捷键'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => ShortcutSettingsPanel.show(context),
      ),
    );
  }
}
