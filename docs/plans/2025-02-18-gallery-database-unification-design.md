# 本地画廊数据库整合设计文档

**日期**: 2025-02-18
**方案**: 方案A - 完全整合
**目标**: 将画廊数据库整合到统一数据库，建立完整缓存机制，优化启动性能

---

## 1. 现状分析

### 1.1 当前架构问题

```
当前状态:
┌─────────────────────────────────────────────────────────────┐
│                      NAI Launcher                           │
├──────────────────────────┬──────────────────────────────────┤
│   统一数据库 (V2)         │   画廊数据库 (独立)               │
│   nai_launcher.db        │   nai_gallery.db                 │
│                          │                                  │
│   ├─ translations        │   ├─ images                      │
│   ├─ danbooru_tags       │   ├─ metadata                    │
│   ├─ cooccurrences       │   ├─ favorites                   │
│   └─ db_metadata         │   ├─ tags                        │
│                          │   ├─ image_tags                  │
│   ConnectionPool (3)     │   ├─ folders                     │
│   预热阶段初始化          │   ├─ scan_history                │
│                          │   └─ metadata_fts                │
│                          │                                  │
│                          │   GalleryDatabaseService         │
│                          │   单连接 + 自定义缓存              │
│                          │   首次进入页面时才初始化           │
└──────────────────────────┴──────────────────────────────────┘
```

**核心问题**:
1. **启动卡顿**: 画廊数据库在首次进入页面时才初始化，大量图片时阻塞UI
2. **代码冗余**: 两套数据库管理体系，重复代码
3. **资源浪费**: 两个数据库连接，独立的缓存机制
4. **死代码**: GalleryDatabaseService 与 DataSource 架构重复

### 1.2 需要保留的数据表

| 表名 | 用途 | 记录数预估 | 优先级 |
|------|------|-----------|--------|
| `images` | 图片基础信息 | 用户文件数 | 必需 |
| `metadata` | 生成元数据 | 用户文件数 | 必需 |
| `favorites` | 收藏状态 | 少于图片数 | 必需 |
| `tags` | 用户标签 | 数千 | 必需 |
| `image_tags` | 图片-标签关联 | 数万 | 必需 |
| `scan_history` | 扫描历史 | 数百 | 低 |
| `metadata_fts` | 全文搜索 | 虚拟表 | 必需 |

---

## 2. 目标架构

### 2.1 整合后架构

```
目标状态:
┌─────────────────────────────────────────────────────────────┐
│                      NAI Launcher                           │
│                                                             │
│              统一数据库 (V3) - nai_launcher.db               │
│                                                             │
│   ┌─────────────────────────────────────────────────────┐  │
│   │            现有数据源 (不变)                          │  │
│   │   translations, danbooru_tags, cooccurrences       │  │
│   └─────────────────────────────────────────────────────┘  │
│                                                             │
│   ┌─────────────────────────────────────────────────────┐  │
│   │            新增: GalleryDataSource                  │  │
│   │                                                     │  │
│   │   ├─ gallery_images      (原 images)               │  │
│   │   ├─ gallery_metadata    (原 metadata)             │  │
│   │   ├─ gallery_favorites   (原 favorites)            │  │
│   │   ├─ gallery_tags        (原 tags)                 │  │
│   │   ├─ gallery_image_tags  (原 image_tags)           │  │
│   │   ├─ gallery_scan_logs   (原 scan_history)         │  │
│   │   └─ gallery_fts_index   (原 metadata_fts)         │  │
│   │                                                     │  │
│   │   - 继承 BaseDataSource                             │  │
│   │   - 使用 ConnectionPool                            │  │
│   │   - 统一缓存机制 (LRU)                              │  │
│   │   - 预热阶段初始化                                  │  │
│   └─────────────────────────────────────────────────────┘  │
│                                                             │
│   ConnectionPoolHolder (共享连接池)                        │
│   所有数据源统一初始化                                      │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 缓存架构

```
三级缓存策略:
┌────────────────────────────────────────────────────────────┐
│                      GalleryDataSource                     │
├────────────────────────────────────────────────────────────┤
│  L1 - 内存LRU缓存 (热数据)                                  │
│  ├─ 图片记录缓存: 1000条                                    │
│  ├─ 元数据缓存: 500条                                       │
│  └─ 收藏状态缓存: 全部 (数据量小)                           │
├────────────────────────────────────────────────────────────┤
│  L2 - 统一数据库 (温数据)                                   │
│  └─ SQLite + WAL模式                                       │
├────────────────────────────────────────────────────────────┤
│  L3 - 文件系统 (冷数据)                                     │
│  └─ 原始图片文件 + 提取的Vibe数据                           │
└────────────────────────────────────────────────────────────┘
```

---

## 3. 详细设计

### 3.1 新增组件

#### 3.1.1 GalleryDataSource

```dart
/// 画廊数据源
/// 管理本地图片索引和元数据
class GalleryDataSource extends BaseDataSource {
  // 缓存
  final LRUCache<int, GalleryImageRecord> _imageCache;
  final LRUCache<int, GalleryMetadata> _metadataCache;
  final Set<int> _favoriteCache; // 收藏ID集合

