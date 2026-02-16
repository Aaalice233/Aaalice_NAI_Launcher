import 'dart:math';

import '../../models/prompt/category_filter_config.dart';
import '../../models/prompt/random_prompt_result.dart';
import '../../models/prompt/tag_library.dart';

/// 提示词生成策略抽象基类
///
/// 定义所有随机提示词生成策略的通用接口和契约。
/// 子类需要实现具体的生成逻辑，支持不同的生成模式（NAI官网风格、自定义等）。
///
/// ## 使用场景
///
/// - NAI 官网风格生成（[NaiStyleGeneratorStrategy]）
/// - 用户自定义预设生成
/// - 混合模式生成
///
/// ## 实现指南
///
/// 子类需要：
/// 1. 实现 [generate] 方法提供具体的生成逻辑
/// 2. 支持通过 [TagLibrary] 获取标签数据
/// 3. 使用 [Random] 进行确定性随机（支持种子）
/// 4. 遵守 [CategoryFilterConfig] 的过滤配置
/// 5. 返回 [RandomPromptResult] 格式的结果
///
/// ## 示例实现
///
/// ```dart
/// class MyCustomStrategy implements PromptGenerationStrategy {
///   @override
///   Future<RandomPromptResult> generate({
///     required TagLibrary library,
///     required Random random,
///     required CategoryFilterConfig filterConfig,
///     int? seed,
///   }) async {
///     // 自定义生成逻辑
///     return RandomPromptResult(
///       mainPrompt: 'generated prompt',
///       seed: seed,
///       mode: RandomGenerationMode.custom,
///     );
///   }
/// }
/// ```
abstract interface class PromptGenerationStrategy {
  /// 生成随机提示词
  ///
  /// [library] 标签词库，包含按类别分组的带权重标签
  /// [random] 随机数生成器，用于确定性随机（支持种子复现）
  /// [filterConfig] 分类级 Danbooru 补充配置，控制各分类的启用状态
  /// [seed] 随机种子（可选，用于结果追踪和复现）
  ///
  /// 返回 [RandomPromptResult] 包含：
  /// - [mainPrompt]: 主提示词（背景、场景、风格等）
  /// - [characters]: 角色列表（V4+ 模式）
  /// - [noHumans]: 是否为无人物场景
  /// - [seed]: 使用的随机种子
  /// - [mode]: 生成模式
  ///
  /// 示例：
  /// ```dart
  /// final strategy = NaiStyleGeneratorStrategy();
  /// final library = await _libraryService.getAvailableLibrary();
  ///
  /// final result = await strategy.generate(
  ///   library: library,
  ///   random: Random(42),
  ///   filterConfig: CategoryFilterConfig(),
  ///   seed: 42,
  /// );
  ///
  /// print(result.mainPrompt);
  /// print(result.characters);
  /// ```
  ///
  /// 异常：
  /// - 当 [library] 为空或无效时，应抛出 [ArgumentError]
  /// - 当生成过程中发生错误时，应抛出相应的异常
  Future<RandomPromptResult> generate({
    required TagLibrary library,
    required Random random,
    required CategoryFilterConfig filterConfig,
    int? seed,
  });
}
