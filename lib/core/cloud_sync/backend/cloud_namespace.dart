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
