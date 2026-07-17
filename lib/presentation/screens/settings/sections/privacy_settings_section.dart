import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../providers/share_image_settings_provider.dart';
import '../../../widgets/online_gallery/blacklist_settings_panel.dart';
import '../widgets/settings_card.dart';
import '../widgets/settings_section_label.dart';

/// 安全与分享设置板块
///
/// 集中管理保护模式（分享脱敏、危险操作确认、高消耗警告等）
/// 与在线画廊内容屏蔽。
class PrivacySettingsSection extends ConsumerStatefulWidget {
  const PrivacySettingsSection({super.key});

  @override
  ConsumerState<PrivacySettingsSection> createState() =>
      _PrivacySettingsSectionState();
}

class _PrivacySettingsSectionState
    extends ConsumerState<PrivacySettingsSection> {
  Future<void> _editHighAnlasThreshold() async {
    final settings = ref.read(shareImageSettingsProvider);
    final controller = TextEditingController(
      text: settings.highAnlasCostThreshold.toString(),
    );
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.settings_setHighAnlasCostThresholdTitle),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: context.l10n.settings_threshold,
            suffixText: 'Anlas',
            helperText: context.l10n.settings_highAnlasCostThresholdHelper,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value != null && value > 0) {
                Navigator.of(dialogContext).pop(value);
              }
            },
            child: Text(context.l10n.common_save),
          ),
        ],
      ),
    );

    controller.dispose();
    if (result == null) {
      return;
    }
    await ref
        .read(shareImageSettingsProvider.notifier)
        .setHighAnlasCostThreshold(result);
  }

  @override
  Widget build(BuildContext context) {
    final shareSettings = ref.watch(shareImageSettingsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsCard(
          title: context.l10n.settings_privacySharing,
          icon: Icons.shield_outlined,
          child: Column(
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.shield_outlined),
                title: Text(context.l10n.settings_protectionMode),
                subtitle: Text(context.l10n.settings_protectionModeSubtitle),
                value: shareSettings.protectionMode,
                onChanged: (value) async {
                  await ref
                      .read(shareImageSettingsProvider.notifier)
                      .setProtectionMode(value);
                },
              ),
              SettingsSectionLabel(context.l10n.settings_protectionFeatures),
              SwitchListTile(
                secondary: const Icon(Icons.cleaning_services_outlined),
                title: Text(context.l10n.settings_stripMetadataTitle),
                subtitle: Text(context.l10n.settings_stripMetadataSubtitle),
                value: shareSettings.stripMetadataForCopyAndDrag,
                onChanged: shareSettings.protectionMode
                    ? (value) async {
                        await ref
                            .read(shareImageSettingsProvider.notifier)
                            .setStripMetadataForCopyAndDrag(value);
                      }
                    : null,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.warning_amber_rounded),
                title: Text(context.l10n.settings_confirmDangerousActionsTitle),
                subtitle: Text(
                  context.l10n.settings_confirmDangerousActionsSubtitle,
                ),
                value: shareSettings.confirmDangerousActions,
                onChanged: shareSettings.protectionMode
                    ? (value) async {
                        await ref
                            .read(shareImageSettingsProvider.notifier)
                            .setConfirmDangerousActions(value);
                      }
                    : null,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.cloud_upload_outlined),
                title: Text(context.l10n.settings_warnExternalImageSendTitle),
                subtitle: Text(
                  context.l10n.settings_warnExternalImageSendSubtitle,
                ),
                value: shareSettings.warnExternalImageSend,
                onChanged: shareSettings.protectionMode
                    ? (value) async {
                        await ref
                            .read(shareImageSettingsProvider.notifier)
                            .setWarnExternalImageSend(value);
                      }
                    : null,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.file_copy_outlined),
                title: Text(context.l10n.settings_preventOverwriteTitle),
                subtitle: Text(context.l10n.settings_preventOverwriteSubtitle),
                value: shareSettings.preventOverwrite,
                onChanged: shareSettings.protectionMode
                    ? (value) async {
                        await ref
                            .read(shareImageSettingsProvider.notifier)
                            .setPreventOverwrite(value);
                      }
                    : null,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.toll_outlined),
                title: Text(context.l10n.settings_warnHighAnlasCostTitle),
                subtitle: Text(
                  context.l10n.settings_warnHighAnlasCostSubtitle(
                    shareSettings.highAnlasCostThreshold,
                  ),
                ),
                value: shareSettings.warnHighAnlasCost,
                onChanged: shareSettings.protectionMode
                    ? (value) async {
                        await ref
                            .read(shareImageSettingsProvider.notifier)
                            .setWarnHighAnlasCost(value);
                      }
                    : null,
              ),
              ListTile(
                enabled:
                    shareSettings.protectionMode &&
                    shareSettings.warnHighAnlasCost,
                leading: const Icon(Icons.speed_outlined),
                title: Text(context.l10n.settings_highAnlasCostThresholdTitle),
                subtitle: Text('${shareSettings.highAnlasCostThreshold} Anlas'),
                trailing: const Icon(Icons.chevron_right),
                onTap:
                    shareSettings.protectionMode &&
                        shareSettings.warnHighAnlasCost
                    ? _editHighAnlasThreshold
                    : null,
              ),
            ],
          ),
        ),
        const OnlineGalleryBlacklistSettingsPanel(),
      ],
    );
  }
}
