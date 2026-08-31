import 'dart:io';

import 'package:nai_launcher/core/cloud_sync/oauth/cloud_drive_oauth_config.dart';
import 'package:nai_launcher/core/cloud_sync/oauth/cloud_drive_oauth_models.dart';

void main(List<String> arguments) {
  final platformName = _option(arguments, '--platform') ?? _hostPlatform();
  final requireConfigured = arguments.contains('--require-configured');
  final providerName = _option(arguments, '--provider');
  final providers = providerName == null
      ? CloudDriveOAuthProvider.values
      : [CloudDriveOAuthProvider.parse(providerName)];
  final platform = CloudDriveOAuthPlatform.values.firstWhere(
    (value) => value.name == platformName,
    orElse: () => CloudDriveOAuthPlatform.unsupported,
  );
  final config = CloudDriveOAuthConfig.fromDartDefines(platform: platform);
  var failed = false;
  for (final provider in providers) {
    final diagnostic = config.diagnose(provider);
    stdout.writeln(diagnostic);
    if (requireConfigured && !diagnostic.isConfigured) failed = true;
  }
  if (failed) exitCode = 2;
}

String? _option(List<String> arguments, String name) {
  final prefix = '$name=';
  for (var index = 0; index < arguments.length; index++) {
    final argument = arguments[index];
    if (argument.startsWith(prefix)) return argument.substring(prefix.length);
    if (argument == name) {
      if (index + 1 >= arguments.length ||
          arguments[index + 1].startsWith('-')) {
        throw FormatException('Missing value for $name');
      }
      return arguments[index + 1];
    }
  }
  return null;
}

String _hostPlatform() {
  if (Platform.isAndroid) return 'android';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isWindows) return 'windows';
  return 'unsupported';
}
