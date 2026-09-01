import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

const cloudSyncProtocol = 'aaalice-cloud-sync';
const cloudSyncSchemaVersion = 1;

/// Hard limit for each object sent to or received from a backend.
const maxCloudObjectBytes = 4 * 1024 * 1024;

const maxCloudClearObjectBytes = maxCloudObjectBytes;

class CloudFormatException implements Exception {
  const CloudFormatException(this.message);
  final String message;
  @override
  String toString() => 'CloudFormatException: $message';
}

class SnapshotObject {
  SnapshotObject({
    required this.id,
    required this.kind,
    required this.size,
    required this.sha256,
  }) {
    _requireIdentity(id, 'id');
    _requireIdentity(kind, 'kind');
    if (size < 0 || size > maxCloudObjectBytes) {
      throw const CloudFormatException('object size is outside allowed range');
    }
    _requireSha(sha256);
  }

  final String id;
  final String kind;
  final int size;
  final String sha256;

  factory SnapshotObject.fromJson(Object? value) {
    final json = _strictMap(value, {'id', 'kind', 'size', 'sha256'});
    return SnapshotObject(
      id: _string(json, 'id'),
      kind: _string(json, 'kind'),
      size: _integer(json, 'size'),
      sha256: _string(json, 'sha256'),
    );
  }

  Map<String, Object> toJson() => {
    'id': id,
    'kind': kind,
    'size': size,
    'sha256': sha256,
  };

  void verify(List<int> bytes) {
    if (bytes.length != size) {
      throw CloudFormatException(
        'object $id size mismatch: expected $size, got ${bytes.length}',
      );
    }
    if (crypto.sha256.convert(bytes).toString() != sha256) {
      throw CloudFormatException('object $id SHA-256 mismatch');
    }
  }
}

class SnapshotManifest {
  SnapshotManifest({
    required this.snapshotId,
    required this.createdAt,
    required List<SnapshotObject> objects,
    this.version = cloudSyncSchemaVersion,
  }) : objects = UnmodifiableListView(List.of(objects)) {
    if (version != cloudSyncSchemaVersion) {
      throw const CloudFormatException('unsupported manifest version');
    }
    _requireIdentity(snapshotId, 'snapshotId');
    if (objects.map((object) => object.id).toSet().length != objects.length) {
      throw const CloudFormatException('duplicate object id');
    }
  }

  final int version;
  final String snapshotId;
  final DateTime createdAt;
  final List<SnapshotObject> objects;

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
      'objects',
    });
    final rawObjects = json['objects'];
    if (rawObjects is! List) {
      throw const CloudFormatException('objects must be an array');
    }
    return SnapshotManifest(
      version: _integer(json, 'version'),
      snapshotId: _string(json, 'snapshotId'),
      createdAt: _date(json, 'createdAt'),
      objects: rawObjects.map(SnapshotObject.fromJson).toList(),
    );
  }

  Map<String, Object> toJson() => {
    'version': version,
    'snapshotId': snapshotId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'objects': objects.map((object) => object.toJson()).toList(),
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

void _requireSha(String value) {
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(value)) {
    throw const CloudFormatException('invalid SHA-256');
  }
}
