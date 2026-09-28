import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'models.dart';

enum JournalOperation { synchronize, uploadLocal, restore, downloadRemote }

enum JournalPhase {
  prepared,
  uploadingObjects,
  uploadingManifest,
  committingHead,
  applyStarted,
  savingBase,
  rollbackStarted,
  completed,
}

class SyncJournal {
  SyncJournal({
    required this.operationId,
    required this.operation,
    required this.phase,
    required this.updatedAt,
    required this.snapshotId,
    required this.targetFingerprint,
    required this.expectedRevision,
    required this.uploadRequired,
    List<String> completedObjectIds = const [],
    this.manifestSha256,
    this.error,
    this.stackTrace,
    this.version = 3,
  }) : completedObjectIds = List.unmodifiable(completedObjectIds) {
    if (version != 3) {
      throw const CloudFormatException('unsupported journal version');
    }
    _identity(operationId, 'operation id');
    _identity(snapshotId, 'snapshot id');
    _sha(targetFingerprint, 'target fingerprint');
    if (manifestSha256 != null) _sha(manifestSha256!, 'manifest SHA-256');
    if (completedObjectIds.toSet().length != completedObjectIds.length ||
        completedObjectIds.any(
          (id) => !RegExp(r'^[0-9a-f]{64}$').hasMatch(id),
        ) ||
        !_isCanonicalObjectSet(completedObjectIds)) {
      throw const CloudFormatException('invalid journal object checkpoint');
    }
    if (!uploadRequired &&
        (completedObjectIds.isNotEmpty || manifestSha256 != null)) {
      throw const CloudFormatException('download journal has upload state');
    }
    if ((phase == JournalPhase.committingHead ||
            phase == JournalPhase.applyStarted ||
            phase == JournalPhase.savingBase) &&
        uploadRequired &&
        manifestSha256 == null) {
      throw const CloudFormatException('journal manifest is missing');
    }
  }

  final int version;
  final String operationId;
  final JournalOperation operation;
  final JournalPhase phase;
  final DateTime updatedAt;
  final String snapshotId;
  final String targetFingerprint;
  final String? expectedRevision;
  final bool uploadRequired;
  final List<String> completedObjectIds;
  final String? manifestSha256;
  final String? error;
  final String? stackTrace;

  bool get appliesLocally => operation != JournalOperation.uploadLocal;

  SyncJournal copyWith({
    JournalPhase? phase,
    List<String>? completedObjectIds,
    String? manifestSha256,
    Object? error,
    StackTrace? stackTrace,
    DateTime? now,
  }) => SyncJournal(
    operationId: operationId,
    operation: operation,
    phase: phase ?? this.phase,
    updatedAt: (now ?? DateTime.now()).toUtc(),
    snapshotId: snapshotId,
    targetFingerprint: targetFingerprint,
    expectedRevision: expectedRevision,
    uploadRequired: uploadRequired,
    completedObjectIds: completedObjectIds ?? this.completedObjectIds,
    manifestSha256: manifestSha256 ?? this.manifestSha256,
    error: error?.toString() ?? this.error,
    stackTrace: stackTrace?.toString() ?? this.stackTrace,
  );

  Map<String, Object?> toJson() => {
    'version': version,
    'operationId': operationId,
    'operation': operation.name,
    'phase': phase.name,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'snapshotId': snapshotId,
    'targetFingerprint': targetFingerprint,
    'expectedRevision': expectedRevision,
    'uploadRequired': uploadRequired,
    'completedObjectIds': completedObjectIds,
    'manifestSha256': manifestSha256,
    'error': error,
    'stackTrace': stackTrace,
  };

  factory SyncJournal.fromJson(Object? value) {
    final json = strictJsonMap(value, const {
      'version',
      'operationId',
      'operation',
      'phase',
      'updatedAt',
      'snapshotId',
      'targetFingerprint',
      'expectedRevision',
      'uploadRequired',
      'completedObjectIds',
      'manifestSha256',
      'error',
      'stackTrace',
    });
    T field<T>(String key) {
      final value = json[key];
      if (value is! T) throw CloudFormatException('$key has invalid type');
      return value;
    }

    final operationName = field<String>('operation');
    final phaseName = field<String>('phase');
    final operation = JournalOperation.values
        .where((item) => item.name == operationName)
        .firstOrNull;
    final phase = JournalPhase.values
        .where((item) => item.name == phaseName)
        .firstOrNull;
    final dateText = field<String>('updatedAt');
    final date = DateTime.tryParse(dateText);
    final objects = json['completedObjectIds'];
    if (operation == null ||
        phase == null ||
        date == null ||
        !dateText.endsWith('Z') ||
        objects is! List ||
        objects.any((value) => value is! String)) {
      throw const CloudFormatException('invalid journal value');
    }
    for (final key in const [
      'expectedRevision',
      'manifestSha256',
      'error',
      'stackTrace',
    ]) {
      if (json[key] != null && json[key] is! String) {
        throw CloudFormatException('$key has invalid type');
      }
    }
    return SyncJournal(
      version: field<int>('version'),
      operationId: field<String>('operationId'),
      operation: operation,
      phase: phase,
      updatedAt: date.toUtc(),
      snapshotId: field<String>('snapshotId'),
      targetFingerprint: field<String>('targetFingerprint'),
      expectedRevision: json['expectedRevision'] as String?,
      uploadRequired: field<bool>('uploadRequired'),
      completedObjectIds: objects.cast<String>(),
      manifestSha256: json['manifestSha256'] as String?,
      error: json['error'] as String?,
      stackTrace: json['stackTrace'] as String?,
    );
  }
}

class JournalStore {
  JournalStore(this.file);
  final File file;
  Future<void> _exclusiveTail = Future<void>.value();

  Future<T> runExclusive<T>(Future<T> Function() action) {
    final previous = _exclusiveTail;
    final released = Completer<void>();
    _exclusiveTail = released.future;
    return () async {
      await previous;
      try {
        return await action();
      } finally {
        released.complete();
      }
    }();
  }

  Future<void> write(SyncJournal journal) async {
    await file.parent.create(recursive: true);
    final part = File('${file.path}.part');
    final sink = part.openWrite(mode: FileMode.writeOnly);
    try {
      sink.write(jsonEncode(journal.toJson()));
      await sink.flush();
    } finally {
      await sink.close();
    }
    await part.rename(file.path);
  }

  Future<SyncJournal?> read() async {
    if (!await file.exists()) return null;
    try {
      final bytes = await file.readAsBytes();
      if (bytes.length > 1024 * 1024) {
        throw const CloudFormatException('journal is too large');
      }
      return SyncJournal.fromJson(jsonDecode(utf8.decode(bytes)));
    } on CloudFormatException {
      rethrow;
    } catch (error) {
      throw CloudFormatException('invalid journal: $error');
    }
  }

  Future<void> delete() async {
    if (await file.exists()) await file.delete();
    final part = File('${file.path}.part');
    if (await part.exists()) await part.delete();
  }
}

bool _isCanonicalObjectSet(List<String> values) {
  for (var index = 1; index < values.length; index++) {
    if (values[index - 1].compareTo(values[index]) >= 0) return false;
  }
  return true;
}

void _identity(String value, String field) {
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$').hasMatch(value)) {
    throw CloudFormatException('invalid $field');
  }
}

void _sha(String value, String field) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw CloudFormatException('invalid $field');
  }
}
