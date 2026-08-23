import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/update_check_service.dart';
import '../../../core/utils/byte_format.dart';
import '../../../core/utils/in_app_release_notes.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/models/version/version_info.dart';
import '../../providers/queue_execution_provider.dart';
import '../../providers/update_provider.dart';
import 'app_toast.dart';

/// 更新检查弹窗组件
///
/// 显示更新提示的 UI 组件，支持：
/// - 显示当前版本和最新版本
/// - 使用 GitHub Flavored Markdown 完整渲染 Release body
/// - 按钮: [稍后提醒] [忽略此版本] [下载并安装/前往下载]
/// - 加载状态指示器（检查中）
/// - 错误状态显示
class UpdateCheckDialog extends ConsumerWidget {
  const UpdateCheckDialog({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updateStateProvider);

    return AlertDialog(
      title: Text(_getTitle(context, state)),
      content: SizedBox(width: 620, child: _buildContent(context, ref, state)),
      actions: _buildActions(context, ref, state),
    );
  }

  /// 获取弹窗标题
  String _getTitle(BuildContext context, UpdateState state) {
    return switch (state.status) {
      UpdateStatus.checking => context.l10n.updateChecking,
      UpdateStatus.available => context.l10n.updateAvailable,
      UpdateStatus.downloading => context.l10n.updateDownloading,
      UpdateStatus.downloaded => context.l10n.updateDownloaded,
      UpdateStatus.installing => context.l10n.updateInstalling,
      UpdateStatus.upToDate => context.l10n.updateUpToDate,
      UpdateStatus.error =>
        state.downloadedUpdate != null
            ? context.l10n.updateInstallFailed
            : state.versionInfo != null
            ? context.l10n.updateDownloadFailed
            : context.l10n.updateError,
      UpdateStatus.idle => context.l10n.updateChecking,
    };
  }

  /// 构建弹窗内容
  Widget _buildContent(BuildContext context, WidgetRef ref, UpdateState state) {
    return switch (state.status) {
      UpdateStatus.checking => _buildLoadingContent(context),
      UpdateStatus.available => _buildUpdateAvailableContent(
        context,
        state.versionInfo!,
      ),
      UpdateStatus.downloading => _buildDownloadContent(context, state),
      UpdateStatus.downloaded => _buildDownloadedContent(context, ref, state),
      UpdateStatus.installing => _buildInstallingContent(context),
      UpdateStatus.upToDate => _buildUpToDateContent(context),
      UpdateStatus.error => _buildErrorContent(context, state),
      UpdateStatus.idle => _buildLoadingContent(context),
    };
  }

