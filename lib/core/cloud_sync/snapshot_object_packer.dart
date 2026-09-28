import 'package:crypto/crypto.dart' as hashes;

import 'data_source.dart';
import 'models.dart';
import 'operation.dart';

/// Packs transport objects without changing record identity or merge granularity.
class SnapshotObjectPacker {
  static const targetBytes = 1024 * 1024;
  static const smallObjectBytes = 64 * 1024;

  static Future<Map<String, List<String>>> pack(
    List<SnapshotRecordRef> refs,
    Map<String, CloudSyncPayload> payloads,
    OperationToken token,
  ) async {
    final eligible = {
      for (final ref in refs)
        if (!ref.deleted &&
            (!ref.binary || ref.kind == 'metadata') &&
            ref.size! <= smallObjectBytes)
          ref.objectId!,
    }.toList()..sort();
    final packs = <String, List<String>>{};
    final originalIds = payloads.keys.toSet();
    var group = <String>[];
    var length = 0;
    Future<void> flush() async {
      if (group.length > 1) {
        final members = [for (final id in group) payloads[id]!];
        final digest = await hashes.sha256
            .bind(_readMembers(members, token))
            .single;
        final id = digest.toString();
        // A concatenation can equal an existing record (e.g. an empty member).
        // Keep those records independent rather than making an ambiguous pack.
        if (!originalIds.contains(id) && !payloads.containsKey(id)) {
          packs[id] = List.of(group);
          for (final member in group) {
            payloads.remove(member);
          }
          payloads[id] = CloudSyncPayload(
            length: length,
            sha256: id,
            openRead: () => _readMembers(members),
          );
        }
      }
      group = [];
      length = 0;
    }

    for (final id in eligible) {
      await token.checkpoint();
      final size = payloads[id]!.length;
      if (length + size > targetBytes) await flush();
      group.add(id);
      length += size;
    }
    await flush();
    return packs;
  }

  /// A saved upload keeps its exact grouping even after packing policy changes.
  static Future<void> restore(
    Map<String, List<String>> packs,
    Map<String, CloudSyncPayload> payloads,
    OperationToken token,
  ) async {
    for (final pack in packs.entries) {
      final members = [for (final id in pack.value) payloads[id]!];
      final digest = await hashes.sha256
          .bind(_readMembers(members, token))
          .single;
      if (digest.toString() != pack.key) {
        throw const CloudFormatException(
          'pending pack does not match staged payloads',
        );
      }
      for (final id in pack.value) {
        payloads.remove(id);
      }
      payloads[pack.key] = CloudSyncPayload(
        length: members.fold(0, (sum, member) => sum + member.length),
        sha256: pack.key,
        openRead: () => _readMembers(members),
      );
    }
  }

  static Stream<List<int>> _readMembers(
    List<CloudSyncPayload> members, [
    OperationToken? token,
  ]) async* {
    for (final member in members) {
      await (token ?? OperationToken.current)?.checkpoint();
      yield await member.readBytes();
    }
  }
}
