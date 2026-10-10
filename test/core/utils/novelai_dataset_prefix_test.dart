import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/constants/model_capabilities.dart';
import 'package:nai_launcher/core/enums/image_model_mode.dart';
import 'package:nai_launcher/core/utils/novelai_dataset_prefix.dart';

void main() {
  const v5 = ModelCapabilityRegistry.v5Full;
  const v3 = ModelCapabilityRegistry.v3;

  group('NovelAiDatasetPrefix.apply', () {
    test('Furry 模式在提示词最前面补 fur dataset', () {
      expect(
        NovelAiDatasetPrefix.apply(
          '1girl, very aesthetic',
          mode: ImageModelMode.furry,
          capabilities: v5,
        ),
        'fur dataset, 1girl, very aesthetic',
      );
    });

    test('Anime 模式与没有 Furry 模式的模型保持原样', () {
      expect(
        NovelAiDatasetPrefix.apply(
          '1girl',
          mode: ImageModelMode.anime,
          capabilities: v5,
        ),
        '1girl',
      );
      expect(
        NovelAiDatasetPrefix.apply(
          '1girl',
          mode: ImageModelMode.furry,
          capabilities: v3,
        ),
        '1girl',
      );
    });

    test('已手写任一数据集标签时不重复补', () {
      for (final prompt in [
        'fur dataset, wolf',
        'fur dataset',
        'background dataset, forest',
      ]) {
        expect(
          NovelAiDatasetPrefix.apply(
            prompt,
            mode: ImageModelMode.furry,
            capabilities: v5,
          ),
          prompt,
        );
      }
    });

    test('与官网一样只看原文开头，前导空白不算手写标签', () {
      expect(
        NovelAiDatasetPrefix.apply(
          ' fur dataset, wolf',
          mode: ImageModelMode.furry,
          capabilities: v5,
        ),
        'fur dataset,  fur dataset, wolf',
      );
    });
  });

  group('NovelAiDatasetPrefix.strip', () {
    test('剥离完整前缀并识别为 Furry', () {
      final result = NovelAiDatasetPrefix.strip(
        'fur dataset, wolf, very aesthetic',
        capabilities: v5,
      );
      expect(result.prompt, 'wolf, very aesthetic');
      expect(result.mode, ImageModelMode.furry);
    });

    test('没有前缀时识别为 Anime，缺逗号空格的写法不剥离', () {
      final anime = NovelAiDatasetPrefix.strip('wolf', capabilities: v5);
      expect(anime.prompt, 'wolf');
      expect(anime.mode, ImageModelMode.anime);

      final bare = NovelAiDatasetPrefix.strip(
        'fur dataset,wolf',
        capabilities: v5,
      );
      expect(bare.prompt, 'fur dataset,wolf');
      expect(bare.mode, ImageModelMode.anime);
    });

    test('只剥离一次，与官网 replace(/^fur dataset, /g) 一致', () {
      final result = NovelAiDatasetPrefix.strip(
        'fur dataset, fur dataset, wolf',
        capabilities: v5,
      );
      expect(result.prompt, 'fur dataset, wolf');
    });

    test('没有 Furry 模式的模型不剥离也不判定模式', () {
      final result = NovelAiDatasetPrefix.strip(
        'fur dataset, wolf',
        capabilities: v3,
      );
      expect(result.prompt, 'fur dataset, wolf');
      expect(result.mode, isNull);
    });

    test('apply 与 strip 往返还原', () {
      const prompt = 'wolf, forest';
      final applied = NovelAiDatasetPrefix.apply(
        prompt,
        mode: ImageModelMode.furry,
        capabilities: v5,
      );
      expect(
        NovelAiDatasetPrefix.strip(applied, capabilities: v5).prompt,
        prompt,
      );
    });
  });
}
