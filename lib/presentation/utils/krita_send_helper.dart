import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/krita/krita_outbound_image.dart';
import '../../core/utils/localization_extension.dart';
import '../providers/krita/krita_bridge_notifier.dart';
import '../widgets/common/app_toast.dart';

class KritaSendHelper {
  const KritaSendHelper._();

  static Future<void> sendImageBytes(
    BuildContext context,
    WidgetRef ref,
    Uint8List imageBytes, {
    required String name,
  }) async {
    // 转码期间触发入口可能已卸载，先取应用级 notifier，保证点击即发送。
    final bridge = ref.read(kritaBridgeNotifierProvider.notifier);
    final outboundImage = await _prepareImage(context, imageBytes, name);
    if (outboundImage == null) {
      return;
    }

    final sent = bridge.sendImageToKrita(
      outboundImage.bytes,
      name: outboundImage.name,
    );
    if (!context.mounted) {
      return;
    }
    if (!sent) {
      AppToast.warning(context, context.l10n.toast_kritaNotConnected);
      return;
    }

    AppToast.success(context, context.l10n.toast_sentToKrita);
  }

  static Future<KritaOutboundImage?> _prepareImage(
    BuildContext context,
    Uint8List imageBytes,
    String name,
  ) async {
    try {
      return await KritaOutboundImage.prepareInBackground(
        imageBytes,
        name: name,
      );
    } on FormatException {
      if (context.mounted) {
        AppToast.warning(
          context,
          context.l10n.toast_kritaUnsupportedImageFormat,
        );
      }
      return null;
    }
  }
}
