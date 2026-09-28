import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../../core/cloud_sync/data_source.dart';
import '../../core/cloud_sync/models.dart';
import 'verified_blob_store.dart';

final class CloudSyncBlobDescriptor {
  const CloudSyncBlobDescriptor({required this.sha256, required this.length});

  final String sha256;
  final int length;
}

class CloudSyncOperationStorage {
  CloudSyncOperationStorage(this.root, this.blobs, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final Directory root;
  final VerifiedBlobStore blobs;
  final DateTime Function() _now;
  final Random _random = Random.secure();
  final Object _mutationZoneKey = Object();
  Future<void> _mutationTail = Future<void>.value();

  Directory stage(String id) => Directory('${root.path}/staging/$id');
  Directory recovery(String id) => Directory('${root.path}/recovery/$id');
  Directory baseRecovery(String id) =>
      Directory('${root.path}/base-recovery/$id');
  Directory upload(String id) => Directory('${root.path}/upload/$id');

  Future<void> writeSnapshot(
    Directory directory,
    CloudSyncSnapshotData snapshot, {
    String? snapshotId,
  }) => _exclusiveMutation(
    () => _writeSnapshot(directory, snapshot, snapshotId: snapshotId),
  );

  Future<void> _writeSnapshot(
    Directory directory,
    CloudSyncSnapshotData snapshot, {
    String? snapshotId,
  }) async {
    final generation = _generationName();
    final generationDirectory = Directory(
      '${directory.path}/generations/$generation',
    );
    await generationDirectory.create(recursive: true);
    final index = <Map<String, Object?>>[];
    for (final record in snapshot.records.values) {
      final payload = record.payload;
      if (record.deleted == (payload != null)) {
        throw const CloudFormatException(
          'invalid persisted record object reference',
        );
      }
      if (payload != null) {
        if (payload is! VerifiedBlobPayload ||
            payload.storeRoot != blobs.root.absolute.path) {
          throw const CloudFormatException(
            'snapshot payload is not a verified blob handle',
          );
        }
        await blobs.assertVerifiedHandle(payload);
      }
      index.add({
        'id': record.id,
        'kind': record.kind,
        'binary': record.binary,
        'deleted': record.deleted,
        'length': payload?.length,
        'sha256': payload?.sha256,
        'tombstoneIdentity': record.tombstoneIdentity,
      });
    }
    index.sort(
      (left, right) =>
          (left['id']! as String).compareTo(right['id']! as String),
    );
    final indexBytes = utf8.encode(
      jsonEncode({'version': 2, 'snapshotId': snapshotId, 'records': index}),
    );
    final indexDigest = sha256.convert(indexBytes).toString();
    await File(
      '${generationDirectory.path}/index.json',
    ).writeAsBytes(indexBytes, flush: true);
    // READY is the last write inside an immutable generation.
    await File(
      '${generationDirectory.path}/READY',
    ).writeAsString(indexDigest, flush: true);

    final refs = Directory('${directory.path}/refs');
    await refs.create(recursive: true);
    final reservation = await _reserveRef(refs);
    try {
      final handle = await reservation.file.open(
        mode: FileMode.writeOnlyAppend,
      );
      try {
        await handle.writeString(
          jsonEncode({
            'version': 1,
            'generation': generation,
            'indexSha256': indexDigest,
          }),
        );
        await handle.flush();
      } finally {
        await handle.close();
      }
      // The exclusive reservation gives every publisher a monotonic name.
      // Renaming the complete ref keeps publication atomic for readers.
      await reservation.file.rename('${refs.path}/${reservation.name}.ref');
    } catch (_) {
      if (await reservation.file.exists()) await reservation.file.delete();
      rethrow;
    }
  }

  Future<CloudSyncSnapshotData?> readSnapshot(Directory directory) async {
    final selected = await _selectedGeneration(directory);
    if (selected == null) return null;
    final generationDirectory = Directory(
      '${directory.path}/generations/${selected.generation}',
    );
    final indexFile = File('${generationDirectory.path}/index.json');
    final readyFile = File('${generationDirectory.path}/READY');
    if (!await indexFile.exists() || !await readyFile.exists()) {
      throw const CloudFormatException('snapshot generation is not READY');
    }
    final indexBytes = await indexFile.readAsBytes();
    final indexDigest = sha256.convert(indexBytes).toString();
    if (indexDigest != selected.indexSha256 ||
        indexDigest != (await readyFile.readAsString()).trim()) {
      throw const CloudFormatException('snapshot index fingerprint mismatch');
    }
    final raw = _decodeJsonBytes(indexBytes, 'invalid snapshot index');
    if (raw is! Map<String, dynamic> ||
        raw.keys.toSet().difference({
          'version',
          'snapshotId',
          'records',
        }).isNotEmpty ||
        raw.keys.length != 3 ||
        raw['version'] != 2 ||
        (raw['snapshotId'] != null && raw['snapshotId'] is! String) ||
        raw['records'] is! List) {
      throw const CloudFormatException('invalid snapshot index');
    }
    final records = <CloudSyncRecord>[];
    for (final value in raw['records']! as List) {
      if (value is! Map<String, dynamic> || !_validRecordIndex(value)) {
        throw const CloudFormatException('invalid snapshot record index');
      }
      final length = value['length'] as int?;
      final digest = value['sha256'] as String?;
      records.add(
        CloudSyncRecord(
          id: value['id']! as String,
          kind: value['kind']! as String,
          binary: value['binary']! as bool,
          deleted: value['deleted']! as bool,
          tombstoneIdentity: value['tombstoneIdentity'] as String?,
          payload: length == null
              ? null
              : await blobs.open(length: length, sha256: digest!),
        ),
      );
    }
    return CloudSyncSnapshotData(records);
  }

  Future<String?> readSnapshotId(Directory directory) async {
    final selected = await _selectedGeneration(directory);
    if (selected == null) return null;
    final generationDirectory = Directory(
      '${directory.path}/generations/${selected.generation}',
    );
    final indexFile = File('${generationDirectory.path}/index.json');
    final readyFile = File('${generationDirectory.path}/READY');
    if (!await indexFile.exists() || !await readyFile.exists()) {
      throw const CloudFormatException('snapshot generation is not READY');
    }
    final indexBytes = await indexFile.readAsBytes();
    final indexDigest = sha256.convert(indexBytes).toString();
    if (indexDigest != selected.indexSha256 ||
        indexDigest != (await readyFile.readAsString()).trim()) {
      throw const CloudFormatException('snapshot index fingerprint mismatch');
    }
    final raw = _decodeJsonBytes(indexBytes, 'invalid snapshot index');
    if (raw is! Map<String, dynamic> ||
        raw.keys.toSet().difference({
          'version',
          'snapshotId',
          'records',
        }).isNotEmpty ||
        raw.keys.length != 3 ||
        raw['version'] != 2 ||
        (raw['snapshotId'] != null && raw['snapshotId'] is! String) ||
        raw['records'] is! List) {
      throw const CloudFormatException('invalid snapshot index');
    }
    return raw['snapshotId'] as String?;
  }

  Future<void> deleteSnapshot(Directory directory) async {
    if (await directory.exists()) await directory.delete(recursive: true);
  }

  Future<String> fingerprint(String operationId) async {
    final selected = await _selectedGeneration(stage(operationId));
    if (selected == null) {
      throw const CloudFormatException('staged target is not READY');
    }
    return selected.indexSha256;
  }

  /// Enumerates blob references reachable from each owner's latest published
  /// descriptor. Superseded generations are unreachable by readers.
  Stream<CloudSyncBlobDescriptor> descriptorRefs() async* {
    for (final owner in await _snapshotOwners()) {
      final selected = await _selectedGeneration(owner);
      if (selected == null) continue;
      yield* _descriptorRefs(owner, selected);
    }
  }

  /// Deletes only unreferenced immutable blobs older than [gracePeriod], then
  /// removes descriptor generations that readers can no longer select.
  /// Marking is fail-closed: malformed published state aborts before deletion.
  Future<int> collectUnreferencedBlobs({
    Duration gracePeriod = const Duration(days: 7),
  }) => _exclusiveMutation(
    () => _collectUnreferencedBlobs(gracePeriod: gracePeriod),
  );

  Future<int> _collectUnreferencedBlobs({required Duration gracePeriod}) async {
    final owners = await _snapshotOwners();
    final selected = <String, _SnapshotRef>{};
    final live = <String>{};
    for (final owner in owners) {
      final ref = await _selectedGeneration(owner);
      if (ref == null) continue;
      selected[owner.path] = ref;
      await for (final descriptor in _descriptorRefs(owner, ref)) {
        live.add(descriptor.sha256);
      }
    }
    final deleted = await blobs.sweep(live, gracePeriod: gracePeriod);
    for (final owner in owners) {
      final ref = selected[owner.path];
      if (ref != null) await _pruneSupersededGenerations(owner, ref);
      await _pruneOrphanedState(owner, ref, gracePeriod);
    }
    return deleted;
  }

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
    if (await target.exists()) {
      if (!_sameBytes(await target.readAsBytes(), bytes)) {
        throw const CloudFormatException('upload artifact is immutable');
      }
      return;
    }
    final temporary = File('${directory.path}/$name-${_nonce()}');
    await temporary.writeAsBytes(bytes, flush: true);
    try {
      await temporary.rename(target.path);
    } on FileSystemException {
      if (!await target.exists() ||
          !_sameBytes(await target.readAsBytes(), bytes)) {
        rethrow;
      }
      if (await temporary.exists()) await temporary.delete();
    }
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
  }

