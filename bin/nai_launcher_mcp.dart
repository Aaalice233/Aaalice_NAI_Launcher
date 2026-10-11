import 'dart:io';

import 'package:nai_launcher/core/mcp/cli/mcp_cli.dart';

Future<void> main(List<String> args) async {
  exit(
    await runNaiLauncherMcpCli(
      args,
      input: stdin,
      output: stdout,
      diagnostics: stderr,
    ),
  );
}
