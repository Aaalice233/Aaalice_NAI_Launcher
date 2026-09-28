import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/image_share_sanitizer.dart';
import '../../core/watermark/watermark_render_service.dart';
import 'share_image_settings_provider.dart';
import 'watermark_settings_provider.dart';

/// A snapshot of the saved watermark, independent of the metadata policy.
final copyDragWatermarkProvider = Provider<ShareImageTransform?>((ref) {
  final enabled = ref.watch(
    shareImageSettingsProvider.select((s) => s.watermarkForCopyAndDrag),
  );
  if (!enabled) return null;

  final state = ref.watch(watermarkSettingsProvider);
  final logoService = ref.watch(watermarkLogoServiceProvider);
  final cacheKey = sha256
      .convert(
        utf8.encode(
          jsonEncode([
            state.configuration.encode(),
            state.localLogoPath,
            state.loadIssue?.name,
          ]),
        ),
      )
      .toString();

  return ShareImageTransform(
    cacheKey: cacheKey,
    apply: (image, {required stripMetadata}) async {
      if (state.loadIssue != null) {
        throw const WatermarkRenderException(
          'The saved watermark settings cannot be loaded. Save the defaults again.',
        );
      }
      final logoPath = state.localLogoPath;
      final logo = state.configuration.logoStyle.enabled
          ? await logoService.readValidated(logoPath ?? '')
          : null;
      final result = await WatermarkRenderService.render(
        WatermarkRenderRequest(
          sourceBytes: image.bytes,
          sourceFileName: image.fileName,
          settings: state.configuration,
          logoBytes: logo,
          // The editor's own preservation setting must not override sharing.
          preserveMetadata: !stripMetadata,
        ),
      );
      return SanitizedShareImage(
        bytes: result.bytes,
        fileName: result.fileName,
        mimeType: 'image/png',
      );
    },
  );
});
