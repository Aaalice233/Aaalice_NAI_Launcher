import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/mcp/mcp_cli_path.dart';

void main() {
  test('Windows resolves the proxy beside the executable with .exe', () {
    expect(
      resolveBundledMcpCliPath(
        executablePath: r'C:\Program Files\Aaalice\nai_launcher.exe',
        isWindows: true,
      ),
      r'C:\Program Files\Aaalice\nai_launcher_mcp.exe',
    );
  });

  test('macOS resolves the proxy inside Contents/MacOS without a suffix', () {
    expect(
      resolveBundledMcpCliPath(
        executablePath:
            '/Applications/Aaalice NAI Launcher.app/Contents/MacOS/'
            'Aaalice NAI Launcher',
        isWindows: false,
      ),
      '/Applications/Aaalice NAI Launcher.app/Contents/MacOS/nai_launcher_mcp',
    );
  });

  test('the host platform decides the suffix when none is given', () {
    final resolved = resolveBundledMcpCliPath(
      executablePath: Platform.isWindows
          ? r'C:\app\nai_launcher.exe'
          : '/app/nai_launcher',
    );

    expect(
      resolved.endsWith(Platform.isWindows ? '.exe' : 'nai_launcher_mcp'),
      isTrue,
      reason: resolved,
    );
  });

  test('existence follows the resolved path', () async {
    final directory = await Directory.systemTemp.createTemp('mcp_cli_path_');
    addTearDown(() => directory.delete(recursive: true));
    final host = File(
      '${directory.path}${Platform.pathSeparator}nai_launcher'
      '${Platform.isWindows ? '.exe' : ''}',
    );
    await host.writeAsString('host');

    expect(bundledMcpCliExists(executablePath: host.path), isFalse);

    await File(
      resolveBundledMcpCliPath(executablePath: host.path),
    ).writeAsString('proxy');

    expect(bundledMcpCliExists(executablePath: host.path), isTrue);
  });
}
