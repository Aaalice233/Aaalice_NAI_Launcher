import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../agent/private_data_guard.dart';
import '../constants/app_version.dart';
import '../utils/app_logger.dart';
import '../utils/fatal_diagnostics.dart';
import 'diagnostic_agent_audit.dart';
import 'file_export_service.dart';

final diagnosticLogExportServiceProvider = Provider<DiagnosticLogExportService>(
  (ref) => DiagnosticLogExportService(),
);

enum DiagnosticLogExportStatus { exported, cancelled, noLogs }

class DiagnosticLogExportResult {
  const DiagnosticLogExportResult(this.status);

  final DiagnosticLogExportStatus status;
}

typedef DiagnosticArchiveExporter =
    Future<bool> Function(
      String sourcePath,
      String fileName,
      String dialogTitle,
    );

/// Builds a privacy-sanitized diagnostics archive for user-initiated export.
class DiagnosticLogExportService {
  DiagnosticLogExportService({
    Future<List<File>> Function()? loadLogFiles,
    Future<List<File>> Function()? loadCrashFiles,
    Future<File?> Function()? loadAgentAuditFile,
    Future<void> Function()? flushLogs,
    DiagnosticArchiveExporter? exportArchive,
    DateTime Function()? now,
    String Function()? diagnosticsMetadata,
    int maxPerFileBytes = defaultMaxPerFileBytes,
    int maxTotalSourceBytes = defaultMaxTotalSourceBytes,
  }) : assert(maxPerFileBytes > 0),
       assert(maxTotalSourceBytes > 0),
       _loadLogFiles = loadLogFiles ?? AppLogger.getLogFiles,
       _loadCrashFiles = loadCrashFiles ?? _defaultCrashFiles,
       _loadAgentAuditFile = loadAgentAuditFile ?? _defaultAgentAuditFile,
       _flushLogs = flushLogs ?? AppLogger.flush,
       _exportArchive = exportArchive ?? _defaultExportArchive,
       _now = now ?? DateTime.now,
       _diagnosticsMetadata =
           diagnosticsMetadata ?? _defaultDiagnosticsMetadata,
       _maxPerFileBytes = maxPerFileBytes,
       _maxTotalSourceBytes = maxTotalSourceBytes;

  static const int maxSourceFiles = 13;
  static const int defaultMaxPerFileBytes = 32 * 1024 * 1024;
  static const int defaultMaxTotalSourceBytes = 96 * 1024 * 1024;

  final Future<List<File>> Function() _loadLogFiles;
  final Future<List<File>> Function() _loadCrashFiles;
  final Future<File?> Function() _loadAgentAuditFile;
  final Future<void> Function() _flushLogs;
  final DiagnosticArchiveExporter _exportArchive;
  final DateTime Function() _now;
  final String Function() _diagnosticsMetadata;
  final int _maxPerFileBytes;
  final int _maxTotalSourceBytes;

  static Future<void> cleanupStaleTemporaryFiles({
    Duration minimumAge = Duration.zero,
    DateTime? now,
  }) async {
    final temporaryDirectory = await getTemporaryDirectory();
    final exportDirectory = Directory(
      p.join(temporaryDirectory.path, 'exports'),
    );
    if (!await exportDirectory.exists()) return;

    final cutoff = (now ?? DateTime.now()).subtract(minimumAge);
    await for (final entity in exportDirectory.list(followLinks: false)) {
      final name = p.basename(entity.path);
      final isDiagnosticExport = name.contains('_nai-launcher-diagnostics-');
      if (!isDiagnosticExport) continue;
      try {
        final modified = await entity.stat().then((stat) => stat.modified);
        if (modified.isAfter(cutoff)) continue;
        await entity.delete(recursive: entity is Directory);
      } on FileSystemException {
        // A locked export is either still in use or will be retried next launch.
      }
    }
  }

