import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/utils/app_logger.dart';

part 'nai_tags_data_source.g.dart';

/// NAI 官方标签数据
///
/// 从 assets/data/nai_official_tags.json 加载
class NaiTagsData {
  final String version;
  final String source;
  final String lastUpdated;
  final Map<String, List<String>> categories;
  final List<String> hairColorKeywords;

  const NaiTagsData({
    required this.version,
    required this.source,
    required this.lastUpdated,
    required this.categories,
    required this.hairColorKeywords,
  });

  factory NaiTagsData.fromJson(Map<String, dynamic> json) {
    final categoriesRaw = json['categories'] as Map<String, dynamic>;
    final categories = categoriesRaw.map(
      (key, value) => MapEntry(key, List<String>.from(value as List)),
    );

    return NaiTagsData(
      version: json['version'] as String? ?? '1.0.0',
      source: json['source'] as String? ?? '',
      lastUpdated: json['lastUpdated'] as String? ?? '',
      categories: categories,
      hairColorKeywords: List<String>.from(
        json['hairColorKeywords'] as List? ?? [],
      ),
    );
  }

  /// 获取指定类别的标签列表
  List<String> getCategory(String category) {
    return categories[category] ?? [];
  }

  /// 表情标签
  List<String> get expressionTags => getCategory('expression');

  /// 姿势标签
  List<String> get poseTags => getCategory('pose');

  /// 场景标签
  List<String> get sceneTags => getCategory('scene');

  /// 背景标签
  List<String> get backgroundTags => getCategory('background');

  /// 风格标签
  List<String> get styleTags => getCategory('style');

  /// 发色标签
  List<String> get hairColorTags => getCategory('hairColor');

  /// 多色发标签
  List<String> get multicolorHairTags => getCategory('multicolorHair');

  /// 发长标签
  List<String> get hairLengthTags => getCategory('hairLength');

  /// 发型标签
  List<String> get hairStyleTags => getCategory('hairStyle');

  /// 刘海标签
  List<String> get bangsTags => getCategory('bangs');

  /// 扎发标签
  List<String> get hairUpdoTags => getCategory('hairUpdo');

  /// 瞳色标签
  List<String> get eyeColorTags => getCategory('eyeColor');

  /// 眼型标签
  List<String> get eyeStyleTags => getCategory('eyeStyle');

  /// 眼睛变体标签
  List<String> get eyeVariantTags => getCategory('eyeVariant');

  /// 服装标签
  List<String> get clothingTags => getCategory('clothing');

  /// 配饰标签
  List<String> get accessoryTags => getCategory('accessory');

  /// 身体特征标签
  List<String> get bodyFeatureTags => getCategory('bodyFeature');

  /// 种族特征标签
  List<String> get speciesFeatureTags => getCategory('speciesFeature');

  /// 人数标签
  List<String> get characterCountTags => getCategory('characterCount');

  /// 视角/构图标签
  List<String> get cameraTags => getCategory('camera');

  /// 特效标签
  List<String> get effectTags => getCategory('effect');

  /// 物品标签
  List<String> get itemTags => getCategory('items');

  /// 年代标签
  List<String> get yearTags => getCategory('year');

  /// 获取所有类别名称
  List<String> get categoryNames => categories.keys.toList();

  /// 获取总标签数
  int get totalTagCount =>
      categories.values.fold(0, (sum, list) => sum + list.length);

  /// 空数据（fallback）
  static const empty = NaiTagsData(
    version: '0.0.0',
    source: '',
    lastUpdated: '',
    categories: {},
    hairColorKeywords: [],
  );
}

/// NAI 标签数据源
///
/// 负责从 JSON 文件加载标签数据
class NaiTagsDataSource {
  static const String _assetPath = 'assets/data/nai_official_tags.json';

  NaiTagsData? _cachedData;

  /// 加载标签数据
  Future<NaiTagsData> loadData() async {
    if (_cachedData != null) {
      return _cachedData!;
    }

    try {
      AppLogger.d('Loading NAI tags data from $_assetPath', 'NaiTagsData');

      final jsonString = await rootBundle.loadString(_assetPath);
      final jsonData = json.decode(jsonString) as Map<String, dynamic>;
      _cachedData = NaiTagsData.fromJson(jsonData);

      AppLogger.i(
        'Loaded NAI tags data: ${_cachedData!.totalTagCount} tags in ${_cachedData!.categoryNames.length} categories',
        'NaiTagsData',
      );

      return _cachedData!;
    } catch (e, stack) {
      AppLogger.e('Failed to load NAI tags data: $e', 'NaiTagsData', stack);
      return NaiTagsData.empty;
    }
  }

  /// 重新加载（清除缓存）
  Future<NaiTagsData> reload() async {
    _cachedData = null;
    return loadData();
  }

  /// 是否已加载
  bool get isLoaded => _cachedData != null;

  /// 获取缓存的数据（可能为空）
  NaiTagsData? get cachedData => _cachedData;
}

/// Provider: NaiTagsDataSource 单例
@Riverpod(keepAlive: true)
NaiTagsDataSource naiTagsDataSource(Ref ref) {
  return NaiTagsDataSource();
}

/// Provider: NAI 标签数据（异步加载）
@Riverpod(keepAlive: true)
Future<NaiTagsData> naiTagsData(Ref ref) async {
  final dataSource = ref.watch(naiTagsDataSourceProvider);
  return dataSource.loadData();
}