  // 表名
  static const String _tableImages = 'gallery_images';
  static const String _tableMetadata = 'gallery_metadata';
  static const String _tableFavorites = 'gallery_favorites';
  static const String _tableTags = 'gallery_tags';
  static const String _tableImageTags = 'gallery_image_tags';
  static const String _tableScanLogs = 'gallery_scan_logs';
  static const String _tableFts = 'gallery_fts_index';

  // 核心操作
  Future<List<GalleryImageRecord>> queryImages({...});
  Future<GalleryMetadata?> getMetadata(int imageId);
  Future<void> indexImage(File file, NaiImageMetadata metadata);
  Future<void> batchIndex(List<ImageIndexTask> tasks);
  Future<List<GalleryImageRecord>> search(String query);
}
```

#### 3.1.2 GalleryService

```dart
/// 画廊服务
/// 面向UI的高级接口
class GalleryService {
  final GalleryDataSource _dataSource;
  final GalleryFileWatcher _fileWatcher;
  final GalleryCacheManager _cacheManager;

  // 分页查询
  Future<PagedResult<GalleryImageRecord>> getImages(int page, int pageSize);

  // 搜索
  Future<SearchResult> search(String query, {FilterOptions? filters});

  // 索引管理
  Future<ScanResult> performIncrementalScan();
  Future<ScanResult> performFullScan();

  // 收藏
  Future<void> toggleFavorite(int imageId);
  Future<List<GalleryImageRecord>> getFavorites();
}
```

### 3.2 数据模型调整

#### 3.2.1 现有模型复用

复用现有模型，增加统一ID字段：

```dart
/// 画廊图片记录 (扩展现有 LocalImageRecord)
class GalleryImageRecord {
  final int id;                    // 数据库主键 (新增)
  final String filePath;           // 文件路径 (唯一)
  final String fileName;
  final int fileSize;
  final String? fileHash;
  final int? width;
  final int? height;
  final double? aspectRatio;
  final DateTime createdAt;
  final DateTime modifiedAt;
  final DateTime indexedAt;
  final bool isDeleted;
  final int? dateYmd;
  final String? resolutionKey;

  // 关联数据
  final GalleryMetadata? metadata;
  final bool isFavorite;
  final List<String> tags;
}
```

### 3.3 数据迁移策略

```
迁移流程:
1. 检测旧数据库是否存在
   └─ 是 → 执行迁移
   └─ 否 → 创建新表，完成

2. 迁移步骤 (事务保护)
   a. 读取旧数据库所有记录
   b. 批量插入新数据库
   c. 验证数据完整性
   d. 删除旧数据库文件

3. 回滚策略
   - 迁移失败保留旧数据库
   - 下次启动重试
   - 记录迁移状态到 db_metadata
