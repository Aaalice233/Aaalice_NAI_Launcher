import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_logger.dart';
import '../../../core/utils/nai_metadata_parser.dart';
import '../../../data/models/image/image_params.dart';
import '../../../data/repositories/gallery_folder_repository.dart';
import '../../../data/services/statistics_cache_service.dart';
import '../character_prompt_provider.dart';
import '../image_save_settings_provider.dart';
import '../local_gallery_provider.dart';
import 'generation_models.dart';

/// 自动保存服务（从 ImageGenerationNotifier 提取）
///
/// 负责生成图像的自动保存逻辑，包括元数据嵌入和统计更新。
class GenerationAutoSaveService {
  final Ref _ref;

  GenerationAutoSaveService(this._ref);

  /// 自动保存图像（如果启用）
  Future<void> autoSaveIfEnabled(
    List<GeneratedImage> images,
    ImageParams params,
  ) async {
    final saveSettings = _ref.read(imageSaveSettingsNotifierProvider);
    if (!saveSettings.autoSave) return;

    try {
      final saveDirPath = await GalleryFolderRepository.instance.getRootPath();
      if (saveDirPath == null) return;
      final saveDir = Directory(saveDirPath);
      if (!await saveDir.exists()) {
        await saveDir.create(recursive: true);
      }

      // 使用已解析别名的角色提示词（来自 params.characters）
      final characterConfig = _ref.read(characterPromptNotifierProvider);

      // 构建 V4 多角色提示词结构（直接使用已解析的 params.characters）
      final charCaptions = <Map<String, dynamic>>[];
      final charNegCaptions = <Map<String, dynamic>>[];

      for (final char in params.characters) {
        charCaptions.add({
          'char_caption': char.prompt,
          'centers': [
            {'x': 0.5, 'y': 0.5},
          ],
        });
        charNegCaptions.add({
          'char_caption': char.negativePrompt,
          'centers': [
            {'x': 0.5, 'y': 0.5},
          ],
        });
      }

      int savedCount = 0;
      for (final image in images) {
        try {
          // 从图片元数据中提取实际的 seed
          int actualSeed = params.seed;
          if (params.seed == -1) {
            final extractedMeta =
                await NaiMetadataParser.extractFromBytes(image.bytes);
            if (extractedMeta != null &&
                extractedMeta.seed != null &&
                extractedMeta.seed! > 0) {
              actualSeed = extractedMeta.seed!;
            } else {
              actualSeed = Random().nextInt(4294967295);
            }
          }

          final commentJson = <String, dynamic>{
            'prompt': params.prompt,
            'uc': params.negativePrompt,
            'seed': actualSeed,
            'steps': params.steps,
            'width': params.width,
            'height': params.height,
            'scale': params.scale,
            'uncond_scale': 0.0,
            'cfg_rescale': params.cfgRescale,
            'n_samples': 1,
            'noise_schedule': params.noiseSchedule,
            'sampler': params.sampler,
            'sm': params.smea,
            'sm_dyn': params.smeaDyn,
          };

          if (charCaptions.isNotEmpty) {
            commentJson['v4_prompt'] = {
              'caption': {
                'base_caption': params.prompt,
                'char_captions': charCaptions,
              },
              'use_coords': !characterConfig.globalAiChoice,
              'use_order': true,
            };
            commentJson['v4_negative_prompt'] = {
              'caption': {
                'base_caption': params.negativePrompt,
                'char_captions': charNegCaptions,
              },
              'use_coords': false,
              'use_order': false,
            };
          }

          final metadata = {
            'Description': params.prompt,
            'Software': 'NovelAI',
            'Source': getModelSourceName(params.model),
            'Comment': jsonEncode(commentJson),
          };

          final embeddedBytes = await NaiMetadataParser.embedMetadata(
            image.bytes,
            jsonEncode(metadata),
          );

          final fileName = 'NAI_${DateTime.now().millisecondsSinceEpoch}.png';
          final saveDirPath = await GalleryFolderRepository.instance.getRootPath();
          if (saveDirPath == null) continue;
          final file = File('$saveDirPath/$fileName');
          await file.writeAsBytes(embeddedBytes);
          savedCount++;

          // 避免文件名冲突
          await Future.delayed(const Duration(milliseconds: 2));
        } catch (e) {
          AppLogger.e('自动保存图像失败: $e');
        }
      }

      if (savedCount > 0) {
        // 刷新本地图库
        _ref.read(localGalleryNotifierProvider.notifier).refresh();

        // 增量更新统计缓存，避免下次启动时完全重新计算
        try {
          final cacheService = _ref.read(statisticsCacheServiceProvider);
          await cacheService.incrementImageCount(savedCount);
        } catch (e) {
          AppLogger.w('统计缓存增量更新失败: $e', 'AutoSave');
        }

        AppLogger.d('自动保存完成: $savedCount 张图像', 'AutoSave');
      }
    } catch (e) {
      AppLogger.e('自动保存失败: $e');
    }
  }

  /// 获取模型源名称
  String getModelSourceName(String model) {
    if (model.contains('diffusion-4-5')) {
      return 'NovelAI Diffusion V4.5';
    } else if (model.contains('diffusion-4')) {
      return 'NovelAI Diffusion V4';
    } else if (model.contains('diffusion-3')) {
      return 'NovelAI Diffusion V3';
    }
    return 'NovelAI Diffusion';
  }
}
