# 随机词库数据维护

随机词库与自动补全词库是两条独立功能链。运行时词条来自随包的完整
`assets/databases/tag_catalog.db`，`assets/data/random_tag_library.json` 只保存可审查的
声明式语义分类规则，不保存 NovelAI 网站的随机词表、脚本、权重或依赖数据。

## 数据链

1. `tool/tag_catalog/source_lock.json` 固定完整 catalog 的来源、commit、SHA-256 和计数。
2. `assets/data/random_tag_library.json` 记录 catalog 分类、glob 与 token 规则。
3. `RandomTagLibraryDataSource` 启动时核对 catalog metadata，再用 SQL 按规则建立内存索引。
4. `detail` 分类保留 catalog 中全部可用于画面描述的 general/species 条目；其他分类是重叠的语义索引，不会从完整候选集中删除条目。
5. `source_lock.json` 固定 taxonomy 哈希、完整 catalog 计数和每个语义分类的解析计数。

运行时不会访问 NovelAI 网站，也不需要把完整 SQLite 内容复制成另一份 JSON。分类查询按
`post_count DESC, name ASC` 保持确定顺序，生成器在首次使用每个池时建立累计权重索引，避免每次抽取重新扫描权重。

## 修改 taxonomy

先编辑 `assets/data/random_tag_library.json`，再运行：

```powershell
dart run tool/random_tag_library/build_random_tag_library.dart
dart run tool/random_tag_library/verify_random_tag_library.dart
```

`build_random_tag_library.dart` 只重新计算聚合计数与锁文件哈希，不输出候选标签。
提交前必须检查分类数量是否符合预期；新增分类不得为空，也不得通过截断或预过滤来规避性能问题。

## NovelAI 行为参考

`analyze_nai_random_prompt.dart` 仅用于维护者对本地、未提交的 NovelAI 前端副本做聚合行为核对：

```powershell
dart run tool/random_tag_library/analyze_nai_random_prompt.dart "<local 1741-*.js path>"
```

工具只输出文件哈希、数组数和聚合条目数，不输出候选词、精确权重、依赖表或网站源码。
仓库实现只复现可观察的高层行为：分阶段生成、主提示词稳定去重、角色槽位隔离、条件规则与加权抽取。
