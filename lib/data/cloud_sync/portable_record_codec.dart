import 'dart:convert';

import 'package:crypto/crypto.dart';

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

  Future<DecodedPortableSnapshot> decode(
    CloudSyncSnapshotData snapshot, {
    bool rejectOrphans = true,
  }) async {
    final records = <String, PortableSyncRecord>{};
    final metadataChunks = <String, List<String>>{};
    final referencedChunks = <String>{};
    for (final cloudRecord in snapshot.records.values) {
      if (cloudRecord.kind != 'metadata') continue;
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
        if (document['version'] != 1 ||
            document['adapterId'] is! String ||
            document['portableId'] is! String ||
            document['kind'] is! String ||
            document['data'] is! Map ||
            document['deleted'] is! bool ||
            document['deleted'] != cloudRecord.deleted) {
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
        if (rawResource != null) {
          if (cloudRecord.deleted || rawResource is! Map) {
            throw const CloudFormatException('invalid tombstone resource');
          }
          final value = strictJsonMap(rawResource, {
            'path',
            'mediaType',
            'length',
            'sha256',
            'chunks',
          });
          if (value['path'] is! String ||
              value['mediaType'] is! String ||
              (value['mediaType']! as String).isEmpty ||
              (value['mediaType']! as String).length > 255 ||
              value['length'] is! int ||
              (value['length']! as int) < 0 ||
              value['sha256'] is! String ||
              !RegExp(r'^[a-f0-9]{64}$').hasMatch(value['sha256']! as String) ||
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
          final digestSink = sha256.startChunkedConversion(
            ChunkedConversionSink.withCallback((digests) {
              if (digests.single.toString() != value['sha256']) {
                throw const CloudFormatException(
                  'portable resource checksum mismatch',
                );
              }
            }),
          );
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
                chunk.deleted ||
                chunk.payload == null) {
              throw const CloudFormatException('invalid staged resource chunk');
            }
            final bytes = await chunk.readBytes();
            if (bytes == null) {
              throw const CloudFormatException(
                'resource chunk payload is missing',
              );
            }
            actualLength += bytes.length;
            digestSink.add(bytes);
          }
          digestSink.close();
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
