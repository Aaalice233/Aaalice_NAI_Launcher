import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../storage/secure_storage_service.dart';
import 'backend/cloud_sync_backend.dart';
import 'crypto.dart';

class CloudKeyEnvelopeSession {
  const CloudKeyEnvelopeSession({
    required this.masterKey,
    required this.envelope,
    required this.revision,
    this.recoveryKey,
  });

  final SecretKey masterKey;
  final WrappedMasterKey envelope;
  final String revision;
  final String? recoveryKey;
}

class CloudKeyEnvelopeService {
  CloudKeyEnvelopeService({
    required CloudKeyEnvelopeBackend backend,
    required SecureStorageService secureStorage,
    CloudCrypto? crypto,
  }) : _backend = backend,
       _secureStorage = secureStorage,
       _crypto = crypto ?? CloudCrypto();

  final CloudKeyEnvelopeBackend _backend;
  final SecureStorageService _secureStorage;
  final CloudCrypto _crypto;
  CreatedMasterKey? _prepared;

  Future<String> prepareCreate(String password) async {
    if (await _backend.readKeyEnvelope() != null) {
      throw StateError('Remote KEY.json already exists.');
    }
    _prepared = await _crypto.create(password);
    return _prepared!.recoveryKey;
  }

  void discardPrepared() => _prepared = null;

  Future<CloudKeyEnvelopeSession> commitPrepared() async {
    final created = _prepared;
    if (created == null) throw StateError('No prepared key envelope.');
    try {
      final committed = await _backend.commitKeyEnvelope(
        created.wrapped.encode(),
        expectedRevision: null,
      );
      await _persist(created.masterKey, created.wrapped);
      return CloudKeyEnvelopeSession(
        masterKey: created.masterKey,
        envelope: created.wrapped,
        revision: committed.revision,
        recoveryKey: created.recoveryKey,
      );
    } finally {
      _prepared = null;
    }
  }

  Future<CloudKeyEnvelopeSession> create(String password) async {
    await prepareCreate(password);
    return commitPrepared();
  }

  /// Existing devices prefer their secure-storage master key, but still read
  /// and validate the remotely authoritative wrapper and revision.
  Future<CloudKeyEnvelopeSession> unlock({String? password}) async {
    final remote = await _backend.readKeyEnvelope();
    if (remote == null) throw StateError('Remote KEY.json is missing.');
    final envelope = WrappedMasterKey.decode(remote.bytes);
    final local = await _secureStorage.getCloudSyncMasterKey();
    final SecretKey master;
    if (local != null) {
      final bytes = base64Decode(local);
      if (bytes.length != 32) throw const FormatException('Invalid local key');
      master = SecretKey(bytes);
      await _crypto.verifyEnvelope(master, envelope);
    } else {
      if (password == null || password.isEmpty) {
        throw StateError('An encryption password is required.');
      }
      master = await _crypto.unlock(password, envelope);
    }
    await _persist(master, envelope);
    return CloudKeyEnvelopeSession(
      masterKey: master,
      envelope: envelope,
      revision: remote.revision,
    );
  }

  Future<CloudKeyEnvelopeSession> changePassword(
    CloudKeyEnvelopeSession current,
    String password,
  ) async {
    await _crypto.verifyEnvelope(current.masterKey, current.envelope);
    final wrapped = await _crypto.wrapMasterKey(
      current.masterKey,
      password,
      recoveryBox: current.envelope.recoveryBox,
    );
    final committed = await _backend.commitKeyEnvelope(
      wrapped.encode(),
      expectedRevision: current.revision,
    );
    await _persist(current.masterKey, wrapped);
    return CloudKeyEnvelopeSession(
      masterKey: current.masterKey,
      envelope: wrapped,
      revision: committed.revision,
    );
  }

  Future<CloudKeyEnvelopeSession> recover(
    String recoveryKey,
    String newPassword,
  ) async {
    final remote = await _backend.readKeyEnvelope();
    if (remote == null) throw StateError('Remote KEY.json is missing.');
    final recovered = await _crypto.recover(
      recoveryKey,
      newPassword,
      WrappedMasterKey.decode(remote.bytes),
    );
    final committed = await _backend.commitKeyEnvelope(
      recovered.wrapped.encode(),
      expectedRevision: remote.revision,
    );
    await _persist(recovered.masterKey, recovered.wrapped);
    return CloudKeyEnvelopeSession(
      masterKey: recovered.masterKey,
      envelope: recovered.wrapped,
      revision: committed.revision,
    );
  }

  Future<CloudKeyEnvelopeSession> rotateRecoveryKey(
    CloudKeyEnvelopeSession current,
  ) async {
    final rotated = await _crypto.rotateRecoveryKey(
      current.masterKey,
      current.envelope,
    );
    final committed = await _backend.commitKeyEnvelope(
      rotated.wrapped.encode(),
      expectedRevision: current.revision,
    );
    await _persist(current.masterKey, rotated.wrapped);
    return CloudKeyEnvelopeSession(
      masterKey: current.masterKey,
      envelope: rotated.wrapped,
      revision: committed.revision,
      recoveryKey: rotated.recoveryKey,
    );
  }

  Future<void> _persist(SecretKey master, WrappedMasterKey envelope) async {
    await Future.wait([
      master.extractBytes().then(
        (bytes) => _secureStorage.saveCloudSyncMasterKey(base64Encode(bytes)),
      ),
      _secureStorage.saveCloudSyncKeyEnvelope(
        base64Encode(Uint8List.fromList(envelope.encode())),
      ),
    ]);
  }
}
