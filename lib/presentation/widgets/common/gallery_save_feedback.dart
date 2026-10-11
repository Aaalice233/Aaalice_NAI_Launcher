import 'package:flutter/widgets.dart';

import '../../../core/services/system_gallery_publisher.dart';
import '../../../core/utils/localization_extension.dart';
import 'app_toast.dart';

/// 图片已写入启动器图库后，按系统相册发布结果给出统一提示。
///
/// [appGalleryMessage] 用于不支持系统相册的平台，通常带上保存目录。
void showGallerySaveFeedback(
  BuildContext context,
  SystemGalleryPublishOutcome outcome, {
  required String appGalleryMessage,
}) {
  final l10n = context.l10n;
  switch (outcome) {
    case SystemGalleryPublished():
      AppToast.success(context, l10n.image_savedToSystemGallery);
    case SystemGallerySyncDisabled():
      AppToast.success(context, l10n.image_savedToAppGallery);
    case SystemGalleryUnsupported():
      AppToast.success(context, appGalleryMessage);
    case SystemGalleryPublishFailed(:final error):
      AppToast.warning(context, l10n.image_savedAppOnly(error.toString()));
  }
}
