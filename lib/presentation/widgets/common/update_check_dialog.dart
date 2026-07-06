import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/localization_extension.dart';
import '../../../data/models/version/version_info.dart';
import '../../providers/update_provider.dart';
import 'app_toast.dart';

/// 更新检查弹窗组件
///
/// 显示更新提示的 UI 组件，支持：
/// - 显示当前版本和最新版本
/// - 使用 flutter_markdown 渲染 Release body（Markdown）
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
      content: SizedBox(width: 480, child: _buildContent(context, state)),
      actions: _buildActions(context, ref, state),
    );
  }

  /// 获取弹窗标题
  String _getTitle(BuildContext context, UpdateState state) {
    return switch (state.status) {
      UpdateStatus.checking => context.l10n.updateChecking,
      UpdateStatus.available => context.l10n.updateAvailable,
      UpdateStatus.downloading => context.l10n.updateDownloading,
      UpdateStatus.installing => context.l10n.updateInstalling,
      UpdateStatus.upToDate => context.l10n.updateUpToDate,
      UpdateStatus.error => context.l10n.updateError,
      UpdateStatus.idle => context.l10n.updateChecking,
    };
  }

  /// 构建弹窗内容
  Widget _buildContent(BuildContext context, UpdateState state) {
    return switch (state.status) {
      UpdateStatus.checking => _buildLoadingContent(context),
      UpdateStatus.available => _buildUpdateAvailableContent(
        context,
        state.versionInfo!,
      ),
      UpdateStatus.downloading => _buildDownloadContent(context, state),
      UpdateStatus.installing => _buildInstallingContent(context),
      UpdateStatus.upToDate => _buildUpToDateContent(context),
      UpdateStatus.error => _buildErrorContent(context, state.errorMessage),
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
                  value: versionInfo.currentVersion ?? '',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildVersionInfoTile(
                  context,
                  label: context.l10n.latestVersion,
                  value: versionInfo.version,
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
          if (versionInfo.releaseNotes != null &&
              versionInfo.releaseNotes!.isNotEmpty) ...[
            Text(
              context.l10n.releaseNotes,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 240),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(
                    alpha: 0.5,
                  ),
                ),
              ),
              child: SingleChildScrollView(
                child: _buildReleaseNotes(versionInfo.releaseNotes!),
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

    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LinearProgressIndicator(value: progress == 0 ? null : progress),
            const SizedBox(height: 16),
            Text(context.l10n.updateDownloadingProgress(percent)),
          ],
        ),
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
  /// 使用简单的文本渲染，因为 flutter_markdown 可能未添加依赖
  /// 如果后续需要完整 Markdown 支持，可以添加 flutter_markdown 包
  Widget _buildReleaseNotes(String releaseNotes) {
    // 简单的 Markdown 渲染
    return SelectableText(
      releaseNotes,
      style: const TextStyle(fontSize: 14, height: 1.6),
    );
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

  /// 构建错误内容
  Widget _buildErrorContent(BuildContext context, String? errorMessage) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              errorMessage ?? context.l10n.updateError,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.error,
              ),
              textAlign: TextAlign.center,
            ),
          ],
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
          onPressed: () {
            // 关闭弹窗，保持状态
            Navigator.of(context).pop();
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
        // 下载并安装 / 前往下载
        FilledButton(
          onPressed: () async {
            final versionInfo = state.versionInfo;
            if (versionInfo?.supportsInAppInstall == true) {
              await ref
                  .read(updateStateProvider.notifier)
                  .downloadAndInstallUpdate();
              return;
            }
            await _openDownloadUrl(context, versionInfo);
            if (context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: Text(
            state.versionInfo?.supportsInAppInstall == true
                ? context.l10n.updateDownloadAndInstall
                : context.l10n.goToDownload,
          ),
        ),
      ],
      UpdateStatus.downloading || UpdateStatus.installing => const [],
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
        FilledButton(
          onPressed: () {
            ref.read(updateStateProvider.notifier).checkForUpdates();
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
