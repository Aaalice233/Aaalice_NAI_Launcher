import '../../models/gallery/nai_image_metadata.dart';

class MetadataParseResult {
  final bool success;
  final NaiImageMetadata? metadata;
  final String? sourceFormat;
  final String? rawData;
  final List<String> triedParsers;
  final String? errorMessage;
  final Duration? parseTime;
  final int? bytesRead;

  const MetadataParseResult({
    this.success = false,
    this.metadata,
    this.sourceFormat,
    this.rawData,
    this.triedParsers = const [],
    this.errorMessage,
    this.parseTime,
    this.bytesRead,
  });

  factory MetadataParseResult.failed(
    List<String> triedParsers,
    String error, {
    Duration? parseTime,
    int? bytesRead,
  }) => MetadataParseResult(
    triedParsers: triedParsers,
    errorMessage: error,
    parseTime: parseTime,
    bytesRead: bytesRead,
  );

  factory MetadataParseResult.success(
    NaiImageMetadata metadata,
    String sourceFormat,
    String rawData,
    List<String> triedParsers, {
    Duration? parseTime,
    int? bytesRead,
  }) => MetadataParseResult(
    success: true,
    metadata: metadata,
    sourceFormat: sourceFormat,
    rawData: rawData,
    triedParsers: triedParsers,
    parseTime: parseTime,
    bytesRead: bytesRead,
  );
}

class ParseStatistics {
  int totalAttempts = 0;
  int successfulParses = 0;
  int failedParses = 0;
  int gradualReadAttempts = 0;
  int gradualReadSuccesses = 0;
  final Map<String, int> parserSuccessCounts = {};
  final Map<String, int> parserFailureCounts = {};
  Duration totalParseTime = Duration.zero;

  Map<String, dynamic> toMap() => {
    'totalAttempts': totalAttempts,
    'successfulParses': successfulParses,
    'failedParses': failedParses,
    'gradualReadAttempts': gradualReadAttempts,
    'gradualReadSuccesses': gradualReadSuccesses,
    'parserSuccessCounts': parserSuccessCounts,
    'parserFailureCounts': parserFailureCounts,
    'averageParseTimeMs': totalAttempts > 0
        ? totalParseTime.inMilliseconds ~/ totalAttempts
        : 0,
  };

  void reset() {
    totalAttempts = 0;
    successfulParses = 0;
    failedParses = 0;
    gradualReadAttempts = 0;
    gradualReadSuccesses = 0;
    parserSuccessCounts.clear();
    parserFailureCounts.clear();
    totalParseTime = Duration.zero;
  }
}
