import 'dart:convert';

import '../../core/cloud_sync/data_source.dart';
import '../../core/cloud_sync/models.dart';
import 'portable_sync_record.dart';

class DecodedPortableSnapshot {
  const DecodedPortableSnapshot(this.records, this.metadataChunks);

  final Map<String, PortableSyncRecord> records;
  final Map<String, List<String>> metadataChunks;
}

class PortableRecordCodec {
  const PortableRecordCodec({required this.stableId});

  final String Function(String adapterId, String portableId) stableId;

  static String tombstoneIdentity(PortableSyncRecord record) => base64Url
      .encode(
        utf8.encode(
          jsonEncode({
            'adapterId': record.adapterId,
            'portableId': record.id,
            'kind': record.kind,
            'data': record.data,
          }),
        ),
      )
      .replaceAll('=', '');

  Future<DecodedPortableSnapshot> decode(
    CloudSyncSnapshotData snapshot, {
    bool rejectOrphans = true,
  }) async {
    final records = <String, PortableSyncRecord>{};
    final metadataChunks = <String, List<String>>{};
    final referencedChunks = <String>{};
    for (final cloudRecord in snapshot.records.values) {
      if (cloudRecord.kind != 'metadata') continue;
      if (cloudRecord.deleted && cloudRecord.payload == null) {
        if (cloudRecord.binary) {
          throw const CloudFormatException(
            'tombstone metadata must not be binary',
          );
        }
        final portable = _decodeTombstone(cloudRecord);
        records[cloudRecord.id] = portable;
        metadataChunks[cloudRecord.id] = const [];
        continue;
      }
      final bytes = await cloudRecord.readBytes();
      if (bytes == null) {
        throw const CloudFormatException('metadata payload is missing');
      }
      try {
        final document = strictJsonMap(jsonDecode(utf8.decode(bytes)), {
          'version',
          'adapterId',
          'portableId',
          'kind',
          'data',
          'deleted',
          'resource',
        });
        if (document['version'] != 2 ||
            document['adapterId'] is! String ||
            document['portableId'] is! String ||
            document['kind'] is! String ||
            document['data'] is! Map ||
            document['deleted'] != false) {
          throw const CloudFormatException('invalid portable metadata schema');
        }
        final adapterId = document['adapterId']! as String;
        final portableId = document['portableId']! as String;
        if (stableId(adapterId, portableId) != cloudRecord.id) {
          throw const CloudFormatException(
            'portable metadata identity mismatch',
          );
        }
        final data = <String, Object?>{};
        for (final entry in (document['data']! as Map).entries) {
          if (entry.key is! String) {
            throw const CloudFormatException(
              'portable data key is not a string',
            );
          }
          data[entry.key as String] = entry.value;
        }

        PortableSyncResource? resource;
        final chunks = <String>[];
        final rawResource = document['resource'];
        if (cloudRecord.binary != (rawResource != null)) {
          throw const CloudFormatException('metadata binary/resource mismatch');
        }
        if (rawResource != null && !cloudRecord.deleted) {
          if (rawResource is! Map) {
            throw const CloudFormatException('invalid portable resource');
          }
          final value = strictJsonMap(rawResource, {
            'path',
            'mediaType',
            'length',
            'chunks',
          });
          if (value['path'] is! String ||
              value['mediaType'] is! String ||
              (value['mediaType']! as String).isEmpty ||
              (value['mediaType']! as String).length > 255 ||
              value['length'] is! int ||
              (value['length']! as int) < 0 ||
              value['chunks'] is! List ||
              !(value['chunks']! as List).every((item) => item is String)) {
            throw const CloudFormatException(
              'invalid portable resource schema',
            );
          }
          chunks.addAll((value['chunks']! as List).cast<String>());
          if (chunks.length > 65536 || chunks.toSet().length != chunks.length) {
            throw const CloudFormatException(
              'duplicate or excessive resource chunks',
            );
          }
          final length = value['length']! as int;
          if (length > 4 * 1024 * 1024 * 1024) {
            throw const CloudFormatException('portable resource is too large');
          }
          if ((length == 0) != chunks.isEmpty) {
            throw const CloudFormatException('resource length/chunks mismatch');
          }
          var actualLength = 0;
          for (var index = 0; index < chunks.length; index++) {
            final chunkId = chunks[index];
            if (chunkId != '${cloudRecord.id}.c$index' ||
                !referencedChunks.add(chunkId)) {
              throw const CloudFormatException(
                'invalid resource chunk identity',
              );
            }
            final chunk = snapshot.records[chunkId];
            if (chunk == null ||
                chunk.kind != 'resource' ||
                !chunk.binary ||
                chunk.deleted ||
                chunk.payload == null) {
              throw const CloudFormatException('invalid staged resource chunk');
            }
            actualLength += chunk.payload!.length;
          }
          if (actualLength != length) {
            throw const CloudFormatException(
              'portable resource length mismatch',
            );
          }
          resource = PortableSyncResource(
            relativePath: value['path']! as String,
            mediaType: value['mediaType']! as String,
            length: length,
            openRead: () => _readChunks(snapshot, chunks),
          );
        }
        final portable = PortableSyncRecord(
          adapterId: adapterId,
          id: portableId,
          kind: document['kind']! as String,
          data: data,
          deleted: cloudRecord.deleted,
          resource: resource,
        );
        records[cloudRecord.id] = portable;
        metadataChunks[cloudRecord.id] = List.unmodifiable(chunks);
      } on CloudFormatException {
        rethrow;
      } catch (error) {
        throw CloudFormatException('invalid portable metadata: $error');
      }
    }
    final resources = snapshot.records.values
        .where((record) => record.kind == 'resource')
        .map((record) => record.id)
        .toSet();
    if (rejectOrphans &&
        (resources.length != referencedChunks.length ||
            !resources.containsAll(referencedChunks))) {
      throw const CloudFormatException('orphan resource chunk');
    }
    return DecodedPortableSnapshot(records, metadataChunks);
  }

