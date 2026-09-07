import 'package:flutter/widgets.dart';

import '../../core/utils/localization_extension.dart';
import '../../core/utils/zip_utils.dart';
import '../../l10n/app_localizations.dart';
import '../widgets/common/app_toast.dart';

class ZipExportProgress {
  ZipExportProgress(BuildContext context, int count)
    : _l10n = context.l10n,
      controller = AppToast.showProgress(
        context,
        context.l10n.localGallery_packingImages(count),
      );

  final AppLocalizations _l10n;
  final ToastController controller;

  void update(ZipCreationProgress progress) => controller.updateProgress(
    progress.fraction,
    message: _l10n.localGallery_packingProgress(
      progress.current,
      progress.total,
    ),
    subtitle: progress.currentFileName,
  );
}
