import 'package:flutter/widgets.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';

import '../../../core/utils/localization_extension.dart';
import '../../providers/replication_queue_provider.dart';
import '../common/app_toast.dart';

String? enqueueFailureMessage(AppLocalizations l10n, EnqueueResult result) {
  if (result.outcome == EnqueueOutcome.saved) return null;
  final started = result.startedTaskIds.length;
  final withdrawn = result.withdrawnTaskIds.length;
  return [
    if (started > 0)
      withdrawn > 0
          ? l10n.queue_enqueueStartedAndWithdrawn(started, withdrawn)
          : l10n.queue_enqueueStartedUnsaved(started)
    else if (withdrawn > 0)
      l10n.queue_enqueueWithdrawn(withdrawn),
    if (result.queuedTaskIds.isNotEmpty)
      l10n.queue_enqueueQueued(result.queuedTaskIds.length),
    if (result.failedTaskIds.isNotEmpty)
      l10n.queue_enqueueFailedBeforeSaved(result.failedTaskIds.length),
    if (result.removedTaskIds.isNotEmpty)
      l10n.queue_enqueueRemoved(result.removedTaskIds.length),
    if (!result.indexSaved) l10n.queue_enqueueIndexUnsaved,
  ].join('\n');
}

/// 保存失败时提示并返回 true；全部写进索引（含队列已满）时返回 false，交给调用方提示。
bool showEnqueueFailureToast(
  BuildContext context,
  EnqueueResult result, {
  List<String> extraLines = const [],
}) {
  final message = enqueueFailureMessage(context.l10n, result);
  if (message == null) return false;
  final text = [message, ...extraLines].join('\n');
  if (result.outcome == EnqueueOutcome.startedBeforeSaved ||
      result.queuedTaskIds.isNotEmpty) {
    AppToast.warning(context, text);
  } else {
    AppToast.error(context, text);
  }
  return true;
}

void showEnqueueResultToast(
  BuildContext context,
  EnqueueResult result, {
  required String successMessage,
}) {
  if (showEnqueueFailureToast(context, result)) return;
  if (result.accepted == 0) {
    AppToast.warning(context, context.l10n.onlineGallery_queueFullMax);
    return;
  }
  AppToast.success(context, successMessage);
}

/// 入队抛出意外错误时的提示，不带异常原文。
void showEnqueueErrorToast(BuildContext context) =>
    AppToast.error(context, context.l10n.queue_enqueueUnexpectedError);
