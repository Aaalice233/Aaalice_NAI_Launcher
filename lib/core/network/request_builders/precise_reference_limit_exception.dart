class PreciseReferenceLimitException implements Exception {
  const PreciseReferenceLimitException();

  static const maxReferences = 16;
  static const errorCode = 'GENERATION_ERROR_PRECISE_REFERENCE_LIMIT';

  static bool matches(Object? error) =>
      error is PreciseReferenceLimitException ||
      (error != null && error.toString().contains(errorCode));

  @override
  String toString() => '$errorCode|$maxReferences';
}
