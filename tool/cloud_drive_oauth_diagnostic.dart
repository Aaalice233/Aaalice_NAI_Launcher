import 'dart:io';

import 'package:nai_launcher/core/cloud_sync/oauth/cloud_drive_oauth_config.dart';
import 'package:nai_launcher/core/cloud_sync/oauth/cloud_drive_oauth_models.dart';

void main(List<String> arguments) {
  final platformName = _option(arguments, '--platform') ?? _hostPlatform();
  final requireConfigured = arguments.contains('--require-configured');
  final platform = CloudDriveOAuthPlatform.values.firstWhere(
    (value) => value.name == platformName,
    orElse: () => CloudDriveOAuthPlatform.unsupported,
  );
  final config = CloudDriveOAuthConfig.fromDartDefines(platform: platform);
  var failed = false;
  for (final provider in CloudDriveOAuthProvider.values) {
    final diagnostic = config.diagnose(provider);
    stdout.writeln(diagnostic);
    if (requireConfigured && !diagnostic.isConfigured) failed = true;
  }
  if (failed) exitCode = 2;
}

String? _option(List<String> arguments, String name) {
  final prefix = '$name=';
  for (final argument in arguments) {
    if (argument.startsWith(prefix)) return argument.substring(prefix.length);
  }
  return null;
}

String _hostPlatform() {
  if (Platform.isAndroid) return 'android';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isWindows) return 'windows';
  return 'unsupported';
}