```

### 3.4 预热阶段集成

```dart
// warmup_provider.dart 中注册
void _registerQuickPhaseTasks() {
  // ... 现有任务 ...

  // 新增: 画廊数据源初始化
  _scheduler.registerTask(
    PhasedWarmupTask(
      name: 'warmup_galleryDataSource',
      displayName: '初始化画廊索引',
      phase: WarmupPhase.quick,
      weight: 3, // 权重较高，因为可能耗时
      timeout: const Duration(seconds: 30),
      task: _initGalleryDataSource,
    ),
  );
}

Future<void> _initGalleryDataSource() async {
  final dataSource = await ref.watch(galleryDataSourceProvider.future);

  // 快速检测文件变化
  final dir = await _getImageDirectory();
  final needProcessing = await dataSource.detectChanges(dir);

  if (needProcessing > 1000) {
    // 大量文件后台处理
    AppLogger.i('画廊索引: $needProcessing 个文件待处理，将在后台完成');
    _scheduleBackgroundScan();
  } else if (needProcessing > 0) {
    // 少量文件立即处理
    await dataSource.quickSync(dir);
  }
}
```

---

## 4. 需要删除的死代码

### 4.1 完全删除的文件

```
lib/
├── data/
│   ├── services/
│   │   └── gallery/
│   │       ├── gallery_database_service.dart      [DELETE]
│   │       ├── gallery_database_schema.dart       [DELETE]
│   │       ├── gallery_migration_service.dart     [DELETE - 功能合并到DataSource]
│   │       └── gallery_cache_service.dart         [DELETE - 使用统一缓存]
│   └── repositories/
│       ├── local_gallery_repository.dart          [DELETE - 替换为GalleryService]
│       └── gallery_repository.dart                [DELETE - 与上面合并]
│
├── core/
│   └── database/
│       └── migrations/
│           ├── v1_initial_schema.dart             [DELETE - 画廊相关]
│           └── v2_remove_foreign_keys.dart        [DELETE - 画廊相关]
```

### 4.2 需要修改的文件

```
lib/
├── presentation/
│   └── providers/
│       ├── local_gallery_provider.dart            [MAJOR - 使用新DataSource]
│       └── warmup_provider.dart                   [ADD - 注册画廊初始化]
│
├── core/
│   └── database/
│       ├── database_manager.dart                  [ADD - 注册GalleryDataSource]
│       └── services/
│           └── service_providers.dart             [ADD - GalleryService provider]
```

---

## 5. 实施步骤

### Phase 1: 基础架构 (2-3天)
1. 创建 `GalleryDataSource` 类
2. 在统一数据库中创建画廊表
3. 实现基础 CRUD 操作
4. 集成到 `DatabaseManager`

### Phase 2: 数据迁移 (1-2天)
1. 实现迁移逻辑
2. 添加迁移状态追踪
3. 测试迁移流程

### Phase 3: 服务层 (2天)
1. 创建 `GalleryService`
2. 实现搜索和过滤
3. 实现扫描和索引

### Phase 4: UI集成 (2天)
1. 重写 `LocalGalleryNotifier`
2. 更新 `warmup_provider`
3. 测试所有画廊功能

### Phase 5: 清理 (1天)
1. 删除所有旧代码
2. 清理无用导入
3. 运行完整测试

---

## 6. 风险评估

| 风险 | 可能性 | 影响 | 缓解措施 |
|------|--------|------|----------|
| 数据迁移失败 | 中 | 高 | 保留旧数据库，可回滚 |
| 性能下降 | 低 | 中 | 保持连接池，优化缓存 |
| 功能回归 | 中 | 中 | 完整测试所有画廊功能 |
| 代码冲突 | 高 | 低 | 分阶段提交，频繁同步 |

---

## 7. 成功标准

- [ ] 画廊数据完全迁移到统一数据库
- [ ] 预热阶段完成画廊初始化（不阻塞UI）
- [ ] 所有旧数据库相关代码已删除
- [ ] 无功能回归
- [ ] 性能不低于原有实现

---

**设计者**: Claude Code
**审核状态**: 待审核
**实施状态**: 待开始