  Future<DiagnosticLogExportResult> export({
    required String dialogTitle,
  }) async {
    await _flushLogs();
    final files = await _collectReadableFiles();
    final auditFile = await _loadAgentAuditFile();
    final auditPath = auditFile != null && await auditFile.exists()
        ? auditFile.path
        : null;
    if (auditPath != null) files.insert(0, auditFile!);
    if (files.isEmpty) {
      return const DiagnosticLogExportResult(DiagnosticLogExportStatus.noLogs);
    }

    final timestamp = _now();
    final fileName =
        'nai-launcher-diagnostics-${_fileTimestamp(timestamp)}.zip';
    final exported = await FileExportService.withTemporaryOutput<bool>(
      fileName: fileName,
      action: (archivePath) async {
        final stagingDirectory = Directory('$archivePath.contents');
        await stagingDirectory.create(recursive: true);
        try {
          final sourcePaths = files.map((file) => file.path).toList();
          final diagnosticsMetadata = _diagnosticsMetadata();
          final fileLoggingEnabled = AppLogger.fileLoggingEnabled;
          await Isolate.run(
            () => _buildArchive(
              archivePath: archivePath,
              stagingDirectoryPath: stagingDirectory.path,
              sourcePaths: sourcePaths,
              auditPath: auditPath,
              createdAt: timestamp,
              diagnosticsMetadata: diagnosticsMetadata,
              fileLoggingEnabled: fileLoggingEnabled,
              maxPerFileBytes: _maxPerFileBytes,
              maxTotalSourceBytes: _maxTotalSourceBytes,
            ),
          );
          return _exportArchive(archivePath, fileName, dialogTitle);
        } finally {
          if (await stagingDirectory.exists()) {
            await stagingDirectory.delete(recursive: true);
          }
        }
      },
    );

    return DiagnosticLogExportResult(
      exported
          ? DiagnosticLogExportStatus.exported
          : DiagnosticLogExportStatus.cancelled,
    );
  }

  Future<List<File>> _collectReadableFiles() async {
    final candidates = <File>[
      ...await _loadLogFiles(),
      ...await _loadCrashFiles(),
    ];
    final files = <File>[];
    final seenPaths = <String>{};
    for (final file in candidates) {
      final absolutePath = file.absolute.path;
      if (seenPaths.add(absolutePath) && await file.exists()) {
        files.add(file);
      }
    }
    files.sort(
      (left, right) =>
          right.lastModifiedSync().compareTo(left.lastModifiedSync()),
    );
    return files.take(maxSourceFiles).toList();
  }

  static Future<void> _buildArchive({
    required String archivePath,
    required String stagingDirectoryPath,
    required List<String> sourcePaths,
    required String? auditPath,
    required DateTime createdAt,
    required String diagnosticsMetadata,
    required bool fileLoggingEnabled,
    required int maxPerFileBytes,
    required int maxTotalSourceBytes,
  }) async {
    final stagingDirectory = Directory(stagingDirectoryPath);
    final encoder = ZipFileEncoder();
    var encoderOpen = false;
    try {
      encoder.create(archivePath, level: ZipFileEncoder.GZIP);
      encoderOpen = true;

      final usedNames = <String>{};
      final includedNames = <String>[];
      final truncatedNames = <String>[];
      var remainingSourceBytes = maxTotalSourceBytes;
      var omittedLogCount = 0;
      for (final sourcePath in sourcePaths) {
        if (remainingSourceBytes <= 0) {
          omittedLogCount++;
          continue;
        }
        final sourceFile = File(sourcePath);
        final archiveName = _uniqueFileName(
          p.basename(sourceFile.path),
          usedNames,
        );
        final sanitizedFile = File(p.join(stagingDirectory.path, archiveName));
        try {
          final sourceLength = await sourceFile.length();
          final archivedBytes = [
            sourceLength,
            maxPerFileBytes,
            remainingSourceBytes,
          ].reduce((left, right) => left < right ? left : right);
          final wasTruncated = archivedBytes < sourceLength;
          await _writeSanitizedCopy(
            sourceFile,
            sanitizedFile,
            maxBytes: archivedBytes,
            snapshotLength: sourceLength,
            wasTruncated: wasTruncated,
            isAgentAudit: sourcePath == auditPath,
          );
          remainingSourceBytes -= archivedBytes;
          await encoder.addFile(
            sanitizedFile,
            'logs/$archiveName',
            ZipFileEncoder.GZIP,
          );
          includedNames.add(archiveName);
          if (wasTruncated) truncatedNames.add(archiveName);
        } finally {
          if (await sanitizedFile.exists()) {
            await sanitizedFile.delete();
          }
        }
      }

      final metadataFile = File(
        p.join(stagingDirectory.path, 'diagnostics.json'),
      );
      final metadata = <String, Object>{
        'schemaVersion': 1,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'environment': _sanitize(diagnosticsMetadata),
        'fileLoggingEnabled': fileLoggingEnabled,
        'logs': includedNames,
        'truncatedLogs': truncatedNames,
        'omittedLogCount': omittedLogCount,
      };
      await metadataFile.writeAsString(
        const JsonEncoder.withIndent('  ').convert(metadata),
        encoding: utf8,
        flush: true,
      );
      await encoder.addFile(
        metadataFile,
        'diagnostics.json',
        ZipFileEncoder.GZIP,
      );

      await encoder.close();
      encoderOpen = false;
    } finally {
      if (encoderOpen) {
        await encoder.close();
      }
    }
  }

