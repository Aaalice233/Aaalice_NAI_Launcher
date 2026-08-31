---
name: aaalice-launcher-release
description: 为 Aaalice NAI Launcher 准备并发布新版本，包括同步 main、更新版本号、生成并逐项审查 Changelog 材料、撰写用户更新日志、执行发布前验证、提交、创建并推送 v* tag。用户提到发布 Launcher 版本、准备 Release、写 CHANGELOG、更新日志或 release notes 时使用。
compatibility: 必须位于 Aaalice_NAI_Launcher 仓库，并具备 git、Git LFS、Flutter、Dart 与 PowerShell。
---

# Aaalice NAI Launcher 版本发布

本 skill 是 Aaalice NAI Launcher 应用版本发布与 Changelog 撰写的唯一流程文档。`AGENTS.md` 只保留通用工程、资源和验证约束；执行发布时同时遵守这些通用约束，但不得在其他文档复制本流程。

## 约束

- 更新日志的差异审查、归类、撰写和完整性复核必须由当前主 Agent 亲自完成，禁止委派子代理。
- 不根据 commit 标题直接写日志；必须同时阅读审查报告与完整 diff，并按变更文件反向核对。
- 工作区已有改动默认属于用户。发布前必须确认其来源，不得覆盖、清理或混入发布提交。
- tag 必须等于 `pubspec.yaml` 中去掉 `+build` 的版本，如 `3.2.0+38` 对应 `v3.2.0`。
- 日常版本日志只维护 `CHANGELOG.md`；不要手写安装包文件表。Release metadata 由项目脚本生成。
- 创建和推送 tag 会触发正式 Release workflow。只有用户明确要求发布时才能执行，不得把“只写更新日志”理解为授权发布。

## 1. 同步与基线确认

1. 读取项目 `AGENTS.md`，确认当前通用工程、资源和验证约束。
2. 检查当前分支、工作区、远端和 LFS 状态：

```powershell
git status --short --branch
git remote -v
git lfs status
```

3. 发布必须从干净的 `main` 开始。用户授权同步后执行：

```powershell
git fetch --all --prune
git pull --ff-only origin main
git lfs pull --include="assets/databases/tag_catalog.db"
```

4. 读取当前 `pubspec.yaml` 版本、最近 `v*` tag 与 `HEAD`。向用户确认无法可靠推导的目标版本或 build number；可明确顺延时使用下一个 build number。

## 2. 准备版本号

1. 将 `pubspec.yaml` 更新为目标 `semver+build`。
2. 运行源检查与 diff 检查：

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/verify_flutter_sources.ps1
git diff --check
```

3. 只提交版本号改动：

```text
chore(release): 准备 <version> 版本
```

发布审查脚本要求工作区干净，因此版本号必须先形成独立提交。

## 3. 生成并阅读 Changelog 审查材料

运行：

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/prepare_changelog_review.ps1
```

脚本输出：

- `tool/.tmp/changelog-review/release-changelog-review.md`
- `tool/.tmp/changelog-review/release-changelog.diff`

当前主 Agent 必须完成以下审查：

1. 完整阅读 `release-changelog-review.md`，确认比较范围、每个提交及全部变更文件。
2. 完整审查 `release-changelog.diff`。大 diff 可按文件、功能域或 hunk 分段读取，但不能只读统计、提交标题或局部摘要。
3. 以登录、更新、生成、画廊、词库、设置、启动、安装、多语言等入口建立覆盖清单。
4. 区分用户可见变化与纯内部文档、测试、重构、构建维护；后者不写入用户日志。
5. 同一功能开发期间的新增和修复合并为最终用户结果，不暴露中间损坏状态。

## 4. 撰写目标版本段落

在 `CHANGELOG.md` 的 `[Unreleased]` 后新增：

```markdown
## [<version>] - YYYY-MM-DD

### ✨ 新增

- ...

### 🛠 改进

- ...

### 🐛 修复

- ...
```

