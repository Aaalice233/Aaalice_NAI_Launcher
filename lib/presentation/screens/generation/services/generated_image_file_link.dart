import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../../providers/image_generation_provider.dart';
import 'generation_result_saver.dart';
import 'generation_save_service.dart';

/// 需要一个真实文件的操作（收藏、定位文件夹）共用的保存入口。
///
/// 与其他保存入口同一套落盘：已在当前图库里就复用原文件，删除历史时也能连带删除它。
class GeneratedImageFileLink {
  const GeneratedImageFileLink._();

  static Future<GenerationResultFile> ensureSaved(
    WidgetRef ref,
    GeneratedImage image,
    AppLocalizations l10n,
  ) async {
    final saver = GenerationSaveService.saverFor(ref);
    final file = await saver.save(GenerationSaveService.requestFor(ref, image));
    if (file == null) throw StateError(l10n.localGallery_saveDirectoryNotSet);
    return file;
  }
}
