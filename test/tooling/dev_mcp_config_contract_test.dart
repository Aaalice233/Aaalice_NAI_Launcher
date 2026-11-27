import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

bool _hasPwsh() {
  try {
    final result = Process.runSync('pwsh', ['--version']);
    return result.exitCode == 0;
  } on ProcessException {
    return false;
  }
}

String _normalizePath(String path) {
  final normalized = path.replaceAll('\\', '/');
  return Platform.isWindows ? normalized.toLowerCase() : normalized;
}

String _encodePropertiesPath(String path) {
  return path.replaceAll('\\', r'\\').replaceAll(':', r'\:');
}

void main() {
  test('project-level Dart MCP configs exist and share start_dart_mcp.ps1', () {
    final scriptFile = File('scripts/start_dart_mcp.ps1');
    expect(scriptFile.existsSync(), isTrue);

    final codexConfig = File('.codex/config.toml').readAsStringSync();
    expect(codexConfig, contains('[mcp_servers.dart]'));
    expect(codexConfig, contains('scripts/start_dart_mcp.ps1'));

    final pluginManifest =
        jsonDecode(
              File('.agents/plugins/dart-mcp/plugin.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    expect(pluginManifest['name'], 'dart-mcp');

    for (final path in [
      '.agents/plugins/dart-mcp/mcp_config.json',
      '.mcp.json',
    ]) {
      final configFile = File(path);
      expect(configFile.existsSync(), isTrue, reason: 'Missing $path');

      final decoded =
          jsonDecode(configFile.readAsStringSync()) as Map<String, dynamic>;
      final servers = decoded['mcpServers'] as Map<String, dynamic>?;
      expect(servers, isNotNull, reason: '$path should define mcpServers');

      final dartServer = servers!['dart'] as Map<String, dynamic>?;
      expect(
        dartServer,
        isNotNull,
        reason: '$path should define mcpServers.dart',
      );
      expect(dartServer!['command'], 'pwsh');

      final args = (dartServer['args'] as List<dynamic>).cast<String>();
      expect(
        args.join(' '),
        contains('scripts/start_dart_mcp.ps1'),
        reason: '$path should launch scripts/start_dart_mcp.ps1',
      );
      expect(
        args.join(' '),
        isNot(matches(RegExp(r'[A-Za-z]:[/\\]|/Users/'))),
        reason: '$path must remain machine-independent',
      );
    }
  });

  test('PowerShell dev scripts do not pass bare if expressions as arguments', () {
    final bareIfArgumentPattern = RegExp(r'(?<!\$)\(\s*if\s*\(');
    for (final path in [
      '.agents/skills/aaalice-dev-sessions/scripts/windows_runner.ps1',
      '.agents/skills/aaalice-dev-sessions/scripts/android_runner.ps1',
      'scripts/start_dart_mcp.ps1',
    ]) {
      final content = File(path).readAsStringSync();
      expect(
        bareIfArgumentPattern.hasMatch(content),
        isFalse,
        reason:
            '$path must not pass bare (if (...)) statements as command arguments',
      );
    }
  });

  test(
    'runner scripts resolve Flutter and Dart commands from local.properties',
    () {
      final hasPwsh = _hasPwsh();
      if (Platform.isWindows) {
        expect(hasPwsh, isTrue, reason: 'pwsh must be available on Windows');
      } else if (!hasPwsh) {
        markTestSkipped('pwsh is not available in this environment');
        return;
      }

      final tempRoot = Directory.systemTemp.createTempSync('runner_sdk_test_');
      addTearDown(() {
        if (tempRoot.existsSync()) {
          tempRoot.deleteSync(recursive: true);
        }
      });

      final fakeRepo = Directory('${tempRoot.path}/repo')..createSync();
      final androidDir = Directory('${fakeRepo.path}/android')..createSync();
      final fakeSdk = Directory('${tempRoot.path}/flutter_sdk')..createSync();
      final sdkBin = Directory('${fakeSdk.path}/bin')..createSync();
      final dartSdkBin = Directory('${fakeSdk.path}/bin/cache/dart-sdk/bin')
        ..createSync(recursive: true);

      final flutterName = Platform.isWindows ? 'flutter.bat' : 'flutter';
      final dartBinName = Platform.isWindows ? 'dart.bat' : 'dart';
      final dartExeName = Platform.isWindows ? 'dart.exe' : 'dart';

      final flutterBinFile = File('${sdkBin.path}/$flutterName')
        ..writeAsStringSync('stub');
      final dartBinFile = File('${sdkBin.path}/$dartBinName')
        ..writeAsStringSync('stub');
      final dartExeFile = File('${dartSdkBin.path}/$dartExeName');

      final canonicalSdkPath = fakeSdk.resolveSymbolicLinksSync();
      File('${androidDir.path}/local.properties').writeAsStringSync(
        'flutter.sdk=${_encodePropertiesPath(canonicalSdkPath)}\n',
      );

      const pwshCommand = r'''
$ErrorActionPreference = 'Stop'
$repoRoot = $env:TEST_REPO_ROOT
$env:FLUTTER_SDK = $null
$env:FLUTTER_CMD = $null
$env:DART_CMD = $null
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($env:TEST_RUNNER_SCRIPT, [ref]$tokens, [ref]$errors)
if ($errors.Count -gt 0) {
  throw ('Parse errors: ' + ($errors -join '; '))
}
$functions = $ast.FindAll({
  param($node)
  $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
    $node.Name -in @('Resolve-ConfiguredFlutterSdk', 'Resolve-ToolCommand')
}, $true)
if ($functions.Count -ne 2) {
  throw ('Expected 2 functions, found ' + $functions.Count)
}
foreach ($fn in $functions) {
  . ([ScriptBlock]::Create($fn.Extent.Text))
}
$flutterPath = Resolve-ToolCommand -EnvironmentVariable 'FLUTTER_CMD' -CommandName 'flutter'
$dartSdkPath = Resolve-ToolCommand -EnvironmentVariable 'DART_CMD' -CommandName 'dart'
Remove-Item -LiteralPath $env:TEST_DART_SDK_EXE -Force
$dartBinPath = Resolve-ToolCommand -EnvironmentVariable 'DART_CMD' -CommandName 'dart'
[pscustomobject]@{
  flutter = $flutterPath
  dartSdk = $dartSdkPath
  dartBin = $dartBinPath
} | ConvertTo-Json -Compress
''';

      for (final scriptPath in [
        '.agents/skills/aaalice-dev-sessions/scripts/windows_runner.ps1',
        '.agents/skills/aaalice-dev-sessions/scripts/android_runner.ps1',
      ]) {
        dartExeFile.writeAsStringSync('stub');

        final runnerFile = File(scriptPath);
        expect(runnerFile.existsSync(), isTrue, reason: 'Missing $scriptPath');

        final result = Process.runSync(
          'pwsh',
          ['-NoProfile', '-Command', pwshCommand],
          environment: {
            'TEST_REPO_ROOT': fakeRepo.resolveSymbolicLinksSync(),
            'TEST_RUNNER_SCRIPT': runnerFile.absolute.path,
            'TEST_DART_SDK_EXE': dartExeFile.resolveSymbolicLinksSync(),
          },
        );

        expect(
          result.exitCode,
          0,
          reason:
              'Failed for $scriptPath:\nstdout: ${result.stdout}\nstderr: ${result.stderr}',
        );

        final resolved =
            jsonDecode((result.stdout as String).trim())
                as Map<String, dynamic>;
        expect(
          _normalizePath(resolved['flutter'] as String),
          _normalizePath(flutterBinFile.resolveSymbolicLinksSync()),
          reason: '$scriptPath should resolve flutter executable',
        );
        expect(
          _normalizePath(resolved['dartSdk'] as String),
          _normalizePath(
            '${fakeSdk.resolveSymbolicLinksSync()}/bin/cache/dart-sdk/bin/$dartExeName',
          ),
          reason: '$scriptPath should prefer cached dart-sdk executable',
        );
        expect(
          _normalizePath(resolved['dartBin'] as String),
          _normalizePath(dartBinFile.resolveSymbolicLinksSync()),
          reason: '$scriptPath should fall back to sdk/bin/$dartBinName',
        );
      }
    },
  );
}
