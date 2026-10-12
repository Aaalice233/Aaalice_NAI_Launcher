import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/api_constants.dart';
import '../../../../../core/save_naming/save_name_context.dart';
import '../../../../../core/utils/app_logger.dart';
import '../../../../../data/models/gallery/nai_image_metadata.dart';
import '../../../../../data/services/image_metadata_service.dart';
import '../../../../providers/image_generation_provider.dart';

/// 命名规则预览所用的图片字段。
class SaveNamingPreviewSample {
  const SaveNamingPreviewSample(this.context, {required this.fromLatestImage});

  /// 内置样例，时间取 [now]。
  factory SaveNamingPreviewSample.builtIn(DateTime now) =>
      SaveNamingPreviewSample(
        SaveNameContext(
          createdAt: now,
          imageId: '7d3c2a9e-5b41-4f6a-9c1e-2f8b6d4a1e03',
          index: 0,
          width: 832,
          height: 1216,
          metadata: const NaiImageMetadata(
            prompt:
                '1girl, solo, silver hair, blue eyes, school uniform, '
                'cherry blossoms, petals, looking at viewer',
            seed: 1234567890,
            model: ImageModels.animeDiffusionV45Full,
            width: 832,
            height: 1216,
            characterPrompts: ['1girl, hatsune miku, twintails'],
          ),
        ),
        fromLatestImage: false,
      );

  final SaveNameContext context;
  final bool fromLatestImage;
}

/// 优先取最近一张可保存的生成图，读不到元数据时用内置样例。
final saveNamingPreviewSampleProvider =
    FutureProvider.autoDispose<SaveNamingPreviewSample>((ref) async {
      // 只读一次：生成进度会频繁刷新状态，预览不需要跟着重新解析。
      final latest = ref
          .read(imageGenerationNotifierProvider)
          .history
          .where((image) => image.canSave)
          .firstOrNull;
      if (latest == null) {
        return SaveNamingPreviewSample.builtIn(DateTime.now());
      }
      NaiImageMetadata? metadata = latest.metadata;
      if (metadata == null) {
        try {
          metadata = await ImageMetadataService().getMetadataFromBytes(
            latest.bytes,
          );
        } catch (error, stack) {
          AppLogger.e(
            'Failed to read metadata for save naming preview',
            error,
            stack,
            'SaveNamingPreview',
          );
        }
      }
      if (metadata == null) {
        return SaveNamingPreviewSample.builtIn(DateTime.now());
      }
      return SaveNamingPreviewSample(
        SaveNameContext(
          createdAt: latest.createdAt,
          metadata: metadata,
          imageId: latest.id,
          index: 0,
          width: latest.width,
          height: latest.height,
        ),
        fromLatestImage: true,
      );
    });
