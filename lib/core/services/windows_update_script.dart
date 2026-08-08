/// Windows 平台应用内更新的辅助脚本生成器。
///
/// 更新安装必须在应用进程退出后进行，否则安装器会因文件占用而失败。
/// 旧实现让安装器与应用退出“竞速”（启动安装器后延迟退出应用），
/// 时序不稳定。改为生成一个独立 PowerShell 脚本：脚本先等待应用进程
/// 退出，再执行安装或文件替换，彻底消除竞态。
library;

/// 生成 Windows 更新辅助脚本的纯函数集合，便于单元测试。
class WindowsUpdateScript {
  WindowsUpdateScript._();

  /// 安装版更新脚本：等待应用退出后以静默模式运行 NSIS 安装器。
  ///
  /// NSIS 安装成功后会自行启动新版本应用（见 nai_launcher.nsi），
  /// 脚本只负责运行安装器并清理临时文件。
  static String buildInstallerScript({
    required int appPid,
    required String installerPath,
  }) {
    return '''
\$ErrorActionPreference = 'Stop'
\$AppPid = $appPid
\$InstallerPath = '${_escape(installerPath)}'
\$ScriptPath = \$MyInvocation.MyCommand.Path

# 等待应用进程退出，避免安装时文件被占用。
try {
  Wait-Process -Id \$AppPid -Timeout 120 -ErrorAction SilentlyContinue
} catch {}
Start-Sleep -Milliseconds 500

try {
  Start-Process -FilePath \$InstallerPath -ArgumentList '/S' -Wait
} finally {
  Remove-Item -LiteralPath \$InstallerPath -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath \$ScriptPath -Force -ErrorAction SilentlyContinue
}
''';
  }

  /// 便携版更新脚本：等待应用退出后解压更新包覆盖应用目录并重启。
  ///
  /// 只覆盖同名文件、不删除多余文件（Copy-Item -Force），
  /// 避免误删用户放在应用目录旁边的个人文件。
  static String buildPortableScript({
    required int appPid,
    required String zipPath,
    required String appDirectory,
    required String executablePath,
    required String extractDirectory,
  }) {
    return '''
\$ErrorActionPreference = 'Stop'
\$AppPid = $appPid
\$ZipPath = '${_escape(zipPath)}'
\$AppDir = '${_escape(appDirectory)}'
\$ExePath = '${_escape(executablePath)}'
\$ExtractDir = '${_escape(extractDirectory)}'
\$ScriptPath = \$MyInvocation.MyCommand.Path

# 等待应用进程退出，避免覆盖时文件被占用。
try {
  Wait-Process -Id \$AppPid -Timeout 120 -ErrorAction SilentlyContinue
} catch {}
Start-Sleep -Milliseconds 500

try {
  if (Test-Path -LiteralPath \$ExtractDir) {
    Remove-Item -LiteralPath \$ExtractDir -Recurse -Force
  }
  Expand-Archive -LiteralPath \$ZipPath -DestinationPath \$ExtractDir -Force

  # 发布 zip 可能带一层同名顶层目录，定位真实内容根目录。
  \$SourceDir = \$ExtractDir
  \$Items = Get-ChildItem -LiteralPath \$ExtractDir
  if (\$Items.Count -eq 1 -and \$Items[0].PSIsContainer) {
    \$SourceDir = \$Items[0].FullName
  }

  Copy-Item -Path (Join-Path \$SourceDir '*') -Destination \$AppDir -Recurse -Force
  Start-Process -FilePath \$ExePath
} finally {
  Remove-Item -LiteralPath \$ExtractDir -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath \$ZipPath -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath \$ScriptPath -Force -ErrorAction SilentlyContinue
}
''';
  }

  /// PowerShell 单引号字符串转义。
  static String _escape(String value) => value.replaceAll("'", "''");
}
