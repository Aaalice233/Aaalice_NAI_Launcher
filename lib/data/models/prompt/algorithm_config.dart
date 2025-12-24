import 'package:freezed_annotation/freezed_annotation.dart';

part 'algorithm_config.freezed.dart';
part 'algorithm_config.g.dart';

/// 随机算法配置
///
/// 控制随机提示词生成的各项参数
@freezed
class AlgorithmConfig with _$AlgorithmConfig {
  const AlgorithmConfig._();

  const factory AlgorithmConfig({
    /// 角色数量权重分布
    /// 格式: [[count, weight], ...]
    /// 默认值来自 NAI 官网: [[1,70], [2,20], [3,7], [0,5]]
    @Default([
      [1, 70], // 1人 70%
      [2, 20], // 2人 20%
      [3, 7],  // 3人 7%
      [0, 5],  // 无人 5%
    ])
    List<List<int>> characterCountWeights,

    /// 是否启用权重随机偏移（随机添加括号）
    @Default(false) bool bracketRandomizationEnabled,

    /// 权重随机偏移最小层数
    @Default(0) int bracketRandomizationMin,

    /// 权重随机偏移最大层数
    @Default(2) int bracketRandomizationMax,

    /// 括号类型：true = {} 增强，false = [] 减弱
    @Default(true) bool bracketEnhance,

    /// V4 模型模式（支持多角色）
    @Default(true) bool isV4Model,

    /// Furry 性别权重分布
    /// 键: 'm' = 男性, 'f' = 女性, 'o' = 其他
    @Default({'m': 45, 'f': 45, 'o': 10})
    Map<String, int> furryGenderWeights,
  }) = _AlgorithmConfig;

  factory AlgorithmConfig.fromJson(Map<String, dynamic> json) =>
      _$AlgorithmConfigFromJson(json);

  /// NAI 官网默认配置
  static const AlgorithmConfig naiDefault = AlgorithmConfig();

  /// 获取角色数量权重的显示文本
  String get characterCountDisplayText {
    final buffer = StringBuffer();
    for (final weight in characterCountWeights) {
      final count = weight[0];
      final percent = weight[1];
      final label = count == 0 ? '无人' : '$count人';
      if (buffer.isNotEmpty) buffer.write(', ');
      buffer.write('$label $percent%');
    }
    return buffer.toString();
  }

  /// 获取指定角色数量的权重百分比
  int getWeightForCount(int count) {
    for (final weight in characterCountWeights) {
      if (weight[0] == count) {
        return weight[1];
      }
    }
    return 0;
  }

  /// 更新指定角色数量的权重
  AlgorithmConfig updateWeightForCount(int count, int newWeight) {
    final newWeights = characterCountWeights.map((w) {
      if (w[0] == count) {
        return [count, newWeight];
      }
      return w;
    }).toList();
    return copyWith(characterCountWeights: newWeights);
  }

  /// 计算总权重
  int get totalWeight {
    return characterCountWeights.fold(0, (sum, w) => sum + w[1]);
  }

  /// 归一化权重（使总和为100）
  AlgorithmConfig normalizeWeights() {
    final total = totalWeight;
    if (total == 0 || total == 100) return this;

    final newWeights = characterCountWeights.map((w) {
      final normalized = (w[1] * 100 / total).round();
      return [w[0], normalized];
    }).toList();

    return copyWith(characterCountWeights: newWeights);
  }
}

/// 类别概率配置
///
/// 存储每个类别被选中的概率
@freezed
class CategoryProbabilityConfig with _$CategoryProbabilityConfig {
  const CategoryProbabilityConfig._();

  const factory CategoryProbabilityConfig({
    /// 发色选取概率
    @Default(0.8) double hairColor,

    /// 瞳色选取概率
    @Default(0.8) double eyeColor,

    /// 发型选取概率
    @Default(0.5) double hairStyle,

    /// 表情选取概率
    @Default(0.6) double expression,

    /// 姿势选取概率
    @Default(0.5) double pose,

    /// 服装选取概率
    @Default(0.7) double clothing,

    /// 配饰选取概率
    @Default(0.5) double accessory,

    /// 身体特征选取概率
    @Default(0.3) double bodyFeature,

    /// 背景选取概率
    @Default(0.9) double background,

    /// 场景选取概率
    @Default(0.5) double scene,

    /// 风格选取概率
    @Default(0.3) double style,
  }) = _CategoryProbabilityConfig;

  factory CategoryProbabilityConfig.fromJson(Map<String, dynamic> json) =>
      _$CategoryProbabilityConfigFromJson(json);

  /// NAI 官网默认配置
  static const CategoryProbabilityConfig naiDefault =
      CategoryProbabilityConfig();

  /// 获取指定类别的概率
  double getProbability(String categoryName) {
    return switch (categoryName) {
      'hairColor' => hairColor,
      'eyeColor' => eyeColor,
      'hairStyle' => hairStyle,
      'expression' => expression,
      'pose' => pose,
      'clothing' => clothing,
      'accessory' => accessory,
      'bodyFeature' => bodyFeature,
      'background' => background,
      'scene' => scene,
      'style' => style,
      _ => 0.5,
    };
  }

  /// 更新指定类别的概率
  CategoryProbabilityConfig updateProbability(
    String categoryName,
    double newProbability,
  ) {
    return switch (categoryName) {
      'hairColor' => copyWith(hairColor: newProbability),
      'eyeColor' => copyWith(eyeColor: newProbability),
      'hairStyle' => copyWith(hairStyle: newProbability),
      'expression' => copyWith(expression: newProbability),
      'pose' => copyWith(pose: newProbability),
      'clothing' => copyWith(clothing: newProbability),
      'accessory' => copyWith(accessory: newProbability),
      'bodyFeature' => copyWith(bodyFeature: newProbability),
      'background' => copyWith(background: newProbability),
      'scene' => copyWith(scene: newProbability),
      'style' => copyWith(style: newProbability),
      _ => this,
    };
  }

  /// 转换为 Map 格式（用于 UI 显示）
  Map<String, double> toMap() {
    return {
      'hairColor': hairColor,
      'eyeColor': eyeColor,
      'hairStyle': hairStyle,
      'expression': expression,
      'pose': pose,
      'clothing': clothing,
      'accessory': accessory,
      'bodyFeature': bodyFeature,
      'background': background,
      'scene': scene,
      'style': style,
    };
  }
}
