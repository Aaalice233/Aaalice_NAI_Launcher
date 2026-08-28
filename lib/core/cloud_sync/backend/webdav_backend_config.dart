import 'cloud_namespace.dart';

/// Persistable, non-secret WebDAV transport policy.
///
/// [allowInsecureHttp] must only be set by an explicit local-user choice.
class WebDavBackendConfig {
  WebDavBackendConfig({
    required this.baseUri,
    this.namespace = 'aaalice-sync',
    this.allowInsecureHttp = false,
  }) {
    validate();
  }

  factory WebDavBackendConfig.fromJson(Map<String, Object?> json) {
    return WebDavBackendConfig(
      baseUri: Uri.parse(json['baseUri'] as String),
      namespace: json['namespace'] as String? ?? 'aaalice-sync',
      allowInsecureHttp: json['allowInsecureHttp'] as bool? ?? false,
    );
  }

  final Uri baseUri;
  final String namespace;
  final bool allowInsecureHttp;

  Map<String, Object?> toJson() => {
    'baseUri': baseUri.toString(),
    'namespace': namespace,
    'allowInsecureHttp': allowInsecureHttp,
  };

  void validate() {
    CloudNamespace.validate(namespace);
    if (!baseUri.hasAuthority || baseUri.host.isEmpty) {
      throw ArgumentError.value(baseUri, 'baseUri', 'Absolute URL required');
    }
    if (baseUri.userInfo.isNotEmpty ||
        baseUri.hasQuery ||
        baseUri.hasFragment) {
      throw ArgumentError.value(baseUri, 'baseUri', 'Unsafe WebDAV URL');
    }
    final scheme = baseUri.scheme.toLowerCase();
    if (scheme != 'https' && !(scheme == 'http' && allowInsecureHttp)) {
      throw ArgumentError.value(
        baseUri,
        'baseUri',
        'HTTPS required unless insecure HTTP is explicitly allowed',
      );
    }
  }
}
