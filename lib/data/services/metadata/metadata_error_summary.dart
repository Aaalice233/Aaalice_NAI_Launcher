/// Describes a metadata parse failure for logs. Exception text can quote the
/// prompt being parsed (FormatException sources, NoSuchMethodError receivers),
/// so only the type and position survive.
String metadataErrorSummary(Object error) {
  if (error is! FormatException) return '${error.runtimeType}';
  final source = error.source;
  final length = switch (source) {
    String() => source.length,
    List() => source.length,
    _ => null,
  };
  return 'FormatException(offset: ${error.offset}, length: $length)';
}