  /// 构建加载状态内容
  Widget _buildLoadingContent(BuildContext context) {
    return const SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [CircularProgressIndicator(), SizedBox(height: 16)],
        ),
      ),
    );
  }

  /// 构建有可用更新内容
  Widget _buildUpdateAvailableContent(
    BuildContext context,
    VersionInfo versionInfo,
  ) {
    final theme = Theme.of(context);
    final releaseNotes = extractInAppReleaseNotes(
      versionInfo.releaseNotes ?? '',
    );
    final releaseNotesBackground = theme.colorScheme.surfaceContainerLowest;
    final releaseNotesForeground = _readableForeground(releaseNotesBackground);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 版本信息
          Row(
            children: [
              Expanded(
                child: _buildVersionInfoTile(
                  context,
                  label: context.l10n.currentVersion,
                  value: versionInfo.displayCurrentVersion,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildVersionInfoTile(
                  context,
                  label: context.l10n.latestVersion,
                  value: versionInfo.displayVersion,
                  isHighlighted: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (versionInfo.primaryAsset != null) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                versionInfo.supportsInAppInstall
                    ? Icons.system_update_alt
                    : Icons.open_in_new,
              ),
              title: Text(
                versionInfo.primaryAsset!.label ?? context.l10n.common_download,
              ),
              subtitle: Text(
                versionInfo.primaryAsset!.description ??
                    context.l10n.updatePortableManualHint,
              ),
            ),
            const SizedBox(height: 8),
          ],
          // 更新日志
          if (releaseNotes.isNotEmpty) ...[
            Text(
              context.l10n.releaseNotes,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 380),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: releaseNotesBackground,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
              child: SingleChildScrollView(
                child: _buildReleaseNotes(
                  context,
                  versionInfo,
                  releaseNotes,
                  backgroundColor: releaseNotesBackground,
                  foregroundColor: releaseNotesForeground,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建下载进度内容
  Widget _buildDownloadContent(BuildContext context, UpdateState state) {
    final progress = state.downloadProgress.clamp(0.0, 1.0);
    final percent = (progress * 100).round();
    final theme = Theme.of(context);

    return SizedBox(
      height: 140,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LinearProgressIndicator(value: progress == 0 ? null : progress),
            const SizedBox(height: 16),
            Text(context.l10n.updateDownloadingProgress(percent)),
            if (state.totalBytes > 0) ...[
              const SizedBox(height: 6),
              Text(
                context.l10n.updateDownloadSizeSpeed(
                  formatBytes(state.downloadedBytes),
                  formatBytes(state.totalBytes),
                  formatBytesPerSecond(state.downloadSpeedBytesPerSecond),
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 构建下载完成、等待安装确认的内容
  Widget _buildDownloadedContent(
    BuildContext context,
    WidgetRef ref,
    UpdateState state,
  ) {
    final theme = Theme.of(context);
    final queueState = ref.watch(queueExecutionNotifierProvider);
    final hasActiveQueue = queueState.isRunning || queueState.isPaused;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 48,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 14),
          Text(
            context.l10n.updateDownloadedHint(
              state.versionInfo?.displayVersion ?? '',
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (hasActiveQueue) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 20,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.updateActiveTasksWarning,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// 构建安装器启动内容
  Widget _buildInstallingContent(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(context.l10n.updateInstallingHint),
          ],
        ),
      ),
    );
  }

  /// 构建版本信息卡片
  Widget _buildVersionInfoTile(
    BuildContext context, {
    required String label,
    required String value,
    bool isHighlighted = false,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isHighlighted
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isHighlighted
              ? theme.colorScheme.primary.withValues(alpha: 0.3)
              : theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'v$value',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isHighlighted ? theme.colorScheme.primary : null,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建发布说明内容
  ///
  /// 完整渲染 GitHub Flavored Markdown：标题、嵌套列表、任务列表、
  /// 表格、引用、分隔线、删除线、行内/围栏代码、链接与远程图片。
  Widget _buildReleaseNotes(
    BuildContext context,
    VersionInfo versionInfo,
    String releaseNotes, {
    required Color backgroundColor,
    required Color foregroundColor,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final versionTag = versionInfo.displayVersion.startsWith('v')
        ? versionInfo.displayVersion
        : 'v${versionInfo.displayVersion}';
    final rawContentBase = Uri.parse(
      'https://raw.githubusercontent.com/Aaalice233/'
      'Aaalice_NAI_Launcher/$versionTag/',
    );
    final codeBackground = colorScheme.surfaceContainerHighest;
    final codeForeground = _readableForeground(codeBackground);
    final quoteBackground = colorScheme.surfaceContainerHigh;
    final quoteForeground = _readableForeground(quoteBackground);
    final linkColor = _ensureContrast(
      colorScheme.primary,
      backgroundColor,
      foregroundColor,
    );

    return MarkdownBody(
      data: releaseNotes,
      selectable: true,
      extensionSet: md.ExtensionSet.gitHubWeb,
      imageDirectory: rawContentBase.toString(),
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: theme.textTheme.bodyMedium?.copyWith(
          color: foregroundColor,
          height: 1.55,
        ),
        a: theme.textTheme.bodyMedium?.copyWith(
          color: linkColor,
          decoration: TextDecoration.underline,
          decorationColor: linkColor.withValues(alpha: 0.55),
        ),
        h1: theme.textTheme.titleLarge?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
        h2: theme.textTheme.titleMedium?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
        h3: theme.textTheme.titleSmall?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
          height: 1.4,
        ),
        h4: theme.textTheme.bodyLarge?.copyWith(color: foregroundColor),
        h5: theme.textTheme.bodyLarge?.copyWith(color: foregroundColor),
        h6: theme.textTheme.bodyLarge?.copyWith(color: foregroundColor),
        h1Padding: const EdgeInsets.only(top: 10, bottom: 6),
        h2Padding: const EdgeInsets.only(top: 9, bottom: 5),
        h3Padding: const EdgeInsets.only(top: 7, bottom: 4),
        blockSpacing: 10,
        listIndent: 22,
        listBullet: theme.textTheme.bodyMedium?.copyWith(
          color: foregroundColor,
        ),
        blockquote: theme.textTheme.bodyMedium?.copyWith(
          color: quoteForeground,
        ),
        code: theme.textTheme.bodySmall?.copyWith(
          fontFamily: 'monospace',
          color: codeForeground,
          backgroundColor: codeBackground,
        ),
        codeblockPadding: const EdgeInsets.all(12),
        codeblockDecoration: BoxDecoration(
          color: codeBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        blockquotePadding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
        blockquoteDecoration: BoxDecoration(
          color: quoteBackground,
          borderRadius: BorderRadius.circular(6),
          border: Border(
            left: BorderSide(color: colorScheme.primary, width: 3),
          ),
        ),
        tableHead: theme.textTheme.bodyMedium?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w700,
        ),
        tableBody: theme.textTheme.bodyMedium?.copyWith(color: foregroundColor),
        tableBorder: TableBorder.all(color: colorScheme.outlineVariant),
        tableCellsPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 7,
        ),
        tableScrollbarThumbVisibility: true,
        horizontalRuleDecoration: BoxDecoration(
          border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        ),
      ),
      onTapLink: (text, href, title) async {
        if (href == null || href.isEmpty || href.startsWith('#')) return;
        final uri = _resolveReleaseUri(href, versionTag);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else if (context.mounted) {
          AppToast.error(context, context.l10n.cannotOpenUrl);
        }
      },
    );
  }

  Color _readableForeground(Color background) {
    return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : Colors.black;
  }

  Color _ensureContrast(Color candidate, Color background, Color fallback) {
    final lighter = candidate.computeLuminance() > background.computeLuminance()
        ? candidate.computeLuminance()
        : background.computeLuminance();
    final darker = candidate.computeLuminance() > background.computeLuminance()
        ? background.computeLuminance()
        : candidate.computeLuminance();
    return (lighter + 0.05) / (darker + 0.05) >= 4.5 ? candidate : fallback;
  }

  Uri? _resolveReleaseUri(String href, String versionTag) {
    final uri = Uri.tryParse(href);
    if (uri == null) return null;
    if (uri.hasScheme) {
      return const {'http', 'https', 'mailto'}.contains(uri.scheme)
          ? uri
          : null;
    }
    return Uri.parse(
      'https://github.com/Aaalice233/Aaalice_NAI_Launcher/blob/'
      '$versionTag/',
    ).resolveUri(uri);
  }

  /// 构建已是最新内容
  Widget _buildUpToDateContent(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.updateUpToDate,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 构建错误内容。内部异常只写日志，弹窗始终显示简短、可执行的文案。
  Widget _buildErrorContent(BuildContext context, UpdateState state) {
    final theme = Theme.of(context);
    final message = switch (state.checkFailureType) {
      UpdateCheckFailureType.releaseNotFound =>
        context.l10n.updateErrorReleaseNotReady,
      UpdateCheckFailureType.rateLimited => context.l10n.updateErrorServerBusy,
      UpdateCheckFailureType.network => context.l10n.updateErrorNetwork,
      UpdateCheckFailureType.unavailable =>
        context.l10n.updateErrorServiceUnavailable,
      UpdateCheckFailureType.invalidResponse =>
        context.l10n.updateErrorInvalidMetadata,
      UpdateCheckFailureType.unknown ||
      null => state.errorMessage ?? context.l10n.updateErrorUnknown,
    };

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 120, maxHeight: 220),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 48,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建按钮操作
  List<Widget> _buildActions(
    BuildContext context,
    WidgetRef ref,
    UpdateState state,
  ) {
    return switch (state.status) {
      UpdateStatus.checking => [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.common_cancel),
        ),
      ],
      UpdateStatus.available => [
        // 稍后提醒
        TextButton(
          onPressed: () async {
            await ref.read(updateStateProvider.notifier).remindLater();
            if (context.mounted) Navigator.of(context).pop();
          },
          child: Text(context.l10n.remindMeLater),
        ),
        // 忽略此版本
        TextButton(
          onPressed: () async {
            await ref.read(updateStateProvider.notifier).skipUpdate();
            if (context.mounted) {
              AppToast.info(context, context.l10n.versionSkipped);
              Navigator.of(context).pop();
            }
          },
          child: Text(context.l10n.skipThisVersion),
        ),
        OutlinedButton.icon(
          onPressed: () => _openReleasePage(context, state.versionInfo),
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: Text(context.l10n.viewReleasePage),
        ),
        // 下载并安装 / 前往下载
        FilledButton(
          onPressed: () async {
            final versionInfo = state.versionInfo;
            if (versionInfo?.supportsInAppInstall == true) {
              await ref.read(updateStateProvider.notifier).downloadUpdate();
              return;
            }
            await _openDownloadUrl(context, versionInfo);
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Text(
            state.versionInfo?.supportsInAppInstall == true
                ? context.l10n.updateDownload
                : context.l10n.goToDownload,
          ),
        ),
      ],
      UpdateStatus.downloading => [
        TextButton(
          onPressed: () {
            ref.read(updateStateProvider.notifier).cancelDownload();
            AppToast.info(context, context.l10n.updateDownloadCancelled);
          },
          child: Text(context.l10n.common_cancel),
        ),
      ],
      UpdateStatus.downloaded => [
        TextButton(
          onPressed: () async {
            await ref.read(updateStateProvider.notifier).remindLater();
            if (context.mounted) Navigator.of(context).pop();
          },
          child: Text(context.l10n.updateInstallLater),
        ),
        FilledButton(
          onPressed: () => _confirmInstall(context, ref),
          child: Text(context.l10n.updateInstallAndRestart),
        ),
      ],
      UpdateStatus.installing => const [],
      UpdateStatus.upToDate => [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.common_ok),
        ),
      ],
      UpdateStatus.error => [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.common_close),
        ),
        // 下载失败时提供浏览器手动下载的退路
        if (state.versionInfo != null)
          TextButton(
            onPressed: () => _openDownloadUrl(context, state.versionInfo),
            child: Text(context.l10n.goToDownload),
          ),
        FilledButton(
          onPressed: () {
            final notifier = ref.read(updateStateProvider.notifier);
            // 已有版本信息说明是下载/安装阶段出错，直接重试下载；
            // 否则重新走检查更新流程。
            if (state.downloadedUpdate != null) {
              _confirmInstall(context, ref);
            } else if (state.versionInfo != null &&
                state.versionInfo!.supportsInAppInstall) {
              notifier.downloadUpdate();
            } else {
              notifier.checkForUpdates(manual: true);
            }
          },
          child: Text(context.l10n.common_retry),
        ),
      ],
      UpdateStatus.idle => [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.common_cancel),
        ),
      ],
    };
  }

  Future<void> _confirmInstall(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.updateInstallConfirmationTitle),
        content: Text(context.l10n.updateInstallConfirmationBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.common_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.updateInstallAndRestart),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await ref.read(updateStateProvider.notifier).installDownloadedUpdate();
    }
  }

  Future<void> _openReleasePage(
    BuildContext context,
    VersionInfo? versionInfo,
  ) async {
    final url = versionInfo?.htmlUrl;
    if (url == null || url.isEmpty) return;

    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      AppToast.error(context, context.l10n.cannotOpenUrl);
    }
  }

  Future<void> _openDownloadUrl(
    BuildContext context,
    VersionInfo? versionInfo,
  ) async {
    final url = versionInfo?.downloadUrl ?? versionInfo?.htmlUrl;
    if (url == null) return;

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      AppToast.error(context, context.l10n.cannotOpenUrl);
    }
  }

  /// 显示更新检查弹窗
  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const UpdateCheckDialog(),
    );
  }
}
