import 'package:flutter/widgets.dart';

import '../../core/utils/inpaint_mask_utils.dart';
import '../../core/utils/localization_extension.dart';
import '../providers/generation/generation_error_classifier.dart';
import '../providers/prompt_config_provider.dart';

/// 无法识别的消息以“生成失败”为标题、原文为提示。
(String, String?) describeGenerationError(
  BuildContext context,
  String? message,
) {
  if (message == null || message.isEmpty) {
    return (context.l10n.generation_generationFailed, null);
  }
  return _tryDescribeGenerationError(context, message) ??
      (context.l10n.generation_generationFailed, message);
}

/// 无法识别的消息原样返回。
String summarizeGenerationError(BuildContext context, String message) {
  final described = _tryDescribeGenerationError(context, message);
  if (described == null) return message;
  final (title, hint) = described;
  return hint == null ? title : '$title\n$hint';
}

(String, String?)? _tryDescribeGenerationError(
  BuildContext context,
  String message,
) {
  final l10n = context.l10n;
  if (isStreamingGenerationUnsupportedError(message)) {
    return (
      l10n.generation_streamingUnsupported,
      l10n.generation_streamingUnsupportedHint,
    );
  }

  if (message == 'Cancelled') {
    return (l10n.generation_cancelGeneration, null);
  }

  if (EmptyInpaintMaskException.matches(message)) {
    return (
      l10n.generation_emptyInpaintMask,
      l10n.generation_emptyInpaintMaskHint(novelAiLatentGridSize),
    );
  }

  final parts = message.split('|');
  final errorCode = parts[0];
  final details = parts.length > 1 ? parts[1] : null;

  switch (errorCode) {
    case 'AUTH_REQUIRED':
      return (l10n.settings_notLoggedIn, l10n.settings_goToLoginPage);
    case UnsupportedRandomPromptModelException.errorCode:
      return (
        l10n.randomPrompt_unsupportedModel,
        l10n.randomPrompt_unsupportedModelHint,
      );
    case 'GENERATION_ERROR_INVALID_RESOLUTION':
      if (parts.length >= 5) {
        final width = int.tryParse(parts[1]);
        final height = int.tryParse(parts[2]);
        final suggestedWidth = int.tryParse(parts[3]);
        final suggestedHeight = int.tryParse(parts[4]);
        if (width != null &&
            height != null &&
            suggestedWidth != null &&
            suggestedHeight != null) {
          return (
            l10n.generation_invalidResolution,
            l10n.generation_invalidResolutionHint(
              width,
              height,
              suggestedWidth,
              suggestedHeight,
            ),
          );
        }
      }
      return (l10n.generation_invalidResolution, message);
    case 'API_ERROR_429':
      return (l10n.api_error_429, l10n.api_error_429_hint);
    case 'API_ERROR_401':
      return (l10n.api_error_401, l10n.api_error_401_hint);
    case 'API_ERROR_402':
      return (l10n.api_error_402, l10n.api_error_402_hint);
    case 'API_ERROR_400':
      return ('${l10n.common_error} (400)', details);
    case 'API_ERROR_500':
      return (l10n.api_error_500, l10n.api_error_500_hint);
    case 'API_ERROR_503':
      return (l10n.api_error_503, l10n.api_error_503_hint);
    case 'API_ERROR_TIMEOUT':
      return (l10n.api_error_timeout, l10n.api_error_timeout_hint);
    case 'API_ERROR_NETWORK':
      return (l10n.api_error_network, l10n.api_error_network_hint);
    default:
      if (errorCode.startsWith('API_ERROR_HTTP_')) {
        final code = errorCode.replaceFirst('API_ERROR_HTTP_', '');
        return ('${l10n.common_error} (HTTP $code)', details);
      }
      return null;
  }
}
