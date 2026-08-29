import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'crypto.dart';
import 'models.dart';

abstract interface class CloudObjectCodec {
  CloudSnapshotEncoding get encoding;

  int get maxClearObjectBytes;

  Future<Uint8List> encode(
    List<int> bytes, {
    required String objectId,
    required String kind,
  });

  Future<Uint8List> decode(
    List<int> bytes, {
    required String objectId,
    required String kind,
  });
}

class PlainCloudObjectCodec implements CloudObjectCodec {
  const PlainCloudObjectCodec();

  @override
  CloudSnapshotEncoding get encoding => CloudSnapshotEncoding.plain;

  @override
  int get maxClearObjectBytes => maxCloudObjectBytes;

  @override
  Future<Uint8List> encode(
    List<int> bytes, {
    required String objectId,
    required String kind,
  }) async => Uint8List.fromList(bytes);

  @override
  Future<Uint8List> decode(
    List<int> bytes, {
    required String objectId,
    required String kind,
  }) async => Uint8List.fromList(bytes);
}

class LegacyEncryptedCloudObjectCodec implements CloudObjectCodec {
  const LegacyEncryptedCloudObjectCodec({
    required this.crypto,
    required this.masterKey,
  });

  final CloudCrypto crypto;
  final SecretKey masterKey;

  @override
  CloudSnapshotEncoding get encoding => CloudSnapshotEncoding.encrypted;

  @override
  int get maxClearObjectBytes => maxCloudEncryptedClearObjectBytes;

  @override
  Future<Uint8List> encode(
    List<int> bytes, {
    required String objectId,
    required String kind,
  }) => crypto.encryptObject(bytes, masterKey, objectId: objectId, kind: kind);

  @override
  Future<Uint8List> decode(
    List<int> bytes, {
    required String objectId,
    required String kind,
  }) => crypto.decryptObject(bytes, masterKey, objectId: objectId, kind: kind);
}
