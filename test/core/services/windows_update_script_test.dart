import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/windows_update_script.dart';

const _windowsCodePages = [936, 950, 932, 949, 1252, 65001];

// 与 Windows PowerShell 5.1 读取 -File 脚本一致：先认 BOM，没有 BOM 才按代码页解码。
const _windowsPowerShellReader = r'''
param([string]$ScriptPath, [string]$CodePages, [string]$ReportPath)
$ErrorActionPreference = 'Stop'
$Report = [ordered]@{}
foreach ($CodePage in $CodePages.Split(',')) {
  $Reader = New-Object System.IO.StreamReader(
    $ScriptPath,
    [System.Text.Encoding]::GetEncoding([int]$CodePage),
    $true
  )
  try {
    $Text = $Reader.ReadToEnd()
  } finally {
    $Reader.Dispose()
  }
  $Tokens = $null
  $ParseErrors = $null
  $Ast = [System.Management.Automation.Language.Parser]::ParseInput(
    $Text,
    [ref]$Tokens,
    [ref]$ParseErrors
  )
  $Values = [ordered]@{}
  foreach ($Statement in $Ast.EndBlock.Statements) {
    if ($Statement -is [System.Management.Automation.Language.AssignmentStatementAst] -and
        $Statement.Right.Expression -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
      $Values[$Statement.Left.VariablePath.UserPath] = $Statement.Right.Expression.Value
    }
  }
  $Report[$CodePage] = [ordered]@{
    errors = @($ParseErrors | ForEach-Object { $_.Message })
    values = $Values
  }
}
[System.IO.File]::WriteAllText(
  $ReportPath,
  ($Report | ConvertTo-Json -Depth 4),
  (New-Object System.Text.UTF8Encoding($false))
)
''';

