# 标签目录数据库

`build_tag_catalog.dart` 将两类锁定数据合并为唯一内置数据库
`assets/databases/tag_catalog.db`：

- `source_lock.json` 固定完整 Danbooru/e621 英文标签来源。
- `zh_translations.json` 保存经过清洗和复核的简体中文补充翻译。

中文翻译只有两种模式：

- `override`：确认过的 ffdkj 错译，查询时优先于 ffdkj。
- `missing`：ffdkj 基线中缺失的翻译，查询时排在 ffdkj 后面。

这种顺序允许 ffdkj 后续新增或改善普通翻译，同时持续修正确认过的错译。
原始研究报告和 CSV 不参与客户端构建，也不得放入 `assets/`。

运行时统一通过 `FastTagService` 使用这些数据。它同时提供中英文标签补全和批量翻译，
调用方不需要感知内置数据库、ffdkj 或两种补充模式。提示词助手再通过
`LocalFirstPromptTranslationPipeline` 先消费本地结果，只把未命中的规范化标签分批交给
AI，并按原有权重、强调和分隔语法合并结果。

## 更新翻译

1. 清洗并复核候选项，更新 `zh_translations.json`。每个 `tag` 只能出现一次，
   `zhCn` 只能包含一个推荐译文。
2. 更新 `source_lock.json` 中翻译源的 SHA-256、数量和 ffdkj 基线 blob SHA。
3. 根据英文源 SHA-256 与翻译源 SHA-256 计算新的 12 位 `dataVersion`。
4. 获取锁定的英文 CSV 后构建并验证：

```powershell
dart run tool/tag_catalog/build_tag_catalog.dart
dart run tool/tag_catalog/verify_bundled_databases.dart
```

数据库版本变化后，必须把新数据库发布为独立的
`autocomplete-data-tag-catalog-<dataVersion 前 8 位>-vN` prerelease，随后把固定
下载地址、大小和 SHA-256 写入 `assets/databases/manifest.json`。数据 Release 不得设为
latest。
