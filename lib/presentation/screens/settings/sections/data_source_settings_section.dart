import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../widgets/data_source_cache_settings.dart';

/// 数据源设置板块
///
/// 管理 Danbooru 标签数据缓存，包括：
/// - 标签补全数据同步设置
/// - 热度阈值配置
/// - 自动刷新间隔设置
/// - 缓存清除功能
///
/// 注意：DataSourceCacheSettings 已有自己的卡片样式，不需要额外包裹 SettingsCard
class DataSourceSettingsSection extends ConsumerStatefulWidget {
  const DataSourceSettingsSection({super.key});

  @override
  ConsumerState<DataSourceSettingsSection> createState() =>
      _DataSourceSettingsSectionState();
}

class _DataSourceSettingsSectionState
    extends ConsumerState<DataSourceSettingsSection> {
  @override
  Widget build(BuildContext context) {
    // DataSourceCacheSettings 已有自己的卡片容器样式
    // 不需要使用 SettingsCard 包装，避免双重卡片
    return const DataSourceCacheSettings();
  }
}
