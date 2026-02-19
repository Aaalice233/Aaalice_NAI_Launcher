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
///
/// 计费逻辑：
/// - nSamples（批次数量）：应用内循环，每次是独立请求，每次都可享受 Opus 免费
/// - imagesPerRequest（批次大小）：单次请求生成多张，只有第一张免费
@riverpod
int estimatedCost(Ref ref) {
  final params = ref.watch(generationParamsNotifierProvider);
  final imagesPerRequest = ref.watch(imagesPerRequestProvider);
  
  // 使用 select 来减少不必要的重建 - 只关注 isOpus 的变化
  final isOpus = ref.watch(
    subscriptionNotifierProvider.select((s) => s.isOpus),
  );

  // nSamples = 批次数量（应用内循环次数，每次独立请求）
  // imagesPerRequest = 批次大小（单次请求的图片数）
  final batchCount = params.nSamples;
  final batchSize = imagesPerRequest;

  if (batchCount <= 0 || batchSize <= 0) return 0;

  // 计算单次请求的消耗
  // 单次请求内：只有第一张可能享受 Opus 免费
  int singleRequestCost = 0;
  for (int i = 0; i < batchSize; i++) {
    final isFirstImageInRequest = i == 0;
    singleRequestCost += AnlasCalculator.calculateFromValues(
      width: params.width,
      height: params.height,
      steps: params.steps,
      nSamples: 1,
      smea: params.smea,
      smeaDyn: params.smeaDyn,
      model: params.model,
      isOpus: isOpus && isFirstImageInRequest,
      strength: params.action == ImageGenerationAction.img2img
          ? params.strength
          : 1.0,
    );
  }

  // 总消耗 = 单次请求消耗 × 批次数量
  // 每次独立请求都可享受 Opus 免费（如果符合条件）
  final totalCost = singleRequestCost * batchCount;

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
