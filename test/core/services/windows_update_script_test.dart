import 'package:nai_launcher/core/services/windows_update_script.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WindowsUpdateScript', () {
    test('installer script waits for app exit before running installer', () {
      final script = WindowsUpdateScript.buildInstallerScript(
        appPid: 4321,
        installerPath: r'C:\Temp\setup.exe',
      );

      expect(script, contains('\$AppPid = 4321'));
      expect(script, contains('Wait-Process -Id \$AppPid'));
      expect(script, contains(r"'C:\Temp\setup.exe'"));
      expect(script, contains("'/S'"));
      // 安装器运行结束后清理自身与安装包
      expect(script, contains('Remove-Item -LiteralPath \$InstallerPath'));
      expect(script, contains('Remove-Item -LiteralPath \$ScriptPath'));
    });

    test('portable script extracts, overwrites app dir and restarts', () {
      final script = WindowsUpdateScript.buildPortableScript(
        appPid: 1234,
        zipPath: r'C:\Temp\update.zip',
        appDirectory: r'D:\Apps\NAI',
        executablePath: r'D:\Apps\NAI\nai_launcher.exe',
        extractDirectory: r'C:\Temp\extract_1.4.0',
      );

      expect(script, contains('\$AppPid = 1234'));
      expect(script, contains('Wait-Process -Id \$AppPid'));
      expect(script, contains('Expand-Archive'));
      expect(script, contains(r"'D:\Apps\NAI'"));
      expect(script, contains('Start-Process -FilePath \$ExePath'));
      // 覆盖式复制而非删除式镜像，避免误删用户文件
      expect(script, contains('Copy-Item'));
      expect(script, isNot(contains('/MIR')));
    });

    test('escapes single quotes in paths for PowerShell', () {
      final script = WindowsUpdateScript.buildInstallerScript(
        appPid: 1,
        installerPath: r"C:\Temp\it's.exe",
      );

      expect(script, contains(r"'C:\Temp\it''s.exe'"));
    });
  });
}
