import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_version.dart';
import '../widgets/settings_card.dart';

/// 关于设置板块
///
/// 显示应用信息、版本号和开源链接。
class AboutSettingsSection extends ConsumerStatefulWidget {
  const AboutSettingsSection({super.key});

  @override
  ConsumerState<AboutSettingsSection> createState() =>
      _AboutSettingsSectionState();
}

class _AboutSettingsSectionState extends ConsumerState<AboutSettingsSection> {
  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      title: '关于',
      icon: Icons.info,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(context.l10n.app_title),
            subtitle: Text(context.l10n.settings_version(AppVersion.versionName)),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: Text(context.l10n.settings_openSource),
            subtitle: Text(context.l10n.settings_openSourceSubtitle),
            trailing: const Icon(Icons.open_in_new),
            onTap: () async {
              final uri = Uri.parse(
                'https://github.com/Aaalice233/Aaalice_NAI_Launcher',
              );
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ],
      ),
    );
  }
}
