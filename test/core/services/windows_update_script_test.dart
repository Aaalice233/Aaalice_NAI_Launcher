import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/windows_update_script.dart';
import 'package:path/path.dart' as p;

const _windowsCodePages = [936, 950, 932, 949, 1252, 65001];

/// 从 pwsh 启动的测试进程会把 PowerShell 7 的模块目录留在 PSModulePath 里，
/// Windows PowerShell 5.1 子进程会因此加载只支持 .NET Core 的 Archive 模块。
/// 去掉它，让 5.1 用自己的默认模块路径，和用户从资源管理器启动时一致。
Map<String, String> _windowsPowerShellEnvironment() => {
  for (final MapEntry(:key, :value) in Platform.environment.entries)
    if (key.toUpperCase() != 'PSMODULEPATH') key: value,
};

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

    test(
      'both scripts switch PowerShell and process working directories before modifying app files',
      () {
        final installer = WindowsUpdateScript.buildInstallerScript(
          appPid: 1,
          version: '1.6.0',
          installerPath: r'C:\Temp\setup.exe',
          executablePath: r'C:\Apps\NAI\nai_launcher.exe',
          resultPath: r'C:\Temp\result.json',
          pendingMetadataPath: r'C:\Temp\pending.json',
          startedMarkerPath: r'C:\Temp\started.json',
          logPath: r'C:\Temp\update.log',
        );
        final portable = WindowsUpdateScript.buildPortableScript(
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
        );

        for (final MapEntry(key: kind, value: script) in {
          'installer': installer,
          'portable': portable,
        }.entries) {
          expect(script, contains('Set-SafeWorkingDirectory'), reason: kind);
          expect(script, contains('Set-Location -LiteralPath'), reason: kind);
          expect(
            script,
            contains('[System.Environment]::CurrentDirectory'),
            reason: kind,
          );
          expect(
            script.indexOf('\nSet-SafeWorkingDirectory\n'),
            lessThan(script.indexOf('Wait-ApplicationExit\n')),
            reason: kind,
          );
          expect(script, contains('-WorkingDirectory'), reason: kind);
        }

        expect(
          portable.indexOf('\nSet-SafeWorkingDirectory\n'),
          lessThan(portable.indexOf('Move-Item -LiteralPath \$AppDir')),
        );
        expect(
          portable,
          contains(
            r'Start-Process -FilePath $NewExePath -WorkingDirectory $AppDir',
          ),
        );
        expect(
          portable,
          contains(
            r'Start-Process -FilePath $RestoredExePath -WorkingDirectory $AppDir',
          ),
        );
        expect(
          installer,
          contains(
            r'Start-Process -FilePath $ExePath -WorkingDirectory ([System.IO.Path]::GetDirectoryName($ExePath))',
          ),
        );
      },
    );

    test(
      'portable script succeeds when launched with appDirectory as working directory',
      () async {
        final rootDir = await Directory.systemTemp.createTemp(
          'nai_portable_cwd_test_',
        );
        final appDir = Directory(p.join(rootDir.path, 'app'))..createSync();
        final stagingDir = Directory(p.join(rootDir.path, 'staging'))
          ..createSync();
        final updatesDir = Directory(p.join(rootDir.path, 'updates'))
          ..createSync();
        final doneMarker = File(p.join(rootDir.path, 'restarted_done.txt'));

        addTearDown(() async {
          final deadline = DateTime.now().add(const Duration(seconds: 10));
          while (!await doneMarker.exists() &&
              DateTime.now().isBefore(deadline)) {
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
          await Future<void>.delayed(const Duration(milliseconds: 200));
          for (var attempt = 0; attempt < 10; attempt++) {
            try {
              if (await rootDir.exists()) {
                await rootDir.delete(recursive: true);
              }
              break;
            } catch (_) {
              await Future<void>.delayed(const Duration(milliseconds: 200));
            }
          }
        });

        await File(
          p.join(appDir.path, 'app_files_manifest.json'),
        ).writeAsString(
          jsonEncode({
            'files': ['fake_app.cmd', 'version.txt'],
          }),
        );
        await File(
          p.join(appDir.path, 'fake_app.cmd'),
        ).writeAsString('@echo off\r\nexit /b 0\r\n');
        await File(p.join(appDir.path, 'version.txt')).writeAsString('old');
        await File(p.join(appDir.path, 'user_note.txt')).writeAsString('keep');

        await File(
          p.join(stagingDir.path, 'app_files_manifest.json'),
        ).writeAsString(
          jsonEncode({
            'files': ['fake_app.cmd', 'version.txt'],
          }),
        );
        await File(p.join(stagingDir.path, 'version.txt')).writeAsString('new');
        await File(p.join(stagingDir.path, 'fake_app.cmd')).writeAsString(
          '@echo off\r\n'
          'cd /d "%TEMP%"\r\n'
          'ping -n 6 127.0.0.1 >nul\r\n'
          'echo done>"${doneMarker.path}"\r\n',
        );

        final zipFile = File(p.join(updatesDir.path, 'update.zip'));
        final escapedStagingGlob = p
            .join(stagingDir.path, '*')
            .replaceAll("'", "''");
        final escapedZipPath = zipFile.path.replaceAll("'", "''");
        final zipResult = await Process.run(
          'powershell.exe',
          [
            '-NoProfile',
            '-NonInteractive',
            '-Command',
            "Compress-Archive -Path '$escapedStagingGlob' -DestinationPath '$escapedZipPath' -Force",
          ],
          environment: _windowsPowerShellEnvironment(),
          includeParentEnvironment: false,
        );
        expect(
          zipResult.exitCode,
          0,
          reason: '${zipResult.stdout}\n${zipResult.stderr}',
        );

        final exitedApp = await Process.start('cmd.exe', ['/c', 'exit', '0']);
        final exitedPid = exitedApp.pid;
        expect(await exitedApp.exitCode, 0);

        final resultFile = File(p.join(updatesDir.path, 'update_result.json'));
        final pendingFile = File(
          p.join(updatesDir.path, 'pending_update.json'),
        );
        final startedFile = File(
          p.join(updatesDir.path, 'update_started.json'),
        );
        final logFile = File(p.join(updatesDir.path, 'update_2.0.0.log'));
        await pendingFile.writeAsString('{"version":"2.0.0"}');

        final script = WindowsUpdateScript.buildPortableScript(
          appPid: exitedPid,
          version: '2.0.0',
          zipPath: zipFile.path,
          appDirectory: appDir.path,
          executableName: 'fake_app.cmd',
          proxyExecutableName: 'nai_launcher_mcp.exe',
          extractDirectory: p.join(rootDir.path, '.nai_update_2.0.0'),
          backupDirectory: p.join(rootDir.path, '.nai_backup_2.0.0'),
          resultPath: resultFile.path,
          pendingMetadataPath: pendingFile.path,
          startedMarkerPath: startedFile.path,
          logPath: logFile.path,
        );
        final scriptFile = File(p.join(updatesDir.path, 'update.ps1'));
        await scriptFile.writeAsBytes(
          WindowsUpdateScript.encode(script),
          flush: true,
        );

        // 刻意把工作目录设成 appDir，复现真实双击/快捷方式启动后脚本被继承的场景。
        final runResult = await Process.run(
          'powershell.exe',
          [
            '-NoProfile',
            '-NonInteractive',
            '-ExecutionPolicy',
            'Bypass',
            '-WindowStyle',
            'Hidden',
            '-File',
            scriptFile.path,
          ],
          workingDirectory: appDir.path,
          environment: _windowsPowerShellEnvironment(),
          includeParentEnvironment: false,
        );
        expect(
          runResult.exitCode,
          0,
          reason:
              'stdout=${runResult.stdout}\nstderr=${runResult.stderr}\n'
              'log=${await logFile.exists() ? await logFile.readAsString() : ''}',
        );

        final result =
            jsonDecode(await resultFile.readAsString()) as Map<String, dynamic>;
        expect(result['success'], isTrue);
        expect(
          await File(p.join(appDir.path, 'version.txt')).readAsString(),
          'new',
        );
        expect(
          await File(p.join(appDir.path, 'user_note.txt')).readAsString(),
          'keep',
        );
        expect(await zipFile.exists(), isFalse);
        expect(await pendingFile.exists(), isFalse);
        expect(await startedFile.exists(), isFalse);
      },
      skip: !Platform.isWindows,
    );
  });
}
