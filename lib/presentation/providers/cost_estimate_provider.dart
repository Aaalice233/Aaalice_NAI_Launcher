import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/services/anlas_calculator.dart';
import '../../data/models/image/image_params.dart';
import 'image_generation_provider.dart';
import 'subscription_provider.dart';

part 'cost_estimate_provider.g.dart';

/// 预估消耗 Provider
///
/// 根据当前参数实时计算预估的 Anlas 消耗
/// 考虑批次数量(nSamples)和每批图片数(imagesPerRequest)
@riverpod
int estimatedCost(Ref ref) {
  final params = ref.watch(generationParamsNotifierProvider);
  final isOpus = ref.watch(isOpusSubscriptionProvider);
  final imagesPerRequest = ref.watch(imagesPerRequestProvider);

  // 总图片数 = nSamples × imagesPerRequest
  final totalImages = params.nSamples * imagesPerRequest;

  if (totalImages <= 0) return 0;

  // 计算总消耗：只有第一张可能享受 Opus 免费
  int totalCost = 0;
  for (int i = 0; i < totalImages; i++) {
    final isFirstImage = i == 0;
    totalCost += AnlasCalculator.calculateFromValues(
      width: params.width,
      height: params.height,
      steps: params.steps,
      nSamples: 1, // 每张单独计算
      smea: params.smea,
      smeaDyn: params.smeaDyn,
      model: params.model,
      isOpus: isOpus && isFirstImage,
      strength: params.action == ImageGenerationAction.img2img
          ? params.strength
          : 1.0,
    );
  }

  // 加上 Vibe 编码成本 (每张非预编码图片 2 Anlas)
  totalCost += params.vibeEncodingCost;

  return totalCost;
}

/// 是否免费生成 Provider
///
/// 只有总消耗为 0 时才是免费
@riverpod
bool isFreeGeneration(Ref ref) {
  final cost = ref.watch(estimatedCostProvider);
  return cost == 0;
}

/// 余额是否不足 Provider
@riverpod
bool isBalanceInsufficient(Ref ref) {
  final balance = ref.watch(anlasBalanceProvider);
  final cost = ref.watch(estimatedCostProvider);

  if (balance == null) return false; // 未加载时不显示警告
  return balance < cost;
}
