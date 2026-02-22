# 数据库架构重构说明

## 概述

本次重构将原来的单一数据库架构改为分离的预打包数据库架构，解决了 CSV 导入慢、超时等问题。

## 架构变化

### 旧架构
```
单一大数据库 (nai_launcher.db)
├── 画廊数据
├── Danbooru 标签缓存
├── 翻译数据（从 CSV 导入）
└── 共现数据（从 CSV 导入，后台任务）
```

### 新架构
```
assets/databases/          # 预打包数据库（只读）
├── translation.db         # 标签翻译数据
└── cooccurrence.db        # 标签共现关系

databases/                 # 运行时数据库（可写）
└── danbooru.db           # Danbooru API 缓存
```

## 数据库说明

### 1. translation.db（翻译数据库）
- **用途**: 存储标签的中英文翻译
- **来源**: `assets/translations/hf_danbooru_tags.csv`
- **表结构**:
  - `tags`: id, name, type, count
  - `translations`: tag_id, language, translation
- **大小**: ~30-50MB
- **访问方式**: 只读

### 2. cooccurrence.db（共现数据库）
- **用途**: 存储标签共现关系（用于推荐）
- **来源**: `assets/translations/hf_danbooru_cooccurrence.csv`
- **表结构**:
  - `cooccurrences`: tag1, tag2, count, cooccurrence_score
- **大小**: ~50-80MB
- **访问方式**: 只读

### 3. danbooru.db（Danbooru 数据库）
- **用途**: 缓存 Danbooru API 的标签补全数据
- **来源**: 运行时从 Danbooru API 拉取
- **访问方式**: 读写

## 打包工具

### build_databases.dart

位置: `tools/build_databases.dart`

功能:
- 将 CSV 文件打包为优化的 SQLite 数据库
- 创建索引优化查询性能
- 控制数据库大小不超过 100MB

使用方法:
```bash
dart tools/build_databases.dart
```

输出:
- `assets/databases/translation.db`
- `assets/databases/cooccurrence.db`

## 代码变更

### 新增文件

1. `lib/core/database/asset_database_manager.dart`
   - 管理预打包数据库的复制和访问
   - 首次启动时从 assets 复制到应用目录

2. `lib/core/database/data_source_types.dart`
   - 共享的数据源类型定义

3. `tools/build_databases.dart`
   - 数据库打包脚本

### 修改的文件

1. `lib/core/database/database_manager.dart`
   - 初始化资产数据库
   - 重命名主数据库为 danbooru.db

2. `lib/core/database/datasources/translation_data_source.dart`
   - 改为只读访问预打包数据库
   - 移除 CSV 导入逻辑

3. `lib/core/database/datasources/cooccurrence_data_source.dart`
   - 改为只读访问预打包数据库
   - 移除 CSV 导入逻辑

4. `lib/core/database/services/cooccurrence_service.dart`
   - 大幅简化，移除后台导入代码
   - 初始化直接验证数据源可用性

### 移除的功能

1. 共现数据后台导入任务
2. 共现数据导入进度条
3. CSV 解析和批量插入逻辑
4. Checkpoint 断点续传机制

## 性能改进

| 指标 | 旧架构 | 新架构 | 改进 |
|------|--------|--------|------|
| 首次启动时间 | 5-10分钟 | <5秒 | 99%↓ |
| 数据库初始化 | 异步后台任务 | 同步完成 | 即时可用 |
| 内存占用 | 高（批量导入时） | 低 | 稳定 |
| 代码复杂度 | 高 | 低 | 易维护 |

## 部署步骤

1. **开发环境**
   ```bash
   # 1. 打包数据库
   dart tools/build_databases.dart
   
   # 2. 确保数据库文件在 assets/databases/ 目录
   ls assets/databases/
   # 输出: translation.db cooccurrence.db
   
   # 3. 运行应用
   flutter run
   ```

2. **发布版本**
   ```bash
   # 1. 打包数据库
   dart tools/build_databases.dart
   
   # 2. 构建发布版本
   flutter build windows
   # 或 flutter build apk
   ```

## 注意事项

1. **数据库大小**: 每个数据库不超过 100MB
2. **assets 配置**: 确保 `pubspec.yaml` 包含 `assets/databases/` 目录
3. **版本更新**: 当 CSV 数据更新时，需要重新打包数据库
4. **兼容性**: 旧版本用户升级后，原数据库数据仍然保留

## 故障排查

### 数据库文件不存在
检查 `assets/databases/` 目录是否包含 `.db` 文件。

### 数据库损坏
应用会自动检测并从 assets 重新复制。

### 初始化失败
查看日志中的 `AssetDatabaseManager` 和 `DatabaseManager` 标签。
