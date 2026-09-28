const defaultCloudSyncConfiguredPath = 'aaalice-sync';
const cloudSyncV3NamespaceSuffix = '-v3';
const defaultCloudSyncV3Namespace =
    '$defaultCloudSyncConfiguredPath$cloudSyncV3NamespaceSuffix';

String cloudSyncV3Namespace(String configuredPath) {
  final path = configuredPath.isEmpty
      ? defaultCloudSyncConfiguredPath
      : configuredPath;
  CloudNamespace.validate(path);
  final segments = path.split('/');
  segments[segments.length - 1] = '${segments.last}$cloudSyncV3NamespaceSuffix';
  final namespace = segments.join('/');
  CloudNamespace.validate(namespace);
  return namespace;
}

class CloudNamespace {
  const CloudNamespace._();

  static void validate(String value) {
    if (value.isEmpty || value.startsWith('/') || value.contains('\\')) {
      throw ArgumentError.value(value, 'namespace', 'Invalid relative path');
    }
    final segments = value.split('/');
    if (segments.any(
      (segment) =>
          segment.isEmpty ||
          segment == '.' ||
          segment == '..' ||
          !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$').hasMatch(segment),
    )) {
      throw ArgumentError.value(value, 'namespace', 'Invalid relative path');
    }
  }
}