  Future<void> deleteOperation(String operationId) async {
    for (final directory in [
      stage(operationId),
      recovery(operationId),
      baseRecovery(operationId),
      upload(operationId),
    ]) {
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  }

  Future<List<Directory>> _snapshotOwners() async {
    final owners = <Directory>[];
    final base = Directory('${root.path}/base');
    if (await base.exists()) owners.add(base);
    for (final parent in [
      Directory('${root.path}/staging'),
      Directory('${root.path}/recovery'),
      Directory('${root.path}/base-recovery'),
    ]) {
      if (!await parent.exists()) continue;
      await for (final entity in parent.list()) {
        if (entity is Directory) owners.add(entity);
      }
    }
    final previewRoot = Directory('${root.path}/previews');
    if (await previewRoot.exists()) {
      await for (final entity in previewRoot.list(recursive: true)) {
        if (entity is Directory &&
            _fileName(entity.path) == 'refs' &&
            entity.parent.path != previewRoot.path) {
          owners.add(entity.parent);
        }
      }
    }
    return owners;
  }

  Stream<CloudSyncBlobDescriptor> _descriptorRefs(
    Directory owner,
    _SnapshotRef selected,
  ) async* {
    final indexFile = File(
      '${owner.path}/generations/${selected.generation}/index.json',
    );
    if (!await indexFile.exists()) {
      throw const CloudFormatException('published descriptor index is missing');
    }
    final bytes = await indexFile.readAsBytes();
    if (sha256.convert(bytes).toString() != selected.indexSha256) {
      throw const CloudFormatException('published descriptor hash mismatch');
    }
    final raw = jsonDecode(utf8.decode(bytes));
    if (raw is! Map<String, dynamic> ||
        raw.keys.toSet().difference({
          'version',
          'snapshotId',
          'records',
        }).isNotEmpty ||
        raw.keys.length != 3 ||
        raw['version'] != 2 ||
        raw['records'] is! List) {
      throw const CloudFormatException('invalid published descriptor');
    }
    for (final value in raw['records']! as List) {
      if (value is! Map<String, dynamic> || !_validRecordIndex(value)) {
        throw const CloudFormatException('invalid published record descriptor');
      }
      if (value['length'] is int && value['sha256'] is String) {
        yield CloudSyncBlobDescriptor(
          sha256: value['sha256']! as String,
          length: value['length']! as int,
        );
      }
    }
  }

  Future<void> _pruneSupersededGenerations(
    Directory owner,
    _SnapshotRef selected,
  ) async {
    final latest = await _selectedGeneration(owner);
    if (latest == null || latest.generation != selected.generation) return;
    final refs = Directory('${owner.path}/refs');
    await for (final entity in refs.list()) {
      if (entity is File &&
          entity.path.endsWith('.ref') &&
          !entity.path.endsWith('${selected.refName}.ref')) {
        await entity.delete();
      }
    }
    final generations = Directory('${owner.path}/generations');
    if (!await generations.exists()) return;
    await for (final entity in generations.list()) {
      if (entity is Directory &&
          _fileName(entity.path) != selected.generation) {
        await entity.delete(recursive: true);
      }
    }
  }

  Future<void> _pruneOrphanedState(
    Directory owner,
    _SnapshotRef? selected,
    Duration gracePeriod,
  ) async {
    final cutoff = _now().subtract(gracePeriod);
    final refs = Directory('${owner.path}/refs');
    if (await refs.exists()) {
      await for (final entity in refs.list()) {
        if (entity is! File || !entity.path.endsWith('.pending')) continue;
        if ((await entity.stat()).modified.toUtc().isBefore(cutoff)) {
          await entity.delete();
        }
      }
    }
    final generations = Directory('${owner.path}/generations');
    if (!await generations.exists()) return;
    await for (final entity in generations.list()) {
      if (entity is! Directory ||
          _fileName(entity.path) == selected?.generation) {
        continue;
      }
      if ((await entity.stat()).modified.toUtc().isBefore(cutoff)) {
        await entity.delete(recursive: true);
      }
    }
  }

  Future<_SnapshotRef?> _selectedGeneration(Directory directory) async {
    final refs = Directory('${directory.path}/refs');
    if (!await refs.exists()) return null;
    final files = await refs
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.ref'))
        .cast<File>()
        .toList();
    if (files.isEmpty) return null;
    files.sort((left, right) => right.path.compareTo(left.path));
    final selected = await _decodeRef(files.first);
    return _SnapshotRef(
      generation: selected.generation,
      indexSha256: selected.indexSha256,
      refName: _fileName(
        files.first.path,
      ).substring(0, _fileName(files.first.path).length - '.ref'.length),
    );
  }

  Future<_SnapshotRef> _decodeRef(File file) async {
    Object? raw;
    try {
      raw = jsonDecode(await file.readAsString());
    } on FormatException {
      throw const CloudFormatException('invalid snapshot ref');
    }
    if (raw is! Map<String, dynamic> ||
        raw.keys.toSet().difference({
          'version',
          'generation',
          'indexSha256',
        }).isNotEmpty ||
        raw.length != 3 ||
        raw['version'] != 1 ||
        raw['generation'] is! String ||
        !RegExp(
          r'^\d{20}-[0-9a-f]{8}$',
        ).hasMatch(raw['generation']! as String) ||
        raw['indexSha256'] is! String ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(raw['indexSha256']! as String)) {
      throw const CloudFormatException('invalid snapshot ref');
    }
    return _SnapshotRef(
      generation: raw['generation']! as String,
      indexSha256: raw['indexSha256']! as String,
    );
  }

  bool _validRecordIndex(Map<String, dynamic> value) =>
      value.keys.toSet().difference({
        'id',
        'kind',
        'binary',
        'deleted',
        'length',
        'sha256',
        'tombstoneIdentity',
      }).isEmpty &&
      value.keys.length == 7 &&
      value['id'] is String &&
      value['kind'] is String &&
      value['binary'] is bool &&
      value['deleted'] is bool &&
      (value['length'] == null || value['length'] is int) &&
      (value['sha256'] == null || value['sha256'] is String) &&
      (value['tombstoneIdentity'] == null ||
          value['tombstoneIdentity'] is String) &&
      ((value['length'] == null) == (value['sha256'] == null)) &&
      ((value['deleted']! as bool) == (value['length'] == null)) &&
      (value['length'] == null ||
          ((value['length']! as int) >= 0 &&
              (value['length']! as int) <= maxCloudRecordPayloadBytes)) &&
      (value['sha256'] == null ||
          RegExp(r'^[0-9a-f]{64}$').hasMatch(value['sha256']! as String)) &&
      ((value['deleted']! as bool) || value['tombstoneIdentity'] == null);

  Future<_RefReservation> _reserveRef(Directory refs) async {
    while (true) {
      var latestSequence = -1;
      await for (final entity in refs.list()) {
        if (entity is! File) continue;
        final match = RegExp(
          r'^(\d{20})(?:-[0-9a-f]{8})?\.(?:ref|pending)$',
        ).firstMatch(_fileName(entity.path));
        if (match == null) continue;
        final sequence = int.parse(match.group(1)!);
        if (sequence > latestSequence) latestSequence = sequence;
      }
      final wallSequence = _now().microsecondsSinceEpoch;
      final sequence = wallSequence > latestSequence
          ? wallSequence
          : latestSequence + 1;
      final sequenceName = sequence.toString().padLeft(20, '0');
      final file = File('${refs.path}/$sequenceName.pending');
      try {
        await file.create(exclusive: true);
        return _RefReservation(sequenceName, file);
      } on FileSystemException {
        // Another publisher reserved this sequence after our directory scan.
      }
    }
  }

  Future<T> runExclusiveMutation<T>(Future<T> Function() action) {
    if (identical(Zone.current[_mutationZoneKey], this)) {
      return action();
    }
    final previous = _mutationTail;
    final released = Completer<void>();
    _mutationTail = released.future;
    return () async {
      await previous;
      try {
        return await runZoned(action, zoneValues: {_mutationZoneKey: this});
      } finally {
        released.complete();
      }
    }();
  }

  Future<T> _exclusiveMutation<T>(Future<T> Function() action) =>
      runExclusiveMutation(action);

  String _generationName() =>
      '${_now().microsecondsSinceEpoch.toString().padLeft(20, '0')}-'
      '${_nonce()}';

  String _nonce() => _random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0');

  bool _sameBytes(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  Object? _decodeJsonBytes(List<int> bytes, String message) {
    try {
      return jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw CloudFormatException(message);
    }
  }

  String _fileName(String path) => path.replaceAll('\\', '/').split('/').last;

  void _validateArtifactName(String name) {
    if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$').hasMatch(name)) {
      throw const CloudFormatException('invalid upload artifact name');
    }
  }
}

final class _RefReservation {
  const _RefReservation(this.name, this.file);

  final String name;
  final File file;
}

final class _SnapshotRef {
  const _SnapshotRef({
    required this.generation,
    required this.indexSha256,
    this.refName = '',
  });

  final String generation;
  final String indexSha256;
  final String refName;
}
