import 'package:flutter/widgets.dart';

import '../../../core/services/update_check_service.dart';
import '../../../core/services/update_installer_service.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../l10n/app_localizations.dart';
import '../../providers/update_provider.dart';

/// 更新错误状态的本地化文案；安装类失败优先，附带更新脚本日志位置。
String describeUpdateError(BuildContext context, UpdateState state) {
  final l10n = context.l10n;
  final installFailure = state.installFailure;
  if (installFailure == null) {
    return _checkFailureText(l10n, state.checkFailureType);
  }
  final text = _installFailureText(l10n, installFailure);
  final logPath = state.errorLogPath;
  return logPath == null ? text : '$text\n${l10n.updateInstallLogPath(logPath)}';
}

String _checkFailureText(
  AppLocalizations l10n,
  UpdateCheckFailureType? failure,
) => switch (failure) {
  UpdateCheckFailureType.releaseNotFound => l10n.updateErrorReleaseNotReady,
  UpdateCheckFailureType.rateLimited => l10n.updateErrorServerBusy,
  UpdateCheckFailureType.network => l10n.updateErrorNetwork,
  UpdateCheckFailureType.unavailable => l10n.updateErrorServiceUnavailable,
  UpdateCheckFailureType.invalidResponse => l10n.updateErrorInvalidMetadata,
  UpdateCheckFailureType.unknown || null => l10n.updateErrorUnknown,
};

String _installFailureText(
  AppLocalizations l10n,
  UpdateInstallFailure failure,
) => switch (failure) {
  UpdateInstallFailure.unsupported => l10n.updatePortableManualHint,
  UpdateInstallFailure.packageNotFound =>
    l10n.updateInstallErrorPackageNotFound,
  UpdateInstallFailure.incompleteMetadata =>
    l10n.updateInstallErrorIncompleteMetadata,
  UpdateInstallFailure.network => l10n.updateErrorNetwork,
  UpdateInstallFailure.diskFull => l10n.updateInstallErrorDiskFull,
  UpdateInstallFailure.fileSystem => l10n.updateInstallErrorFileSystem,
  UpdateInstallFailure.verificationFailed =>
    l10n.updateInstallErrorVerificationFailed,
  UpdateInstallFailure.resumeRejected => l10n.updateInstallErrorResumeRejected,
  UpdateInstallFailure.emptyResponse => l10n.updateInstallErrorEmptyResponse,
  UpdateInstallFailure.downloadFailed => l10n.updateInstallErrorDownloadFailed,
  UpdateInstallFailure.packageMissing => l10n.updateInstallErrorPackageMissing,
  UpdateInstallFailure.packageCorrupted =>
    l10n.updateInstallErrorPackageCorrupted,
  UpdateInstallFailure.invalidAndroidPackage =>
    l10n.updateInstallErrorInvalidAndroidPackage,
  UpdateInstallFailure.androidInstallerUnavailable =>
    l10n.updateInstallErrorAndroidInstaller,
  UpdateInstallFailure.updaterLaunchFailed =>
    l10n.updateInstallErrorUpdaterLaunchFailed,
  UpdateInstallFailure.updaterNotStarted =>
    l10n.updateInstallErrorUpdaterNotStarted,
  UpdateInstallFailure.installFailed => l10n.updateInstallErrorInstallFailed,
  UpdateInstallFailure.installInterrupted => l10n.updateInstallErrorInterrupted,
  UpdateInstallFailure.unknown => l10n.updateInstallErrorUnknown,
};
