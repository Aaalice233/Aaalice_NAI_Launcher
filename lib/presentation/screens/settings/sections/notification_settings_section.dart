import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../providers/notification_settings_provider.dart';
import '../widgets/settings_card.dart';

/// 通知设置板块
///
/// 提供音效开关和自定义音效选择功能。
class NotificationSettingsSection extends ConsumerWidget {
  const NotificationSettingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsNotifierProvider);
    final notifier = ref.read(notificationSettingsNotifierProvider.notifier);
    final l10n = context.l10n;

    return SettingsCard(
      title: l10n.settings_notification,
      icon: Icons.notifications,
      child: Column(
        children: [
          // 音效开关
          SwitchListTile(
            secondary: const Icon(Icons.volume_up_outlined),
            title: Text(l10n.settings_notificationSound),
            subtitle: Text(l10n.settings_notificationSoundSubtitle),
            value: settings.soundEnabled,
            onChanged: (value) => notifier.setSoundEnabled(value),
          ),

          // 自定义音效（仅在音效开启时显示）
          if (settings.soundEnabled)
            ListTile(
              leading: const Icon(Icons.audiotrack_outlined),
              title: Text(l10n.settings_notificationCustomSound),
              subtitle: Text(
                settings.customSoundPath != null
                    ? settings.customSoundPath!
                        .split(Platform.pathSeparator)
                        .last
                    : l10n.settings_notificationSelectSound,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (settings.customSoundPath != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      tooltip: l10n.settings_notificationResetSound,
                      onPressed: () => notifier.setCustomSoundPath(null),
                    ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () => _selectCustomSound(context, notifier),
            ),
        ],
      ),
    );
  }

  Future<void> _selectCustomSound(
    BuildContext context,
    NotificationSettingsNotifier notifier,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'wav', 'ogg', 'm4a'],
    );
    if (result != null && result.files.single.path != null) {
      await notifier.setCustomSoundPath(result.files.single.path);
    }
  }
}