规则：

- 只保留确有内容的分类。
- 每个 bullet 只描述一个功能主题或一个用户问题。
- 使用用户能看到的入口、问题和结果，不写类名、文件名、接口名、测试名、commit hash 或内部实现过程。
- 同一功能的入口、交互和结果可合并；不同功能或不同问题必须拆开。
- 对新增能力说明“在哪里使用、能做什么”；对修复说明“原来看到什么问题、现在得到什么结果”。
- 日期使用发布当天日期，不沿用旧版本日期。
- 不在 `CHANGELOG.md` 重复下载文件、大小或校验表。

完成初稿后必须做两轮复核：

1. **按提交复核**：每个非纯内部提交都已覆盖，或明确合并到对应功能主题。
2. **按文件反向复核**：从全部变更文件回看受影响入口，确认没有遗漏跨模块和多语言变化。

然后运行：

```powershell
git diff --check
git diff -- CHANGELOG.md
```

并以以下消息提交：

```text
docs(release): 更新 <version> 版本日志
```

## 5. 发布前验证

执行以下固定发布检查：

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/verify_flutter_sources.ps1
dart run tool/tag_catalog/verify_bundled_databases.dart
```

根据本版本风险选择并记录：

- `pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/run_flutter_tests.ps1`
- `flutter analyze`
- Windows、macOS、Android 的适用 release build
- Windows NuGet / portable package 验证

这是发布核心流程：共享契约、数据库、平台原生代码或大范围变更应执行广泛验证。失败时先判断是否由本版本改动、既有问题或环境导致；不得跳过、伪造通过或为通过而修改无关测试。

发布前再次检查：

```powershell
git status --short --branch
git log --oneline <previous-tag>..HEAD
git diff --check <previous-tag>..HEAD
```

确认工作区干净、版本正确、Changelog 完整、LFS 数据库是真实 SQLite 文件。

## 6. 创建并推送 Release tag

仅在验证达到发布标准且用户已明确授权发布时执行：

```powershell
git push origin main
git tag -a v<version> -m "v<version>"
git push origin v<version>
```

推送后检查 GitHub Actions `Release` workflow 是否已由该 tag 触发。该 workflow 应从不可变 tag commit 构建 Windows Setup、Windows Portable、macOS Portable 与正式签名 Android APK，并生成 `release_manifest.json`、`checksums.txt` 和 Release notes。

不得在 workflow 尚未成功时宣称安装包已发布；应区分“tag 已推送 / CI 构建中 / Release 已完成”。Android 正式发布必须配置 `ANDROID_SIGNING_KEYSTORE_BASE64`、`ANDROID_SIGNING_KEYSTORE_PASSWORD`、`ANDROID_SIGNING_KEY_ALIAS` 与 `ANDROID_SIGNING_KEY_PASSWORD`，缺少任一项必须失败，不得发布调试签名 APK。Windows CI 签名使用 `WINDOWS_SIGNING_CERT_BASE64` 与 `WINDOWS_SIGNING_CERT_PASSWORD`；本地打包和签名分别使用 `scripts/package_windows_release.ps1` 与 `scripts/sign_windows_binary.ps1`。

## 交付清单

- [ ] `main` 与远端同步，工作区干净
- [ ] `pubspec.yaml` 为目标 `semver+build`
- [ ] 版本号提交已完成
- [ ] 主 Agent 已亲自阅读审查报告与完整 diff
- [ ] `CHANGELOG.md` 已按提交和变更文件双向复核
- [ ] 更新日志提交已完成
- [ ] Flutter 官方源检查通过
- [ ] 内置数据库检查通过
- [ ] 与风险匹配的测试、analyze、build 已执行并记录
- [ ] `main` 已推送
- [ ] `v*` annotated tag 已创建并推送
- [ ] Release workflow 状态已核对并如实报告
