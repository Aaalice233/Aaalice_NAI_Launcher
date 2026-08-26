# 随机词库数据维护

随机提示词使用两条彼此独立、可组合的数据链：

- **官网来源**：`assets/data/nai_official_random_wordlists.json`。由锁定的 NovelAI
  前端 bundle 确定性提取，供“官网”模式使用。
- **Catalog 扩展来源**：`assets/databases/tag_catalog.db` +
  `assets/data/random_tag_library.json`。供“自定义”模式配置 preset，并在“混合”模式中扩展官网结果。

“混合”模式必须同时执行当前模型对应的官网 recipe 与 catalog preset；不得把 catalog
伪装成官网词库，也不得用官网资产替代可配置的 catalog 扩展。

## 官网词库数据链

当前锁定 bundle 为 `1741-909f971ef51889d8.js.下载`：

- SHA-256：`e832224acd91d2aec14c9ebd705423b4b909a957a48121d847fe5fe3311317d8`
- 大小：`1,404,190` bytes
- 原始数组：`118`
- 原始记录：`5,960`
  - Legacy Anime：`1,865`
  - Furry V3：`1,639`
  - Character Prompts：`2,456`

构建器逐数组保存原始顺序、重复记录、权重以及全部尾部字段，不去重、不归一化、不截断。
运行时按模型能力注册表分派：Legacy 模型使用 Legacy Anime，Furry V3 使用 Furry V3，
V4/V4.5/V5 Full 与 Curated 都使用 Character Prompts。V5 没有独立随机词表。

`tool/random_tag_library/source_lock.json` 同时固定来源文件、来源 SHA-256、输出 SHA-256、
三个 generator 计数及每个原始数组的计数。随包资产只包含数据，不包含 NovelAI 前端脚本。

### 重建官网资产

NovelAI 前端 bundle 是本地输入，不提交仓库。拿到与 lock 完全一致的文件后运行：

```powershell
dart run tool/random_tag_library/analyze_nai_random_prompt.dart "<local 1741-*.js path>"
dart run tool/random_tag_library/build_random_tag_library.dart "<local 1741-*.js path>"
dart run tool/random_tag_library/verify_random_tag_library.dart --source "<local 1741-*.js path>"
```

构建会先核对文件名、大小、SHA-256 和三个 generator 总数，再写入资产与 lock；最后一条命令会
从同一 bundle 再构建一次并逐字节比较，证明输出确定。普通 CI 或没有本地 bundle 时运行：

```powershell
dart run tool/random_tag_library/verify_random_tag_library.dart
```

它仍会核对已提交资产的输出哈希、来源元数据、118 个数组的顺序与计数、5,960 条记录的结构。

升级 NovelAI 来源时，先用分析工具获取新事实并人工核对 generator/数组映射及生成函数；确认后再
显式更新 `referenceAnalysis`。不得只替换资产或为了通过校验修改期望计数。

## Catalog 扩展数据链

1. `tool/tag_catalog/source_lock.json` 固定完整 catalog 的来源、commit、SHA-256 和计数。
2. `assets/data/random_tag_library.json` 记录 catalog 分类、glob 与 token 规则。
3. `RandomTagLibraryDataSource` 启动时核对 catalog metadata，再用 SQL 按规则建立内存索引。
4. `detail` 分类保留 catalog 中全部可用于画面描述的 general/species 条目；其他分类是重叠的语义索引，不会从完整候选集中删除条目。
5. `source_lock.json` 固定 taxonomy 哈希、完整 catalog 计数和每个语义分类的解析计数。

分类查询按 `post_count DESC, name ASC` 保持确定顺序；生成器在首次使用每个池时建立累计权重索引，
避免每次抽取重新扫描权重。修改 taxonomy 后运行：

```powershell
dart run tool/random_tag_library/build_random_tag_library.dart
dart run tool/random_tag_library/verify_random_tag_library.dart
```

不传 bundle 时，构建命令只刷新 catalog taxonomy 计数与哈希，不改官网资产。新增分类不得为空，
也不得通过截断或预过滤规避性能问题。