void main() {
  group('WindowsUpdateScript', () {
    test(
      'installer waits, verifies exit code, records result and restarts',
      () {
        final script = WindowsUpdateScript.buildInstallerScript(
          appPid: 4321,
          version: '1.6.0',
          installerPath: r'C:\Temp\setup.exe',
          executablePath: r'C:\Apps\NAI\nai_launcher.exe',
          resultPath: r'C:\Temp\result.json',
          pendingMetadataPath: r'C:\Temp\pending.json',
          startedMarkerPath: r'C:\Temp\started.json',
          logPath: r'C:\Temp\update.log',
        );

        expect(script, contains('\$AppPid = 4321'));
        expect(script, contains('Get-Process -Id \$AppPid'));
        expect(script, contains(r"'C:\Temp\setup.exe'"));
        expect(script, contains("-ArgumentList '/S'"));
        expect(script, contains('\$Installer.ExitCode -ne 0'));
        expect(script, contains('Write-UpdateResult -Success \$true'));
        expect(script, contains('Write-UpdateResult -Success \$false'));
        expect(script, contains('Start-Process -FilePath \$ExePath'));
        expect(script, contains('Remove-Item -LiteralPath \$InstallerPath'));
      },
    );

    test(
      'portable script swaps directories, preserves user files and rolls back',
      () {
        final script = WindowsUpdateScript.buildPortableScript(
          appPid: 1234,
          version: '1.6.0',
          zipPath: r'C:\Temp\update.zip',
          appDirectory: r'D:\Apps\NAI',
          executableName: 'nai_launcher.exe',
          proxyExecutableName: 'nai_launcher_mcp.exe',
          extractDirectory: r'D:\Apps\.nai_update_1.6.0',
          backupDirectory: r'D:\Apps\.nai_backup_1.6.0',
          resultPath: r'C:\Temp\result.json',
          pendingMetadataPath: r'C:\Temp\pending.json',
          startedMarkerPath: r'C:\Temp\started.json',
          logPath: r'C:\Temp\update.log',
        );

        expect(script, contains('\$AppPid = 1234'));
        expect(script, contains('Expand-Archive'));
        expect(script, contains(r"'D:\Apps\NAI'"));
        expect(script, contains("'app_files_manifest.json'"));
        expect(
          script,
          contains(
            'Get-Content -LiteralPath \$OldManifestPath -Raw -Encoding UTF8',
          ),
        );
        expect(script, contains('\$CanPreserveUserFiles = \$false'));
        expect(script, contains('if (\$CanPreserveUserFiles)'));
        expect(script, contains('Move-Item -LiteralPath \$AppDir'));
        expect(script, contains('Copy-Item -LiteralPath \$_.FullName'));
        expect(script, contains('Previous application version restored.'));
        expect(script, contains('Updated application exited immediately'));
        expect(script, isNot(contains('/MIR')));
      },
    );

    test(
      'portable script stops only bundled proxies inside the app directory',
      () {
        final script = WindowsUpdateScript.buildPortableScript(
          appPid: 1234,
          version: '1.6.0',
          zipPath: r'C:\Temp\update.zip',
          appDirectory: r'D:\Apps\NAI',
          executableName: 'nai_launcher.exe',
          proxyExecutableName: 'nai_launcher_mcp.exe',
          extractDirectory: r'D:\Apps\.nai_update_1.6.0',
          backupDirectory: r'D:\Apps\.nai_backup_1.6.0',
          resultPath: r'C:\Temp\result.json',
          pendingMetadataPath: r'C:\Temp\pending.json',
          startedMarkerPath: r'C:\Temp\started.json',
          logPath: r'C:\Temp\update.log',
        );

        expect(script, contains("\$ProxyExeName = 'nai_launcher_mcp.exe'"));
        expect(script, contains('Join-Path \$AppDir \$ProxyExeName'));
        expect(script, contains('OrdinalIgnoreCase'));
        expect(script, contains('Stop-Process -Id \$Proxy.ProcessId -Force'));
        expect(
          script.indexOf('Stop-BundledProxies\n'),
          lessThan(script.indexOf('Move-Item -LiteralPath \$AppDir')),
        );
      },
    );

    test('installer script defers process handling to the installer', () {
      final script = WindowsUpdateScript.buildInstallerScript(
        appPid: 4321,
        version: '1.6.0',
        installerPath: r'C:\Temp\setup.exe',
        executablePath: r'C:\Apps\NAI\nai_launcher.exe',
        resultPath: r'C:\Temp\result.json',
        pendingMetadataPath: r'C:\Temp\pending.json',
        startedMarkerPath: r'C:\Temp\started.json',
        logPath: r'C:\Temp\update.log',
      );

      expect(script, isNot(contains('Stop-BundledProxies')));
      expect(script, isNot(contains('Stop-Process')));
    });

    test('generated scripts pass the Windows PowerShell parser', () async {
      if (!Platform.isWindows) return;

      final tempDir = await Directory.systemTemp.createTemp('update_script_');
      try {
        final scripts = [
          WindowsUpdateScript.buildInstallerScript(
            appPid: 1,
            version: '1.6.0',
            installerPath: r'C:\Temp\setup.exe',
            executablePath: r'C:\Apps\nai_launcher.exe',
            resultPath: r'C:\Temp\result.json',
            pendingMetadataPath: r'C:\Temp\pending.json',
            startedMarkerPath: r'C:\Temp\started.json',
            logPath: r'C:\Temp\update.log',
          ),
          WindowsUpdateScript.buildPortableScript(
            appPid: 1,
            version: '1.6.0',
            zipPath: r'C:\Temp\update.zip',
            appDirectory: r'D:\Apps\NAI',
            executableName: 'nai_launcher.exe',
            proxyExecutableName: 'nai_launcher_mcp.exe',
            extractDirectory: r'D:\Apps\.nai_update_1.6.0',
            backupDirectory: r'D:\Apps\.nai_backup_1.6.0',
            resultPath: r'C:\Temp\result.json',
            pendingMetadataPath: r'C:\Temp\pending.json',
            startedMarkerPath: r'C:\Temp\started.json',
            logPath: r'C:\Temp\update.log',
          ),
        ];

        for (var index = 0; index < scripts.length; index++) {
          final file = File('${tempDir.path}/script_$index.ps1');
          await file.writeAsBytes(WindowsUpdateScript.encode(scripts[index]));
          final escapedPath = file.path.replaceAll("'", "''");
          final result = await Process.run('powershell.exe', [
            '-NoProfile',
            '-NonInteractive',
            '-Command',
            "\$tokens = \$null; \$errors = \$null; "
                "[System.Management.Automation.Language.Parser]::ParseFile('$escapedPath', [ref]\$tokens, [ref]\$errors) | Out-Null; "
                "if (\$errors.Count -gt 0) { \$errors | ForEach-Object { Write-Error \$_.Message }; exit 1 }",
          ]);
          expect(
            result.exitCode,
            0,
            reason: '${result.stdout}\n${result.stderr}',
          );
        }
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('both scripts announce the start before waiting for the app', () {
      final scripts = {
        'installer': WindowsUpdateScript.buildInstallerScript(
          appPid: 1,
          version: '1.6.0',
          installerPath: r'C:\Temp\setup.exe',
          executablePath: r'C:\Apps\nai_launcher.exe',
          resultPath: r'C:\Temp\result.json',
          pendingMetadataPath: r'C:\Temp\pending.json',
          startedMarkerPath: r'C:\Temp\started.json',
          logPath: r'C:\Temp\update.log',
        ),
        'portable': WindowsUpdateScript.buildPortableScript(
          appPid: 1,
          version: '1.6.0',
          zipPath: r'C:\Temp\update.zip',
          appDirectory: r'D:\Apps\NAI',
          executableName: 'nai_launcher.exe',
          proxyExecutableName: 'nai_launcher_mcp.exe',
          extractDirectory: r'D:\Apps\.nai_update_1.6.0',
          backupDirectory: r'D:\Apps\.nai_backup_1.6.0',
          resultPath: r'C:\Temp\result.json',
          pendingMetadataPath: r'C:\Temp\pending.json',
          startedMarkerPath: r'C:\Temp\started.json',
          logPath: r'C:\Temp\update.log',
        ),
      };

      scripts.forEach((kind, script) {
        expect(
          script,
          contains(r"$StartedPath = 'C:\Temp\started.json'"),
          reason: kind,
        );
        // 标记晚于 Wait-ApplicationExit 写出会让应用一直等不到确认。
        expect(
          script.indexOf('\nWrite-UpdateStarted\n'),
          lessThan(script.indexOf('Wait-ApplicationExit\n')),
          reason: kind,
        );
        expect(
          script.indexOf('\nWrite-UpdateStarted\n'),
          lessThan(script.indexOf('try {')),
          reason: kind,
        );
        // 有结果之后留着标记，下次启动会误判成安装被中断。
        expect(
          script.indexOf('Remove-Item -LiteralPath \$StartedPath'),
          greaterThan(script.indexOf('WriteAllText(\n    \$ResultPath')),
          reason: kind,
        );
      });
    });

    test('escapes single quotes in paths for PowerShell', () {
      final script = WindowsUpdateScript.buildInstallerScript(
        appPid: 1,
        version: '1.6.0',
        installerPath: r"C:\Temp\it's.exe",
        executablePath: r'C:\Apps\nai_launcher.exe',
        resultPath: r'C:\Temp\result.json',
        pendingMetadataPath: r'C:\Temp\pending.json',
        startedMarkerPath: r'C:\Temp\started.json',
        logPath: r'C:\Temp\update.log',
      );

      expect(script, contains(r"'C:\Temp\it''s.exe'"));
    });

    test('escapes every PowerShell single-quote character in paths', () {
      final script = WindowsUpdateScript.buildInstallerScript(
        appPid: 1,
        version: '1.6.0',
        installerPath: r"C:\Temp\‘a’ ‚b‛ 'c'.exe",
        executablePath: r'C:\Apps\nai_launcher.exe',
        resultPath: r'C:\Temp\result.json',
        pendingMetadataPath: r'C:\Temp\pending.json',
        startedMarkerPath: r'C:\Temp\started.json',
        logPath: r'C:\Temp\update.log',
      );

      expect(script, contains(r"'C:\Temp\‘‘a’’ ‚‚b‛‛ ''c''.exe'"));
    });

    test('encodes scripts as UTF-8 with a byte order mark', () {
      const script = "# 注释\n\$LogPath = 'C:\\Users\\王小明\\update.log'\n";

      final bytes = WindowsUpdateScript.encode(script);

      expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      expect(utf8.decode(bytes.sublist(3)), script);
    });

    test(
      'scripts keep non-ASCII paths intact under every Windows code page',
      () async {
        // 九字节的用户名会让 GBK 解码吞掉其后的反斜杠。
        const temp = r'C:\Users\王小明\AppData\Local\Temp\nai_launcher_updates';
        const appDirectory = r'D:\下载\Bob’s ‘NAI’';
        const version = '4.3.1+46';
        final installerValues = {
          'ErrorActionPreference': 'Stop',
          'Version': version,
          'InstallerPath': "$temp\\it's setup.exe",
          'ExePath': '$appDirectory\\nai_launcher.exe',
          'ResultPath': '$temp\\update_result.json',
          'PendingMetadataPath': '$temp\\pending_update.json',
          'StartedPath': '$temp\\update_started.json',
          'LogPath': '$temp\\update_$version.log',
        };
        final portableValues = {
          'ErrorActionPreference': 'Stop',
          'Version': version,
          'ZipPath': '$temp\\NAI_Launcher_Windows_${version}_Portable.zip',
          'AppDir': appDirectory,
          'ExeName': 'nai_launcher.exe',
          'ProxyExeName': 'nai_launcher_mcp.exe',
          'ExtractDir': r'D:\下载\.nai_update_4.3.1_46',
          'BackupDir': r'D:\下载\.nai_backup_4.3.1_46',
          'ResultPath': '$temp\\update_result.json',
          'PendingMetadataPath': '$temp\\pending_update.json',
          'StartedPath': '$temp\\update_started.json',
          'LogPath': '$temp\\update_$version.log',
        };
        final scripts = {
          'installer': (
            WindowsUpdateScript.buildInstallerScript(
              appPid: 1,
              version: version,
              installerPath: installerValues['InstallerPath']!,
              executablePath: installerValues['ExePath']!,
              resultPath: installerValues['ResultPath']!,
              pendingMetadataPath: installerValues['PendingMetadataPath']!,
              startedMarkerPath: installerValues['StartedPath']!,
              logPath: installerValues['LogPath']!,
            ),
            installerValues,
          ),
          'portable': (
            WindowsUpdateScript.buildPortableScript(
              appPid: 1,
              version: version,
              zipPath: portableValues['ZipPath']!,
              appDirectory: portableValues['AppDir']!,
              executableName: portableValues['ExeName']!,
              proxyExecutableName: portableValues['ProxyExeName']!,
              extractDirectory: portableValues['ExtractDir']!,
              backupDirectory: portableValues['BackupDir']!,
              resultPath: portableValues['ResultPath']!,
              pendingMetadataPath: portableValues['PendingMetadataPath']!,
              startedMarkerPath: portableValues['StartedPath']!,
              logPath: portableValues['LogPath']!,
            ),
            portableValues,
          ),
        };

        final tempDir = await Directory.systemTemp.createTemp(
          'update_script_code_pages_',
        );
        addTearDown(() => tempDir.delete(recursive: true));
        final reader = File('${tempDir.path}/read_as_windows_powershell.ps1');
        await reader.writeAsString(_windowsPowerShellReader);

        for (final MapEntry(key: kind, value: (script, expected))
            in scripts.entries) {
          final scriptFile = File('${tempDir.path}/$kind.ps1');
          await scriptFile.writeAsBytes(WindowsUpdateScript.encode(script));
          final reportFile = File('${tempDir.path}/$kind.json');
          final result = await Process.run('powershell.exe', [
            '-NoProfile',
            '-NonInteractive',
            '-ExecutionPolicy',
            'Bypass',
            '-File',
            reader.path,
            '-ScriptPath',
            scriptFile.path,
            '-CodePages',
            _windowsCodePages.join(','),
            '-ReportPath',
            reportFile.path,
          ]);
          expect(
            result.exitCode,
            0,
            reason: '${result.stdout}\n${result.stderr}',
          );

          final report =
              jsonDecode(await reportFile.readAsString())
                  as Map<String, dynamic>;
          for (final codePage in _windowsCodePages) {
            final entry = report['$codePage'] as Map<String, dynamic>;
            expect(entry['errors'], isEmpty, reason: '$kind @ cp$codePage');
            expect(entry['values'], expected, reason: '$kind @ cp$codePage');
          }
        }
      },
      skip: !Platform.isWindows,
    );
  });
}
