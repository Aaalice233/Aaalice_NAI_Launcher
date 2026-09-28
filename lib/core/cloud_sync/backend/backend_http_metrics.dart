/// Broad endpoint categories keep request metrics useful without exposing URLs,
/// account identifiers, object paths, or provider-specific resource names.
enum BackendHttpEndpointCategory {
  unspecified,
  authentication,
  metadata,
  collection,
  object,
  uploadSession,
  providerApi,
}

/// A redacted, per-attempt view of a backend HTTP request.
///
/// This type intentionally has no URL, headers, body, account, or error-message
/// fields. Byte counts can be null when the transport cannot determine them
/// without inspecting or buffering the payload.
class BackendHttpRequestMetric {
  const BackendHttpRequestMetric({
    required this.method,
    required this.endpointCategory,
    required this.attempt,
    required this.statusCode,
    required this.requestBytes,
    required this.responseBytes,
    required this.retry,
    required this.concurrentRequests,
    required this.maxConcurrentRequests,
    required this.elapsed,
  });

  final String method;
  final BackendHttpEndpointCategory endpointCategory;
  final int attempt;
  final int? statusCode;
  final int? requestBytes;
  final int? responseBytes;

  /// Whether this attempt scheduled another attempt after backoff.
  final bool retry;

  final int concurrentRequests;
  final int maxConcurrentRequests;
  final Duration elapsed;
}

typedef BackendHttpRequestObserver =
    void Function(BackendHttpRequestMetric metric);
