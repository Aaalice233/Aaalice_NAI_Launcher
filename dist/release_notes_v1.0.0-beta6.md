## 🎉 NAI Launcher v1.0.0-beta6 更新日志

本次版本重点优化了在线画廊筛选体验，并集中修复了本地画廊拖拽预览问题。

### ✨ 新功能
- 🏷️ 在线画廊新增「多选评级筛选」能力，可更细粒度地组合筛选结果。
- 🗂️ 本地画廊新增「按分类路径过滤」能力，查找图片更高效。
- 🖱️ 本地画廊支持图像卡片拖拽（持续完善交互与稳定性）。

### 🚀 体验优化
- 🧱 调整拖拽卡片布局与视觉样式：更紧凑、信息更清晰。
- 👀 优化拖拽提示与内部/外部拖拽区分逻辑。
- 🔍 在线画廊请求与结果处理流程优化，筛选反馈更一致。

### 🐛 问题修复
- ✅ 修复「首次拖拽无预览图」相关问题（多轮修复与稳定化）。
- ✅ 修复图像卡片拖拽中的占位符、边角缝隙、留白等显示异常。
- ✅ 修复全屏快捷键空格冲突问题。
- ✅ 修复若干 info 级别告警，降低潜在维护风险。

### ⚙️ 其他变更
- 🔐 新增在线画廊黑名单配置相关能力（设置与持久化支持）。
- 🧹 移除部分无用文件，简化代码结构。

### 📦 下载说明
- Windows 压缩包：`NAI_Launcher_Windows_1.0.0-beta6+9.zip`

### 📝 相关提交（v1.0.0-beta5..v1.0.0-beta6）
- `b5a502b0` Bump version to beta6
- `8441f2e1` Remove space fullscreen shortcut
- `9e51dc42` Fix online gallery responses
- `11ba8211` feat(online-gallery): support multi-select rating filter
- `c3aab1f5` fix(gallery): stabilize first-drag preview rendering and quality
- `28a53c36` fix(gallery): 修复首次拖拽无预览图 - 使用 Image.file 直接加载
- `f96d94a5` fix(gallery): 修复首次拖拽无预览图的根本原因
- `3779af09` fix(gallery): 修复首次拖拽无预览图问题
- `e77e4330` fix: 恢复 super_clipboard 导入以使用 DataReader
- `f9c27a19` fix(gallery): 修复首次拖拽无预览图的BUG
- `57f2427a` fix: 修复9个info级别警告
- `5d0d142a` fix(gallery): 底部提示区域改为不透明背景
- `f981b61b` style(gallery): 图片占满卡片，名称作为底部覆层
- `59e6ae5b` fix(gallery): 修复图片和文字之间的缝隙
- `11851545` style(gallery): 减少拖拽卡片底部留白
- `218ca8df` style(gallery): 美化拖拽卡片为小而精美的设计
- `9ed7c98d` fix(gallery): 拖拽卡片改为纵向布局并修复边角缝隙
- `550f41cd` fix(gallery): 添加内部拖拽标识
- `6cad3037` fix(gallery): 恢复拖拽提示并区分内外部拖拽
- `ddbdfb7c` fix(gallery): 移除拖拽覆盖层提示并缩小预览卡片
- `6a9a662d` fix(gallery): 修复拖拽占位符问题
- `6ac8e9c3` feat(gallery): 添加按分类路径过滤功能
- `47eee26f` style(gallery): 格式化代码提升可读性
- `03328c6b` fix(gallery): 修复图像卡片拖拽功能
- `93e901f1` feat(gallery): 实现图像卡片拖拽功能
- `638d1424` refactor(core): 删除无用文件以简化代码库
- `ffbdaa1e` feat(gallery): 新增根据路径获取图片记录功能
