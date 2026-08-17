import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/windows_update_script.dart';

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
          extractDirectory: r'D:\Apps\.nai_update_1.6.0',
          backupDirectory: r'D:\Apps\.nai_backup_1.6.0',
          resultPath: r'C:\Temp\result.json',
          pendingMetadataPath: r'C:\Temp\pending.json',
          logPath: r'C:\Temp\update.log',
        );

        expect(script, contains('\$AppPid = 1234'));
        expect(script, contains('Expand-Archive'));
        expect(script, contains(r"'D:\Apps\NAI'"));
        expect(script, contains("'app_files_manifest.json'"));
        expect(script, contains('\$CanPreserveUserFiles = \$false'));
        expect(script, contains('if (\$CanPreserveUserFiles)'));
        expect(script, contains('Move-Item -LiteralPath \$AppDir'));
        expect(script, contains('Copy-Item -LiteralPath \$_.FullName'));
        expect(script, contains('Previous application version restored.'));
        expect(script, contains('Updated application exited immediately'));
        expect(script, isNot(contains('/MIR')));
      },
    );

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
            logPath: r'C:\Temp\update.log',
          ),
          WindowsUpdateScript.buildPortableScript(
            appPid: 1,
            version: '1.6.0',
            zipPath: r'C:\Temp\update.zip',
            appDirectory: r'D:\Apps\NAI',
            executableName: 'nai_launcher.exe',
            extractDirectory: r'D:\Apps\.nai_update_1.6.0',
            backupDirectory: r'D:\Apps\.nai_backup_1.6.0',
            resultPath: r'C:\Temp\result.json',
            pendingMetadataPath: r'C:\Temp\pending.json',
            logPath: r'C:\Temp\update.log',
          ),
        ];

        for (var index = 0; index < scripts.length; index++) {
          final file = File('${tempDir.path}/script_$index.ps1');
          await file.writeAsString(scripts[index]);
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

    test('escapes single quotes in paths for PowerShell', () {
      final script = WindowsUpdateScript.buildInstallerScript(
        appPid: 1,
        version: '1.6.0',
        installerPath: r"C:\Temp\it's.exe",
        executablePath: r'C:\Apps\nai_launcher.exe',
        resultPath: r'C:\Temp\result.json',
        pendingMetadataPath: r'C:\Temp\pending.json',
        logPath: r'C:\Temp\update.log',
      );

      expect(script, contains(r"'C:\Temp\it''s.exe'"));
    });
  });
}
