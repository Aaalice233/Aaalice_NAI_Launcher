import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import '../../../core/utils/localization_extension.dart';
import '../../../data/services/discord_share_service.dart';

String discordShareErrorText(
  BuildContext context,
  Object error, {
  int retrySeconds = 0,
}) {
  if (error is DioException) {
    return switch (error.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => context.l10n.discordShare_errorNetwork,
      _ => context.l10n.discordShare_errorRelay,
    };
  }
  if (error is! DiscordShareException) {
    return context.l10n.discordShare_errorRelay;
  }
  return switch (error.code) {
    'browser_unavailable' => context.l10n.discordShare_errorBrowser,
    'timeout' => context.l10n.discordShare_errorTimeout,
    'share_in_progress' => context.l10n.discordShare_sending,
    'rate_limited' =>
      retrySeconds > 0
          ? context.l10n.discordShare_errorRateLimitedRetry(retrySeconds)
          : context.l10n.discordShare_errorRateLimited,
    'no_targets' ||
    'invalid_targets' => context.l10n.discordShare_errorNoChannels,
    'unauthorized' ||
    'session_expired' ||
    'invalid_oauth_request' ||
    'invalid_oauth_state' ||
    'invalid_oauth_result_request' ||
    'invalid_oauth_verifier' => context.l10n.discordShare_errorSession,
    'relay_misconfigured' ||
    'rate_limiter_unavailable' => context.l10n.discordShare_errorRelay,
    'image_upload_rejected' ||
    'invalid_image' => context.l10n.discordShare_errorImageRejected,
    'webhook_failed' ||
    'partial_delivery' => context.l10n.discordShare_errorDelivery,
    'network_error' => context.l10n.discordShare_errorNetwork,
    _ => context.l10n.discordShare_errorRelay,
  };
}
