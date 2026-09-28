/// Windows 平台应用内更新的辅助脚本生成器。
///
/// 更新在应用完全退出后执行。脚本记录日志与结构化结果，安装失败会
/// 重新启动旧版本；便携版通过同卷目录切换和备份实现可回滚更新。
library;

class WindowsUpdateScript {
  WindowsUpdateScript._();

  static String buildInstallerScript({
    required int appPid,
    required String version,
    required String installerPath,
    required String executablePath,
    required String resultPath,
    required String pendingMetadataPath,
    required String logPath,
  }) {
    return '''
\$ErrorActionPreference = 'Stop'
\$AppPid = $appPid
\$Version = '${_escape(version)}'
\$InstallerPath = '${_escape(installerPath)}'
\$ExePath = '${_escape(executablePath)}'
\$ResultPath = '${_escape(resultPath)}'
\$PendingMetadataPath = '${_escape(pendingMetadataPath)}'
\$LogPath = '${_escape(logPath)}'
\$ScriptPath = \$MyInvocation.MyCommand.Path

${_commonFunctions()}

try {
  Write-UpdateLog "Waiting for application process \$AppPid to exit."
  Wait-ApplicationExit
  Write-UpdateLog "Starting silent installer: \$InstallerPath"
  \$Installer = Start-Process -FilePath \$InstallerPath -ArgumentList '/S' -PassThru -Wait
  if (\$Installer.ExitCode -ne 0) {
    throw "Installer exited with code \$(\$Installer.ExitCode)."
  }

  Write-UpdateResult -Success \$true -Message 'Update installed successfully.'
  Remove-Item -LiteralPath \$PendingMetadataPath -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath \$InstallerPath -Force -ErrorAction SilentlyContinue
  Write-UpdateLog 'Installer update completed successfully.'
  Start-Process -FilePath \$ExePath
} catch {
  \$FailureMessage = \$_.Exception.Message
  Write-UpdateLog "Installer update failed: \$FailureMessage"
  Write-UpdateResult -Success \$false -Message \$FailureMessage
  if (Test-Path -LiteralPath \$ExePath) {
    Start-Process -FilePath \$ExePath -ErrorAction SilentlyContinue
  }
  exit 1
} finally {
  Remove-Item -LiteralPath \$ScriptPath -Force -ErrorAction SilentlyContinue
}
''';
  }

