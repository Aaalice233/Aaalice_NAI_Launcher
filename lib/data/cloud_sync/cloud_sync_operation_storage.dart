import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../core/cloud_sync/data_source.dart';
import '../../core/cloud_sync/models.dart';

class CloudSyncOperationStorage {
  const CloudSyncOperationStorage(this.root);

  final Directory root;

  Directory stage(String id) => Directory('${root.path}/staging/$id');
  Directory recovery(String id) => Directory('${root.path}/recovery/$id');
  Directory upload(String id) => Directory('${root.path}/upload/$id');

  Future<void> writeSnapshot(
    Directory directory,
    CloudSyncSnapshotData snapshot, {
    String? snapshotId,
  }) async {
    final replacement = Directory('${directory.path}.new');
    if (await replacement.exists()) await replacement.delete(recursive: true);
    await replacement.create(recursive: true);
    final index = <Map<String, Object?>>[];
    for (final record in snapshot.records.values) {
      final bytes = await record.readBytes();
      if (bytes != null) {
        await File(
          '${replacement.path}/${record.id}.payload',
        ).writeAsBytes(bytes, flush: true);
      }
      index.add({
        'id': record.id,
        'kind': record.kind,
        'binary': record.binary,
        'deleted': record.deleted,
        'length': bytes?.length,
        'sha256': record.payload?.sha256,
      });
    }
    index.sort(
      (left, right) =>
          (left['id']! as String).compareTo(right['id']! as String),
    );
    final indexBytes = utf8.encode(
      jsonEncode({'version': 1, 'snapshotId': snapshotId, 'records': index}),
    );
    await File(
      '${replacement.path}/index.json',
    ).writeAsBytes(indexBytes, flush: true);
    await File(
      '${replacement.path}/READY',
    ).writeAsString(sha256.convert(indexBytes).toString(), flush: true);
    if (await directory.exists()) await directory.delete(recursive: true);
    await replacement.rename(directory.path);
  }

  Future<CloudSyncSnapshotData?> readSnapshot(Directory directory) async {
    final indexFile = File('${directory.path}/index.json');
    final readyFile = File('${directory.path}/READY');
    if (!await indexFile.exists() || !await readyFile.exists()) return null;
    final indexBytes = await indexFile.readAsBytes();
    if (sha256.convert(indexBytes).toString() !=
        (await readyFile.readAsString()).trim()) {
      throw const CloudFormatException('snapshot index fingerprint mismatch');
    }
    final raw = jsonDecode(utf8.decode(indexBytes));
    if (raw is! Map<String, dynamic> ||
        raw.keys.toSet().difference({
          'version',
          'snapshotId',
          'records',
        }).isNotEmpty ||
        raw.keys.length != 3 ||
        raw['version'] != 1 ||
        (raw['snapshotId'] != null && raw['snapshotId'] is! String) ||
        raw['records'] is! List) {
      throw const CloudFormatException('invalid staged snapshot index');
    }
    final records = <CloudSyncRecord>[];
    for (final value in raw['records']! as List) {
      if (value is! Map<String, dynamic> || !_validRecordIndex(value)) {
        throw const CloudFormatException('invalid staged record index');
      }
      final id = value['id']! as String;
      final length = value['length'] as int?;
      final file = File('${directory.path}/$id.payload');
      if (length != null) {
        if (!await file.exists() || await file.length() != length) {
          throw const CloudFormatException('staged payload is truncated');
        }
        if ((await sha256.bind(file.openRead()).first).toString() !=
            value['sha256']) {
          throw const CloudFormatException('staged payload checksum mismatch');
        }
      }
      records.add(
        CloudSyncRecord(
          id: id,
          kind: value['kind']! as String,
          binary: value['binary']! as bool,
          deleted: value['deleted']! as bool,
          payload: length == null
              ? null
              : CloudSyncPayload(
                  length: length,
                  sha256: value['sha256']! as String,
                  openRead: file.openRead,
                ),
        ),
      );
    }
    return CloudSyncSnapshotData(records);
  }

  Future<String> fingerprint(String operationId) async =>
      (await File('${stage(operationId).path}/READY').readAsString()).trim();

  Future<void> writeArtifact(
    String operationId,
    String name,
    List<int> bytes,
  ) async {
    _validateArtifactName(name);
    if (bytes.length > maxCloudObjectBytes) {
      throw const CloudFormatException('upload artifact is too large');
    }
    final directory = upload(operationId);
    await directory.create(recursive: true);
    final target = File('${directory.path}/$name');
    final part = File('${target.path}.part');
    await part.writeAsBytes(bytes, flush: true);
    if (await target.exists()) await target.delete();
    await part.rename(target.path);
  }

  Future<List<int>?> readArtifact(String operationId, String name) async {
    _validateArtifactName(name);
    final file = File('${upload(operationId).path}/$name');
    if (!await file.exists()) return null;
    if (await file.length() > maxCloudObjectBytes) {
      throw const CloudFormatException('upload artifact is too large');
    }
    return file.readAsBytes();
  }

  Future<void> deleteArtifact(String operationId, String name) async {
    _validateArtifactName(name);
    final file = File('${upload(operationId).path}/$name');
    if (await file.exists()) await file.delete();
    final part = File('${file.path}.part');
    if (await part.exists()) await part.delete();
  }

  Future<void> deleteOperation(String operationId) async {
    for (final directory in [
      stage(operationId),
      recovery(operationId),
      upload(operationId),
    ]) {
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  }

  bool _validRecordIndex(Map<String, dynamic> value) =>
      value.keys.toSet().difference({
        'id',
        'kind',
        'binary',
        'deleted',
        'length',
        'sha256',
      }).isEmpty &&
      value.keys.length == 6 &&
      value['id'] is String &&
      value['kind'] is String &&
      value['binary'] is bool &&
      value['deleted'] is bool &&
      (value['length'] == null || value['length'] is int) &&
      (value['sha256'] == null || value['sha256'] is String) &&
      ((value['length'] == null) == (value['sha256'] == null)) &&
      (value['length'] == null ||
          ((value['length']! as int) >= 0 &&
              (value['length']! as int) <= maxCloudRecordPayloadBytes)) &&
      (value['sha256'] == null ||
          RegExp(r'^[0-9a-f]{64}$').hasMatch(value['sha256']! as String));

  void _validateArtifactName(String name) {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$').hasMatch(name)) {
      throw const CloudFormatException('invalid upload artifact name');
    }
  }
}
