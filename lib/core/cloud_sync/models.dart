import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

const cloudSyncProtocol = 'aaalice-cloud-sync';
const cloudSyncSchemaVersion = 2;

/// Hard limit for each object sent to or received from a backend.
const maxCloudObjectBytes = 4 * 1024 * 1024;

class CloudFormatException implements Exception {
  const CloudFormatException(this.message);
  final String message;
  @override
  String toString() => 'CloudFormatException: $message';
}

class SnapshotRecordRef {
  SnapshotRecordRef({
    required this.recordId,
    required this.kind,
    required this.binary,
    required this.deleted,
    this.objectId,
    this.size,
    this.tombstoneIdentity,
  }) {
    _requireRecordIdentity(recordId);
    _requireIdentity(kind, 'kind');
    if (deleted) {
      if (objectId != null || size != null) {
        throw const CloudFormatException(
          'tombstone must not reference an object',
        );
      }
      if (tombstoneIdentity != null &&
          (tombstoneIdentity!.isEmpty ||
              tombstoneIdentity!.length > 64 * 1024)) {
        throw const CloudFormatException('tombstone identity is invalid');
      }
    } else {
      if (tombstoneIdentity != null) {
        throw const CloudFormatException(
          'live record must not contain tombstone identity',
        );
      }
      if (objectId == null || size == null) {
        throw const CloudFormatException(
          'live record must reference an object',
        );
      }
      _requireSha(objectId!);
      if (size! < 0 || size! > maxCloudObjectBytes) {
        throw const CloudFormatException(
          'object size is outside allowed range',
        );
      }
    }
  }

  final String recordId;
  final String kind;
  final bool binary;
  final bool deleted;
  final String? objectId;
  final int? size;
  final String? tombstoneIdentity;

  factory SnapshotRecordRef.fromJson(Object? value) {
    final json = _strictMap(value, {
      'recordId',
      'kind',
      'binary',
      'deleted',
      'objectId',
      'size',
      'tombstoneIdentity',
    });
    final binary = json['binary'];
    final deleted = json['deleted'];
    final objectId = json['objectId'];
    final size = json['size'];
    final tombstoneIdentity = json['tombstoneIdentity'];
    if (binary is! bool ||
        deleted is! bool ||
        (objectId != null && objectId is! String) ||
        (size != null && size is! int) ||
        (tombstoneIdentity != null && tombstoneIdentity is! String)) {
      throw const CloudFormatException('invalid record reference schema');
    }
    return SnapshotRecordRef(
      recordId: _string(json, 'recordId'),
      kind: _string(json, 'kind'),
      binary: binary,
      deleted: deleted,
      objectId: objectId as String?,
      size: size as int?,
      tombstoneIdentity: tombstoneIdentity as String?,
    );
  }

  Map<String, Object?> toJson() => {
    'recordId': recordId,
    'kind': kind,
    'binary': binary,
    'deleted': deleted,
    'objectId': objectId,
    'size': size,
    'tombstoneIdentity': tombstoneIdentity,
  };

  void verifyObject(List<int> bytes) {
    if (deleted || objectId == null || size == null) {
      throw const CloudFormatException('tombstone has no object');
    }
    if (bytes.length != size) {
      throw CloudFormatException(
        'object $objectId size mismatch: expected $size, got ${bytes.length}',
      );
    }
    if (crypto.sha256.convert(bytes).toString() != objectId) {
      throw CloudFormatException('object $objectId SHA-256 mismatch');
    }
  }
}

class SnapshotManifest {
  SnapshotManifest({
    required this.snapshotId,
    required this.createdAt,
    required List<SnapshotRecordRef> records,
    this.version = cloudSyncSchemaVersion,
  }) : records = UnmodifiableListView(List.of(records)) {
    if (version != cloudSyncSchemaVersion) {
      throw const CloudFormatException('unsupported manifest version');
    }
    _requireIdentity(snapshotId, 'snapshotId');
    if (records.map((record) => record.recordId).toSet().length !=
        records.length) {
      throw const CloudFormatException('duplicate record id');
    }
    for (var index = 1; index < records.length; index++) {
      if (records[index - 1].recordId.compareTo(records[index].recordId) >= 0) {
        throw const CloudFormatException('manifest records are not canonical');
      }
    }
  }

  final int version;
  final String snapshotId;
  final DateTime createdAt;
  final List<SnapshotRecordRef> records;

