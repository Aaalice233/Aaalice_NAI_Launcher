# Danbooru 分类级过滤控制

## 任务目标

将 Danbooru 补充控制从全局开关改为分类级开关：
1. 同步操作始终获取所有 Danbooru 补充数据
2. 每个分类独立控制是否使用 Danbooru 补充词
3. UI：分类条目添加单独开关，列表顶部添加总开关
4. 移除原有全局开关

## 执行步骤

1. [x] 创建 CategoryFilterConfig 模型
2. [ ] 扩展 Danbooru 补充分类（所有分类）
3. [ ] 更新 TagLibraryService 存储
4. [ ] 更新 TagLibraryProvider
5. [ ] 移除 SyncConfig 的 enableDanbooruSupplement
6. [ ] 更新 UI - 分类列表
7. [ ] 更新 TagLibrary 过滤逻辑
8. [ ] 更新 RandomPromptGenerator
9. [ ] 更新调用方
10. [ ] 运行 build_runner 和 analyze

## 关键改动

- 新模型：`CategoryFilterConfig`
- 存储 key：`category_filter_config`
- 默认值：所有分类关闭