  static Future<void> _writeSanitizedCopy(
    File source,
    File target, {
    required int maxBytes,
    required int snapshotLength,
    required bool wasTruncated,
    required bool isAgentAudit,
  }) async {
    final sink = target.openWrite(encoding: utf8);
    final startOffset = snapshotLength > maxBytes
        ? snapshotLength - maxBytes
        : 0;
    var insidePrivateKey =
        !isAgentAudit &&
        await _privateKeyOpenNearOffset(source, startOffset, snapshotLength);
    var discardFirstPartialLine = await _startsMidLine(source, startOffset);
    try {
      if (wasTruncated) {
        sink.writeln(
          isAgentAudit
              ? jsonEncode({'diagnostic': 'older_audit_content_omitted'})
              : '[OLDER LOG CONTENT OMITTED]',
        );
      }
      await for (final line
          in source
              .openRead(startOffset, snapshotLength)
              .transform(const Utf8Decoder(allowMalformed: true))
              .transform(const LineSplitter())) {
        if (discardFirstPartialLine) {
          discardFirstPartialLine = false;
          continue;
        }
        if (isAgentAudit) {
          sink.writeln(DiagnosticAgentAudit.sanitizeLine(line));
          continue;
        }
        if (_privateKeyBegin.hasMatch(line)) {
          insidePrivateKey = true;
          sink.writeln('[REDACTED PRIVATE KEY]');
          continue;
        }
        if (insidePrivateKey) {
          if (_privateKeyEnd.hasMatch(line)) {
            insidePrivateKey = false;
          }
          continue;
        }
        sink.writeln(_sanitize(line));
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
  }

  static Future<bool> _startsMidLine(File source, int offset) async {
    if (offset <= 0) return false;
    final reader = await source.open();
    try {
      await reader.setPosition(offset - 1);
      final previousByte = await reader.readByte();
      return previousByte != 0x0a && previousByte != 0x0d;
    } finally {
      await reader.close();
    }
  }

  static Future<bool> _privateKeyOpenNearOffset(
    File source,
    int offset,
    int snapshotLength,
  ) async {
    if (offset <= 0) return false;

    const overlapCharacters = 128;
    final scanEnd = offset + overlapCharacters < snapshotLength
        ? offset + overlapCharacters
        : snapshotLength;
    var carry = '';
    var totalCharacters = 0;
    var lastMarkerStart = -1;
    var insidePrivateKey = false;

    await for (final bytes in source.openRead(0, scanEnd)) {
      // Marker text is ASCII; Latin-1 keeps character offsets equal to bytes.
      final decoded = latin1.decode(bytes);
      final combined = '$carry$decoded';
      final combinedStart = totalCharacters - carry.length;
      for (final match in _privateKeyMarker.allMatches(combined)) {
        final absoluteStart = combinedStart + match.start;
        if (absoluteStart >= offset || absoluteStart <= lastMarkerStart) {
          continue;
        }
        lastMarkerStart = absoluteStart;
        insidePrivateKey = match
            .group(0)!
            .toUpperCase()
            .startsWith('-----BEGIN');
      }
      totalCharacters += decoded.length;
      carry = combined.length <= overlapCharacters
          ? combined
          : combined.substring(combined.length - overlapCharacters);
    }
    return insidePrivateKey;
  }

  static final RegExp _privateKeyMarker = RegExp(
    r'-----(?:BEGIN|END) (?:[A-Z0-9 ]+ )?PRIVATE KEY(?: BLOCK)?-----',
    caseSensitive: false,
  );

  static final RegExp _privateKeyBegin = RegExp(
    r'-----BEGIN (?:[A-Z0-9 ]+ )?PRIVATE KEY(?: BLOCK)?-----',
    caseSensitive: false,
  );
  static final RegExp _privateKeyEnd = RegExp(
    r'-----END (?:[A-Z0-9 ]+ )?PRIVATE KEY(?: BLOCK)?-----',
    caseSensitive: false,
  );

  static String _sanitize(String value) {
    final credentialsRedacted = FatalDiagnostics.redactSensitiveText(value);
    final pathsRedacted = PrivateDataGuard.redactAbsolutePaths(
      credentialsRedacted,
    );
    if (PrivateDataGuard.detect(pathsRedacted) != null) {
      return '[REDACTED SENSITIVE LOG LINE]';
    }
    return pathsRedacted;
  }

  static String _uniqueFileName(String requested, Set<String> used) {
    if (used.add(requested)) return requested;
    final extension = p.extension(requested);
    final baseName = p.basenameWithoutExtension(requested);
    var suffix = 2;
    while (true) {
      final candidate = '$baseName-$suffix$extension';
      if (used.add(candidate)) return candidate;
      suffix++;
    }
  }

  static Future<List<File>> _defaultCrashFiles() async {
    final logDirectory = AppLogger.logDirectory;
    if (logDirectory == null || logDirectory.isEmpty) return const [];
    final directory = Directory(p.join(logDirectory, 'crash_diagnostics'));
    if (!await directory.exists()) return const [];

    final files = await directory
        .list(followLinks: false)
        .where((entry) => entry is File && p.extension(entry.path) == '.log')
        .cast<File>()
        .toList();
    files.sort((left, right) {
      final leftTime = left.lastModifiedSync();
      final rightTime = right.lastModifiedSync();
      return rightTime.compareTo(leftTime);
    });
    return files.take(10).toList(growable: false);
  }

  static Future<File?> _defaultAgentAuditFile() async {
    final support = await getApplicationSupportDirectory();
    return File(p.join(support.path, 'agent', 'audit-v1.jsonl'));
  }

  static Future<bool> _defaultExportArchive(
    String sourcePath,
    String fileName,
    String dialogTitle,
  ) async {
    final destination = await FileExportService.saveFileFromPath(
      sourcePath: sourcePath,
      fileName: fileName,
      dialogTitle: dialogTitle,
      mimeType: 'application/zip',
      allowedExtensions: const ['zip'],
    );
    return destination != null;
  }

  static String _defaultDiagnosticsMetadata() {
    return [
      'app=${AppVersion.fullVersion}+${AppVersion.buildNumber}',
      'platform=${Platform.operatingSystem}',
      'osVersion=${Platform.operatingSystemVersion}',
      'locale=${Platform.localeName}',
    ].join('\n');
  }

  static String _fileTimestamp(DateTime value) {
    String two(int part) => part.toString().padLeft(2, '0');
    return '${value.year}${two(value.month)}${two(value.day)}-'
        '${two(value.hour)}${two(value.minute)}${two(value.second)}';
  }
}
