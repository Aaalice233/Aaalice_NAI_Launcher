import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nai_launcher/core/utils/localization_extension.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_version.dart';
import '../../../../core/constants/community_links.dart';
import '../../../../core/platform/platform_capabilities.dart';
import '../../../../core/services/diagnostic_log_export_service.dart';
import '../../../../core/services/update_check_service.dart';
import '../../../../core/storage/local_storage_service.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../providers/update_provider.dart';
import '../../../widgets/common/update_check_dialog.dart';
import '../widgets/settings_card.dart';
import '../widgets/settings_page_layout.dart';

/// Release 页面。iOS 侧载版只能从这里取新版 IPA 自行签名。
const String _releasesPageUrl = '${CommunityLinks.github}/releases';

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
  bool _isExportingLogs = false;

  @override
  Widget build(BuildContext context) {
    final updateState = ref.watch(updateStateProvider);
    final updateNotifier = ref.read(updateStateProvider.notifier);
    final updateService = ref.watch(updateCheckServiceProvider);
    final localStorageService = ref.watch(localStorageServiceProvider);
    final fileLoggingEnabled = localStorageService.getFileLoggingEnabled();

    return SettingsPageLayout(
      title: context.l10n.settings_about,
      children: [
        SettingsCard(
          title: context.l10n.settings_aboutApplicationSection,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(context.l10n.app_title),
                subtitle: Text(
                  context.l10n.settings_version(AppVersion.versionName),
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.article_outlined),
                title: Text(context.l10n.settings_fileLogging),
                subtitle: Text(context.l10n.settings_fileLoggingSubtitle),
                value: fileLoggingEnabled,
                onChanged: (value) async {
                  await AppLogger.setFileLoggingEnabled(value);
                  await localStorageService.setFileLoggingEnabled(
                    AppLogger.fileLoggingEnabled,
                  );
                  if (mounted) {
                    setState(() {});
                  }
                },
              ),
              ListTile(
                key: const ValueKey('export-diagnostic-logs'),
                leading: const Icon(Icons.file_download_outlined),
                title: Text(context.l10n.settings_exportDiagnosticLogs),
                subtitle: Text(
                  context.l10n.settings_exportDiagnosticLogsSubtitle,
                ),
                trailing: _isExportingLogs
                    ? Semantics(
                        liveRegion: true,
                        label: context
                            .l10n
                            .settings_exportDiagnosticLogsInProgress,
                        child: const ExcludeSemantics(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: _isExportingLogs ? null : _exportDiagnosticLogs,
              ),
            ],
          ),
        ),
        SettingsCard(
          title: context.l10n.settings_aboutUpdatesSection,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 【偏离上游】上游无条件渲染「检查更新」与「包含预发布版本」两项。
              // iOS 是自签侧载：Release 里没有 iOS 资产，检查更新只会失败或把
              // 桌面/安卓安装包推过来，预发布开关也就失去意义。这里整体换成一个
              // 指向 Release 页面的外链，用户仍能看到新版说明并自取 IPA 重签。
              if (!PlatformCapabilities.current.supportsAutomaticUpdateCheck)
                ListTile(
                  key: const ValueKey('about-release-page'),
                  leading: const Icon(Icons.system_update),
                  title: Text(context.l10n.settings_releasePage),
                  subtitle: Text(context.l10n.settings_releasePageSubtitle),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => _openUrl(_releasesPageUrl),
                )
              else ...[
                // 检查更新按钮
                FutureBuilder<DateTime?>(
                  future: updateService.getLastCheckTime(),
                  builder: (context, snapshot) {
                    final lastCheckTime = snapshot.data;
                    return ListTile(
                      leading: Badge(
                        isLabelVisible: updateState.hasNewVersion,
                        smallSize: 7,
                        child: const Icon(Icons.system_update),
                      ),
                      title: Text(context.l10n.checkForUpdate),
                      subtitle: Text(
                        updateState.hasDownloadedUpdate
                            ? context.l10n.updateSettingsReady(
                                updateState.versionInfo?.displayVersion ?? '',
                              )
                            : updateState.hasNewVersion
                            ? context.l10n.updateSettingsAvailable(
                                updateState.versionInfo?.displayVersion ?? '',
                              )
                            : _formatLastCheckTime(context, lastCheckTime),
                      ),
                      trailing: updateState.isChecking
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.chevron_right),
                      onTap: updateState.isChecking
                          ? null
                          : () async {
                              if (updateState.hasNewVersion ||
                                  updateState.hasDownloadedUpdate) {
                                updateNotifier.showNotification();
                              } else {
                                await updateNotifier.checkForUpdates(
                                  manual: true,
                                );
                              }
                              if (context.mounted) {
                                await UpdateCheckDialog.show(context);
                              }
                            },
                    );
                  },
                ),
                // 包含预发布版本开关
                FutureBuilder<bool>(
                  future: Future.value(updateService.shouldIncludePrerelease()),
                  builder: (context, snapshot) {
                    final includePrerelease = snapshot.data ?? false;
                    return SwitchListTile(
                      secondary: const Icon(Icons.new_releases_outlined),
                      title: Text(context.l10n.includePrereleaseUpdates),
                      subtitle: Text(
                        context.l10n.includePrereleaseUpdatesDescription,
                      ),
                      value: includePrerelease,
                      onChanged: (value) async {
                        await updateNotifier.setIncludePrerelease(value);
                        if (mounted) {
                          setState(
                            () {},
                          ); // Force widget rebuild to refresh value
                        }
                      },
                    );
                  },
                ),
              ],
            ],
          ),
        ),
        SettingsCard(
          title: context.l10n.settings_aboutResourcesSection,
          child: ListTile(
            leading: const Icon(Icons.code),
            title: Text(context.l10n.settings_openSource),
            subtitle: Text(context.l10n.settings_openSourceSubtitle),
            trailing: const Icon(Icons.open_in_new),
            onTap: () async {
              final uri = Uri.parse(CommunityLinks.github);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ),
      ],
    );
  }

  /// 打开外部链接
  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _exportDiagnosticLogs() async {
    setState(() => _isExportingLogs = true);
    try {
      final result = await ref
          .read(diagnosticLogExportServiceProvider)
          .export(dialogTitle: context.l10n.settings_exportDiagnosticLogs);
      if (!mounted || result.status == DiagnosticLogExportStatus.cancelled) {
        return;
      }
      final message = switch (result.status) {
        DiagnosticLogExportStatus.exported =>
          context.l10n.settings_exportDiagnosticLogsSuccess,
        DiagnosticLogExportStatus.noLogs =>
          context.l10n.settings_exportDiagnosticLogsEmpty,
        DiagnosticLogExportStatus.cancelled => null,
      };
      if (message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } on Object catch (error, stackTrace) {
      AppLogger.e(
        'Failed to export diagnostic logs',
        error,
        stackTrace,
        'Diagnostics',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.settings_exportDiagnosticLogsFailed),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExportingLogs = false);
      }
    }
  }

  /// 格式化上次检查时间
  String _formatLastCheckTime(BuildContext context, DateTime? lastCheckTime) {
    if (lastCheckTime == null) {
      return context.l10n.neverChecked;
    }

    final now = DateTime.now();
    final difference = now.difference(lastCheckTime);

    if (difference.inMinutes < 1) {
      return context.l10n.lastCheckedAt(context.l10n.common_justNow);
    } else if (difference.inHours < 1) {
      return context.l10n.lastCheckedAt(
        context.l10n.common_minutesAgo(difference.inMinutes),
      );
    } else if (difference.inDays < 1) {
      return context.l10n.lastCheckedAt(
        context.l10n.common_hoursAgo(difference.inHours),
      );
    } else {
      return context.l10n.lastCheckedAt(
        context.l10n.common_daysAgo(difference.inDays),
      );
    }
  }
}