  factory SnapshotManifest.decode(List<int> bytes) {
    if (bytes.length > 1024 * 1024) {
      throw const CloudFormatException('manifest is too large');
    }
    try {
      return SnapshotManifest.fromJson(jsonDecode(utf8.decode(bytes)));
    } on CloudFormatException {
      rethrow;
    } catch (error) {
      throw CloudFormatException('invalid manifest JSON: $error');
    }
  }

  factory SnapshotManifest.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const CloudFormatException('expected JSON object');
    }
    final json = _strictMap(value, {
      'version',
      'snapshotId',
      'createdAt',
      'records',
    });
    final rawRecords = json['records'];
    if (rawRecords is! List) {
      throw const CloudFormatException('records must be an array');
    }
    return SnapshotManifest(
      version: _integer(json, 'version'),
      snapshotId: _string(json, 'snapshotId'),
      createdAt: _date(json, 'createdAt'),
      records: rawRecords.map(SnapshotRecordRef.fromJson).toList(),
    );
  }

  Map<String, Object> toJson() => {
    'version': version,
    'snapshotId': snapshotId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'records': records.map((record) => record.toJson()).toList(),
  };

  List<int> encode() => utf8.encode(jsonEncode(toJson()));
}

class SnapshotHead {
  SnapshotHead({
    required this.snapshotId,
    required this.manifestSha256,
    required this.updatedAt,
    this.version = cloudSyncSchemaVersion,
  }) {
    if (version != cloudSyncSchemaVersion) {
      throw const CloudFormatException('unsupported head version');
    }
    _requireIdentity(snapshotId, 'snapshotId');
    _requireSha(manifestSha256);
  }

  final int version;
  final String snapshotId;
  final String manifestSha256;
  final DateTime updatedAt;

  factory SnapshotHead.decode(List<int> bytes) {
    if (bytes.length > 64 * 1024) {
      throw const CloudFormatException('head is too large');
    }
    try {
      return SnapshotHead.fromJson(jsonDecode(utf8.decode(bytes)));
    } on CloudFormatException {
      rethrow;
    } catch (error) {
      throw CloudFormatException('invalid head JSON: $error');
    }
  }

  factory SnapshotHead.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const CloudFormatException('expected JSON object');
    }
    final json = _strictMap(value, {
      'version',
      'snapshotId',
      'manifestSha256',
      'updatedAt',
    });
    return SnapshotHead(
      version: _integer(json, 'version'),
      snapshotId: _string(json, 'snapshotId'),
      manifestSha256: _string(json, 'manifestSha256'),
      updatedAt: _date(json, 'updatedAt'),
    );
  }

  Map<String, Object> toJson() => {
    'version': version,
    'snapshotId': snapshotId,
    'manifestSha256': manifestSha256,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  List<int> encode() => utf8.encode(jsonEncode(toJson()));

  void verifyManifest(List<int> bytes) {
    if (crypto.sha256.convert(bytes).toString() != manifestSha256) {
      throw const CloudFormatException('manifest SHA-256 mismatch');
    }
  }
}

Map<String, Object?> strictJsonMap(Object? value, Set<String> keys) =>
    _strictMap(value, keys);

Map<String, Object?> _strictMap(Object? value, Set<String> keys) {
  if (value is! Map<String, dynamic>) {
    throw const CloudFormatException('expected JSON object');
  }
  if (value.keys.toSet().difference(keys).isNotEmpty ||
      keys.difference(value.keys.toSet()).isNotEmpty) {
    throw const CloudFormatException('JSON fields do not match schema');
  }
  return value;
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) throw CloudFormatException('$key must be a string');
  return value;
}

int _integer(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! int) throw CloudFormatException('$key must be an integer');
  return value;
}

DateTime _date(Map<String, Object?> json, String key) {
  final value = _string(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !value.endsWith('Z')) {
    throw CloudFormatException('$key must be a UTC ISO-8601 timestamp');
  }
  return parsed.toUtc();
}

void _requireIdentity(String value, String field) {
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$').hasMatch(value)) {
    throw CloudFormatException('invalid $field');
  }
}

void _requireRecordIdentity(String value) {
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,65534}$').hasMatch(value)) {
    throw const CloudFormatException('invalid recordId');
  }
}

void _requireSha(String value) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw const CloudFormatException('invalid SHA-256');
  }
}
