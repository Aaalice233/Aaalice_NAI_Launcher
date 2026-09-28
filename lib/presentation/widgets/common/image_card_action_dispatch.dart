import '../../../core/utils/app_logger.dart';
import '../../../core/utils/localization_extension.dart';
import 'package:flutter/material.dart';

import 'app_toast.dart';
import 'image_card_action.dart';

/// Capture the overlay before a menu closes or an action removes its own card.
Future<void> dispatchImageCardAction(
  BuildContext context,
  ImageCardAction action,
) => prepareImageCardDispatch(context, action)();

Future<void> Function() prepareImageCardDispatch(
  BuildContext context,
  ImageCardAction action,
) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  final l10n = context.l10n;
  return () async {
    if (!action.canInvoke) return;
    try {
      await action.invoke();
    } catch (error, stackTrace) {
      AppLogger.e(
        'Image card action ${action.id.name} failed',
        error,
        stackTrace,
      );
      if (error is ImageCardBatchException) {
        for (final failure in error.result.failures.values) {
          AppLogger.e(
            'Image card batch member failed',
            failure.error,
            failure.stackTrace,
          );
        }
      }
      final message = error is ImageCardBatchException
          ? l10n.cardAction_batchFailed(
              error.result.failures.length,
              error.result.failures.length + error.result.succeeded.length,
            )
          : l10n.common_error;
      AppToast.errorOnOverlay(
        overlay,
        '$message · ${action.menuLabel}: $error',
      );
    }
  };
}
