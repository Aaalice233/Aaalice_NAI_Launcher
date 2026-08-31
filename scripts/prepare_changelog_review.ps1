param(
  [string]$BaseRef,

  [string]$HeadRef = 'HEAD',

  [string]$OutputDirectory = 'tool/.tmp/changelog-review',

  [switch]$AllowDirtyWorkingTree
)

$ErrorActionPreference = 'Stop'

function Invoke-Git {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments
  )

  $output = @(& git @Arguments 2>&1)
  if ($LASTEXITCODE -ne 0) {
    $command = 'git ' + ($Arguments -join ' ')
    $details = $output -join [Environment]::NewLine
    throw "$command failed.`n$details"
  }
  return $output
}

function Get-GitFirstLine {
  param(
    [Parameter(Mandatory = $true)]
    [string[]]$Arguments
  )

  $lines = @(Invoke-Git -Arguments $Arguments)
  if ($lines.Count -eq 0) {
    throw "git $($Arguments -join ' ') 没有返回内容。"
  }
  return ([string]$lines[0]).Trim()
}

function Write-Utf8File {
  param(
    [Parameter(Mandatory = $true)]
    [string]$Path,

    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string]$Content
  )

  $utf8WithoutBom = [System.Text.UTF8Encoding]::new($false)
  [System.IO.File]::WriteAllText($Path, $Content, $utf8WithoutBom)
}

function Get-UnreleasedSection {
  $changelogPath = Join-Path (Get-Location) 'CHANGELOG.md'
  if (!(Test-Path -LiteralPath $changelogPath)) {
    return '(CHANGELOG.md 不存在)'
  }

  $lines = Get-Content -LiteralPath $changelogPath -Encoding UTF8
  $start = -1
  for ($index = 0; $index -lt $lines.Count; $index++) {
    if ($lines[$index] -match '^##\s+\[Unreleased\]\s*$') {
      $start = $index
      break
    }
  }
  if ($start -lt 0) {
    return '(CHANGELOG.md 中没有 [Unreleased] 段落)'
  }

  $end = $lines.Count
  for ($index = $start + 1; $index -lt $lines.Count; $index++) {
    if ($lines[$index] -match '^##\s+') {
      $end = $index
      break
    }
  }

  return ($lines[$start..($end - 1)] -join [Environment]::NewLine).Trim()
}

$repositoryRoot = Get-GitFirstLine -Arguments @('rev-parse', '--show-toplevel')
Set-Location -LiteralPath $repositoryRoot

[void](Invoke-Git -Arguments @('rev-parse', '--verify', "$HeadRef^{commit}"))
$headCommit = Get-GitFirstLine -Arguments @('rev-parse', "$HeadRef^{commit}")

if ([string]::IsNullOrWhiteSpace($BaseRef)) {
  $describeRef = $HeadRef
  $nearestTag = Get-GitFirstLine -Arguments @(
    'describe',
    '--tags',
    '--match', 'v[0-9]*',
    '--abbrev=0',
    $describeRef
  )
  $nearestTagCommit = Get-GitFirstLine -Arguments @('rev-parse', "$nearestTag^{commit}")
  if ($nearestTagCommit -eq $headCommit) {
    $describeRef = "$HeadRef^"
    $nearestTag = Get-GitFirstLine -Arguments @(
      'describe',
      '--tags',
      '--match', 'v[0-9]*',
      '--abbrev=0',
      $describeRef
    )
  }
  $BaseRef = $nearestTag.Trim()
}

if ([string]::IsNullOrWhiteSpace($BaseRef)) {
  throw '找不到上一个 v* 版本标签，请通过 -BaseRef 显式指定比较起点。'
}

[void](Invoke-Git -Arguments @('rev-parse', '--verify', "$BaseRef^{commit}"))
[void](Invoke-Git -Arguments @('merge-base', '--is-ancestor', $BaseRef, $HeadRef))

$workingTreeStatus = Invoke-Git -Arguments @('status', '--short')
if ($workingTreeStatus.Count -gt 0 -and !$AllowDirtyWorkingTree) {
  $statusText = $workingTreeStatus -join [Environment]::NewLine
  throw "工作区存在未提交内容。发布审查必须基于完整提交；请先提交，或仅在调试脚本时使用 -AllowDirtyWorkingTree。`n$statusText"
}

