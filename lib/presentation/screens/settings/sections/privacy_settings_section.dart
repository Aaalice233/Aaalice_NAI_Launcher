import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/localization_extension.dart';
import '../../../../data/models/watermark/watermark_settings.dart';
import '../../../providers/share_image_settings_provider.dart';
import '../../../providers/watermark_settings_provider.dart';
import '../../watermark/watermark_editor_launcher.dart';
import '../../../widgets/online_gallery/blacklist_settings_panel.dart';
import '../widgets/settings_card.dart';
import '../widgets/settings_page_layout.dart';

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

  Future<void> _editGenerationInterval() async {
    final settings = ref.read(shareImageSettingsProvider);
    final controller = TextEditingController(
      text: settings.generationIntervalSeconds.toString(),
    );
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.settings_setGenerationIntervalTitle),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: context.l10n.settings_generationIntervalTitle,
            suffixText: context.l10n.unit_seconds,
            helperText: context.l10n.settings_generationIntervalHelper,
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
              if (value != null && value >= 1 && value <= 3600) {
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
        .setGenerationIntervalSeconds(result);
  }

  @override
  Widget build(BuildContext context) {
    final shareSettings = ref.watch(shareImageSettingsProvider);
    final watermarkState = ref.watch(watermarkSettingsProvider);
    final watermarkSettings = watermarkState.configuration;
    final watermarkControlsEnabled = watermarkState.loadIssue == null;

    return SettingsPageLayout(
      title: context.l10n.settings_privacySharing,
      children: [
        SettingsCard(
          title: context.l10n.settings_protectionMode,
          icon: Icons.shield_outlined,
          onTap: () async {
            await ref
                .read(shareImageSettingsProvider.notifier)
                .setProtectionMode(!shareSettings.protectionMode);
          },
          trailing: Switch.adaptive(
            value: shareSettings.protectionMode,
            onChanged: (value) async {
              await ref
                  .read(shareImageSettingsProvider.notifier)
                  .setProtectionMode(value);
            },
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Text(context.l10n.settings_protectionModeSubtitle),
          ),
        ),
        SettingsCard(
          title: context.l10n.settings_protectionFeatures,
          icon: Icons.security_outlined,
          child: Column(
            children: [
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
              SwitchListTile(
                secondary: const Icon(Icons.timer_outlined),
                title: Text(context.l10n.settings_limitGenerationIntervalTitle),
                subtitle: Text(
                  context.l10n.settings_limitGenerationIntervalSubtitle,
                ),
                value: shareSettings.limitGenerationInterval,
                onChanged: shareSettings.protectionMode
                    ? (value) async {
                        await ref
                            .read(shareImageSettingsProvider.notifier)
                            .setLimitGenerationInterval(value);
                      }
                    : null,
              ),
              ListTile(
                enabled:
                    shareSettings.protectionMode &&
                    shareSettings.limitGenerationInterval,
                leading: const Icon(Icons.hourglass_bottom_outlined),
                title: Text(context.l10n.settings_generationIntervalTitle),
                subtitle: Text(
                  context.l10n.settings_generationIntervalValue(
                    shareSettings.generationIntervalSeconds,
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap:
                    shareSettings.protectionMode &&
                        shareSettings.limitGenerationInterval
                    ? _editGenerationInterval
                    : null,
              ),
            ],
          ),
        ),
        SettingsCard(
          title: context.l10n.settings_watermarkTitle,
          icon: Icons.branding_watermark_outlined,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(context.l10n.settings_watermarkSubtitle),
                ),
              ),
              if (watermarkState.loadIssue != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          watermarkState.loadIssue ==
                                  WatermarkSettingsLoadIssue.corrupted
                              ? context.l10n.settings_watermarkConfigCorrupted
                              : context.l10n.settings_watermarkConfigMigrated,
                        ),
                      ),
                      TextButton(
                        onPressed: () => ref
                            .read(watermarkSettingsProvider.notifier)
                            .saveDefaults(),
                        child: Text(context.l10n.common_save),
                      ),
                    ],
                  ),
                ),
              SwitchListTile(
                secondary: const Icon(Icons.toggle_on_outlined),
                title: Text(context.l10n.settings_watermarkEnable),
                value: watermarkSettings.enabled,
                onChanged: watermarkControlsEnabled
                    ? (value) => ref
                          .read(watermarkSettingsProvider.notifier)
                          .updateConfiguration(
                            watermarkSettings.copyWith(enabled: value),
                          )
                    : null,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.data_object_outlined),
                title: Text(context.l10n.settings_watermarkPreserveMetadata),
                subtitle: Text(
                  context.l10n.settings_watermarkPreserveMetadataHint,
                ),
                value: watermarkSettings.preserveMetadata,
                onChanged: watermarkControlsEnabled
                    ? (value) => ref
                          .read(watermarkSettingsProvider.notifier)
                          .updateConfiguration(
                            watermarkSettings.copyWith(preserveMetadata: value),
                          )
                    : null,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.screen_rotation_alt_outlined),
                title: Text(context.l10n.settings_watermarkLayoutByOrientation),
                subtitle: Text(
                  context.l10n.settings_watermarkLayoutByOrientationHint,
                ),
                value: watermarkSettings.rememberLayoutsByOrientation,
                onChanged: watermarkControlsEnabled
                    ? (value) => ref
                          .read(watermarkSettingsProvider.notifier)
                          .updateConfiguration(
                            watermarkSettings.copyWith(
                              rememberLayoutsByOrientation: value,
                            ),
                          )
                    : null,
              ),
              ListTile(
                enabled: watermarkControlsEnabled && watermarkSettings.enabled,
                leading: const Icon(Icons.add_photo_alternate_outlined),
                title: Text(context.l10n.settings_watermarkCreateFromImage),
                trailing: const Icon(Icons.chevron_right),
                onTap: watermarkControlsEnabled && watermarkSettings.enabled
                    ? () => WatermarkEditorLauncher.pickSourceAndOpen(
                        context: context,
                      )
                    : null,
              ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(context.l10n.settings_watermarkEditDefault),
                subtitle: watermarkState.localLogoMissing
                    ? Text(
                        context.l10n.watermark_logoMissing,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      )
                    : null,
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    WatermarkEditorLauncher.editDefaults(context: context),
              ),
            ],
          ),
        ),
        const OnlineGalleryBlacklistSettingsPanel(),
      ],
    );
  }
}
