import 'dart:typed_data';

import 'models.dart';

abstract interface class CloudObjectCodec {
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