$range = "$BaseRef..$HeadRef"
$commitCount = [int](Get-GitFirstLine -Arguments @('rev-list', '--count', $range))
if ($commitCount -eq 0) {
  throw "$BaseRef 与 $HeadRef 之间没有提交。"
}

$outputPath = if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
  $OutputDirectory
} else {
  Join-Path $repositoryRoot $OutputDirectory
}
New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
$outputPath = (Resolve-Path -LiteralPath $outputPath).Path

$generatedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$shortHead = Get-GitFirstLine -Arguments @('rev-parse', '--short=12', $HeadRef)
$diffStat = (Invoke-Git -Arguments @('diff', '--stat', '--find-renames', $BaseRef, $HeadRef)) -join [Environment]::NewLine
$directorySummary = (Invoke-Git -Arguments @('diff', '--dirstat=files,0', $BaseRef, $HeadRef)) -join [Environment]::NewLine
$changedFiles = (Invoke-Git -Arguments @('diff', '--name-status', '--find-renames', $BaseRef, $HeadRef)) -join [Environment]::NewLine
$mergeCommits = (Invoke-Git -Arguments @(
  'log', $range,
  '--merges',
  '--reverse',
  '--date=short',
  '--pretty=format:- `%h` %ad %s'
)) -join [Environment]::NewLine
$commitDetails = (Invoke-Git -Arguments @(
  'log', $range,
  '--no-merges',
  '--reverse',
  '--date=short',
  '--pretty=format:### `%h` %ad %s%n%n%b',
  '--name-status'
)) -join [Environment]::NewLine
$currentUnreleased = Get-UnreleasedSection

if ([string]::IsNullOrWhiteSpace($mergeCommits)) {
  $mergeCommits = '(无 merge commit)'
}
if ([string]::IsNullOrWhiteSpace($commitDetails)) {
  $commitDetails = '(无非 merge commit)'
}
if ($workingTreeStatus.Count -eq 0) {
  $workingTreeNote = '干净；报告覆盖全部工作区内容。'
} else {
  $workingTreeNote = "存在未提交内容，未包含在本报告中：`n`n~~~text`n$($workingTreeStatus -join [Environment]::NewLine)`n~~~"
}

$report = @"
# Release Changelog 审查材料

> 这份文件只用于发布前人工/AI 审查，不可直接作为面向用户的更新日志。

- 比较范围：**$range**
- Base：**$BaseRef**
- Head：**$shortHead**
- 提交数量：$commitCount
- 生成时间：$generatedAt
- 工作区：$workingTreeNote
- 完整源码差异：**release-changelog.diff**

## 撰写要求

1. 逐项审查提交清单、变更文件和完整 diff，不能只根据 commit 标题总结。
2. 只写用户能感知的新增、改进、修复与必要注意事项；不要罗列类名、接口名、测试或重构细节。
3. 把同一功能开发期间的实现与修复合并成完整结果，避免把内部迭代写成多个重复条目。
4. 检查登录、更新、生成、画廊、词库、设置、启动、安装和多语言等受影响入口，避免遗漏跨模块变化。
5. 用简体中文重写目标版本段落，按“✨ 新增”“🛠 改进”“🐛 修复”分类；没有内容的分类不要保留。
6. 完成后再次按“变更文件清单”反向核对，确认每项用户可见变化都已覆盖或明确判定为纯内部变化。

## 当前 Unreleased 内容

$currentUnreleased

## 总体变更统计

~~~text
$diffStat
~~~

## 目录分布

~~~text
$directorySummary
~~~

## Merge / PR 提交

$mergeCommits

## 非 Merge 提交、说明与涉及文件

$commitDetails

## 全部变更文件

~~~text
$changedFiles
~~~
"@

$reportPath = Join-Path $outputPath 'release-changelog-review.md'
$patchPath = Join-Path $outputPath 'release-changelog.diff'
Write-Utf8File -Path $reportPath -Content $report.TrimEnd()

$patch = (Invoke-Git -Arguments @(
  'diff',
  '--no-ext-diff',
  '--no-color',
  '--find-renames',
  '--find-copies',
  $BaseRef,
  $HeadRef
)) -join [Environment]::NewLine
Write-Utf8File -Path $patchPath -Content $patch

Write-Host "Changelog review range: $range"
Write-Host "Review report: $reportPath"
Write-Host "Full diff: $patchPath"
Write-Host '下一步：逐项阅读报告和完整 diff，再重写 CHANGELOG.md 的目标版本段落。'