  static String buildPortableScript({
    required int appPid,
    required String version,
    required String zipPath,
    required String appDirectory,
    required String executableName,
    required String extractDirectory,
    required String backupDirectory,
    required String resultPath,
    required String pendingMetadataPath,
    required String logPath,
  }) {
    return '''
\$ErrorActionPreference = 'Stop'
\$AppPid = $appPid
\$Version = '${_escape(version)}'
\$ZipPath = '${_escape(zipPath)}'
\$AppDir = '${_escape(appDirectory)}'
\$ExeName = '${_escape(executableName)}'
\$ExtractDir = '${_escape(extractDirectory)}'
\$BackupDir = '${_escape(backupDirectory)}'
\$ResultPath = '${_escape(resultPath)}'
\$PendingMetadataPath = '${_escape(pendingMetadataPath)}'
\$LogPath = '${_escape(logPath)}'
\$ScriptPath = \$MyInvocation.MyCommand.Path
\$Swapped = \$false

${_commonFunctions()}

try {
  Write-UpdateLog "Waiting for application process \$AppPid to exit."
  Wait-ApplicationExit

  Remove-Item -LiteralPath \$ExtractDir -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath \$BackupDir -Recurse -Force -ErrorAction SilentlyContinue
  Write-UpdateLog "Extracting update package to \$ExtractDir"
  Expand-Archive -LiteralPath \$ZipPath -DestinationPath \$ExtractDir -Force

  \$SourceDir = \$ExtractDir
  \$Items = @(Get-ChildItem -LiteralPath \$ExtractDir)
  if (\$Items.Count -eq 1 -and \$Items[0].PSIsContainer) {
    \$SourceDir = \$Items[0].FullName
  }
  if (!(Test-Path -LiteralPath (Join-Path \$SourceDir \$ExeName))) {
    throw 'The extracted update does not contain the application executable.'
  }

  # 只把旧清单之外的文件视为用户文件。没有旧清单时无法可靠区分旧程序
  # 文件与用户文件，因此不把旧目录内容覆盖回新版本。
  \$ManagedFiles = @{}
  \$CanPreserveUserFiles = \$false
  \$OldManifestPath = Join-Path \$AppDir 'app_files_manifest.json'
  if (Test-Path -LiteralPath \$OldManifestPath) {
    \$OldManifest = Get-Content -LiteralPath \$OldManifestPath -Raw | ConvertFrom-Json
    if (\$null -eq \$OldManifest.files) {
      throw 'The existing application file manifest is invalid.'
    }
    foreach (\$RelativePath in \$OldManifest.files) {
      \$ManagedFiles[\$RelativePath.ToString().ToLowerInvariant()] = \$true
    }
    \$ManagedFiles['app_files_manifest.json'] = \$true
    \$CanPreserveUserFiles = \$true
  } else {
    Write-UpdateLog 'No existing file manifest; skipping user-file migration for this update.'
  }

  Write-UpdateLog "Moving current application to backup: \$BackupDir"
  Move-Item -LiteralPath \$AppDir -Destination \$BackupDir
  Move-Item -LiteralPath \$SourceDir -Destination \$AppDir
  \$Swapped = \$true

  if (\$CanPreserveUserFiles) {
    Get-ChildItem -LiteralPath \$BackupDir -File -Recurse | ForEach-Object {
      \$RelativePath = \$_.FullName.Substring(\$BackupDir.Length).TrimStart('\\')
      if (!\$ManagedFiles.ContainsKey(\$RelativePath.ToLowerInvariant())) {
        \$Destination = Join-Path \$AppDir \$RelativePath
        \$DestinationDir = Split-Path -Parent \$Destination
        New-Item -ItemType Directory -Path \$DestinationDir -Force | Out-Null
        Copy-Item -LiteralPath \$_.FullName -Destination \$Destination -Force
      }
    }
  }

  \$NewExePath = Join-Path \$AppDir \$ExeName
  Write-UpdateResult -Success \$true -Message 'Update installed successfully.'
  Write-UpdateLog "Starting updated application: \$NewExePath"
  \$NewProcess = Start-Process -FilePath \$NewExePath -PassThru
  Start-Sleep -Seconds 3
  if (\$NewProcess.HasExited) {
    throw "Updated application exited immediately with code \$(\$NewProcess.ExitCode)."
  }

  Remove-Item -LiteralPath \$BackupDir -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath \$ExtractDir -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath \$PendingMetadataPath -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath \$ZipPath -Force -ErrorAction SilentlyContinue
  Write-UpdateLog 'Portable update completed successfully.'
} catch {
  \$FailureMessage = \$_.Exception.Message
  Write-UpdateLog "Portable update failed: \$FailureMessage"

  if (Test-Path -LiteralPath \$BackupDir) {
    if (Test-Path -LiteralPath \$AppDir) {
      Remove-Item -LiteralPath \$AppDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    Move-Item -LiteralPath \$BackupDir -Destination \$AppDir
    \$Swapped = \$false
    Write-UpdateLog 'Previous application version restored.'
  }

  Write-UpdateResult -Success \$false -Message \$FailureMessage
  \$RestoredExePath = Join-Path \$AppDir \$ExeName
  if (Test-Path -LiteralPath \$RestoredExePath) {
    Start-Process -FilePath \$RestoredExePath -ErrorAction SilentlyContinue
  }
  exit 1
} finally {
  Remove-Item -LiteralPath \$ExtractDir -Recurse -Force -ErrorAction SilentlyContinue
  if (!\$Swapped) {
    Remove-Item -LiteralPath \$BackupDir -Recurse -Force -ErrorAction SilentlyContinue
  }
  Remove-Item -LiteralPath \$ScriptPath -Force -ErrorAction SilentlyContinue
}
''';
  }

  static String _commonFunctions() {
    return '''
function Write-UpdateLog {
  param([string]\$Message)
  \$Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'
  Add-Content -LiteralPath \$LogPath -Value "[\$Timestamp] \$Message" -Encoding UTF8
}

function Write-UpdateResult {
  param([bool]\$Success, [string]\$Message)
  \$Result = [ordered]@{
    success = \$Success
    version = \$Version
    message = \$Message
    logPath = \$LogPath
  } | ConvertTo-Json -Compress
  [System.IO.File]::WriteAllText(
    \$ResultPath,
    \$Result,
    (New-Object System.Text.UTF8Encoding(\$false))
  )
}

function Wait-ApplicationExit {
  \$Deadline = [DateTime]::UtcNow.AddSeconds(120)
  while ((Get-Process -Id \$AppPid -ErrorAction SilentlyContinue) -and
         [DateTime]::UtcNow -lt \$Deadline) {
    Start-Sleep -Milliseconds 250
  }
  Start-Sleep -Milliseconds 500
  if (Get-Process -Id \$AppPid -ErrorAction SilentlyContinue) {
    throw "Application process \$AppPid did not exit within 120 seconds."
  }
}
''';
  }

  static String _escape(String value) => value.replaceAll("'", "''");
}