  PortableSyncRecord _decodeTombstone(CloudSyncRecord record) {
    final identity = record.tombstoneIdentity;
    if (record.payload != null || identity == null) {
      throw const CloudFormatException('invalid tombstone record');
    }
    try {
      var encoded = identity;
      encoded = encoded.padRight(
        encoded.length + ((4 - encoded.length % 4) % 4),
        '=',
      );
      final value = jsonDecode(utf8.decode(base64Url.decode(encoded)));
      final json = strictJsonMap(value, {
        'adapterId',
        'portableId',
        'kind',
        'data',
      });
      if (json['adapterId'] is! String ||
          json['portableId'] is! String ||
          json['kind'] is! String ||
          json['data'] is! Map) {
        throw const CloudFormatException('invalid tombstone identity');
      }
      final adapterId = json['adapterId']! as String;
      final portableId = json['portableId']! as String;
      if (stableId(adapterId, portableId) != record.id) {
        throw const CloudFormatException('tombstone identity mismatch');
      }
      return PortableSyncRecord(
        adapterId: adapterId,
        id: portableId,
        kind: json['kind']! as String,
        data: Map<String, Object?>.from(json['data']! as Map),
        deleted: true,
      );
    } on CloudFormatException {
      rethrow;
    } catch (error) {
      throw CloudFormatException('invalid tombstone identity: $error');
    }
  }

  Stream<List<int>> _readChunks(
    CloudSyncSnapshotData snapshot,
    List<String> ids,
  ) async* {
    for (final id in ids) {
      final bytes = await snapshot.records[id]!.readBytes();
      if (bytes == null) {
        throw const CloudFormatException('resource chunk payload is missing');
      }
      yield bytes;
    }
  }
}
