import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hashes;
import 'package:cryptography/cryptography.dart';

import 'crypto_models.dart';
import 'models.dart';

export 'crypto_models.dart';

class CloudCrypto {
  CloudCrypto({KdfParameters? kdf, Random? random})
    : kdf = kdf ?? const KdfParameters(),
      _random = random ?? Random.secure();

  static const _recoveryPrefix = 'AA1-';
  final KdfParameters kdf;
  final Random _random;
  final AesGcm _aes = AesGcm.with256bits();
  Future<CreatedMasterKey> create(String password) async {
    _requireSupportedKdf(kdf);
    final masterBytes = _randomBytes(32);
    final salt = _randomBytes(16);
    final recoveryBytes = _randomBytes(32);
    final passwordKey = await _passwordKey(password, salt, kdf);
    final passwordBox = await _seal(
      masterBytes,
      passwordKey,
      _boxIdentity('password'),
    );
    final recoveryKey = SecretKey(recoveryBytes);
    final recoveryBox = await _seal(
      masterBytes,
      recoveryKey,
      _boxIdentity('recovery'),
    );
    final masterKey = SecretKey(masterBytes);
    return CreatedMasterKey(
      masterKey,
      await _authenticatedEnvelope(
        masterKey: masterKey,
        kdf: kdf,
        salt: salt,
        passwordBox: passwordBox,
        recoveryBox: recoveryBox,
      ),
      _encodeRecovery(recoveryBytes),
    );
  }

  Future<SecretKey> unlock(String password, WrappedMasterKey wrapped) async {
    try {
      final key = await _passwordKey(password, wrapped.salt, wrapped.kdf);
      final master = SecretKey(
        await _open(wrapped.passwordBox, key, _boxIdentity('password')),
      );
      await verifyEnvelope(master, wrapped);
      return master;
    } on SecretBoxAuthenticationError catch (error) {
      throw CloudCryptoException(
        'incorrect password or tampered key wrapper',
        error,
      );
    } on RangeError catch (error) {
      throw CloudCryptoException('truncated key wrapper', error);
    }
  }

  Future<WrappedMasterKey> changePassword(
    String oldPassword,
    String newPassword,
    WrappedMasterKey wrapped,
  ) async {
    final master = await unlock(oldPassword, wrapped);
    final salt = _randomBytes(16);
    final key = await _passwordKey(newPassword, salt, kdf);
    final bytes = await master.extractBytes();
    return _authenticatedEnvelope(
      masterKey: master,
      kdf: kdf,
      salt: salt,
      passwordBox: await _seal(bytes, key, _boxIdentity('password')),
      recoveryBox: wrapped.recoveryBox,
    );
  }

  /// Rewraps an already unlocked random master key. Snapshot objects are not
  /// touched, so password rotation is constant-time in remote data size.
  Future<WrappedMasterKey> wrapMasterKey(
    SecretKey masterKey,
    String password, {
    Uint8List? recoveryBox,
  }) async {
    _requireSupportedKdf(kdf);
    final salt = _randomBytes(16);
    final key = await _passwordKey(password, salt, kdf);
    return _authenticatedEnvelope(
      masterKey: masterKey,
      kdf: kdf,
      salt: salt,
      passwordBox: await _seal(
        await masterKey.extractBytes(),
        key,
        _boxIdentity('password'),
      ),
      recoveryBox: recoveryBox,
    );
  }

  Future<RecoveryResult> recover(
    String recoveryCode,
    String newPassword,
    WrappedMasterKey wrapped,
  ) async {
    if (wrapped.recoveryBox == null) {
      throw const CloudCryptoException(
        'recovery key has already been consumed',
      );
    }
    try {
      final recoveryKey = SecretKey(_decodeRecovery(recoveryCode));
      final bytes = await _open(
        wrapped.recoveryBox!,
        recoveryKey,
        _boxIdentity('recovery'),
      );
      final masterKey = SecretKey(bytes);
      await verifyEnvelope(masterKey, wrapped);
      final salt = _randomBytes(16);
      final passwordKey = await _passwordKey(newPassword, salt, kdf);
      return RecoveryResult(
        masterKey,
        await _authenticatedEnvelope(
          masterKey: masterKey,
          kdf: kdf,
          salt: salt,
          passwordBox: await _seal(
            bytes,
            passwordKey,
            _boxIdentity('password'),
          ),
          recoveryBox: null,
        ),
      );
    } on SecretBoxAuthenticationError catch (error) {
      throw CloudCryptoException(
        'invalid recovery key or tampered wrapper',
        error,
      );
    }
  }

  Future<({WrappedMasterKey wrapped, String recoveryKey})> rotateRecoveryKey(
    SecretKey masterKey,
    WrappedMasterKey wrapped,
  ) async {
    await verifyEnvelope(masterKey, wrapped);
    final recoveryBytes = _randomBytes(32);
    final recoveryBox = await _seal(
      await masterKey.extractBytes(),
      SecretKey(recoveryBytes),
      _boxIdentity('recovery'),
    );
    final authenticated = await _authenticatedEnvelope(
      masterKey: masterKey,
      kdf: wrapped.kdf,
      salt: wrapped.salt,
      passwordBox: wrapped.passwordBox,
      recoveryBox: recoveryBox,
    );
    return (
      wrapped: authenticated,
      recoveryKey: _encodeRecovery(recoveryBytes),
    );
  }

  Future<Uint8List> encryptObject(
    List<int> clearText,
    SecretKey masterKey, {
    required String objectId,
    required String kind,
  }) => _seal(clearText, masterKey, _objectAad(objectId, kind));
  Future<Uint8List> decryptObject(
    List<int> encoded,
    SecretKey masterKey, {
    required String objectId,
    required String kind,
  }) async {
    try {
      return await _open(encoded, masterKey, _objectAad(objectId, kind));
    } on SecretBoxAuthenticationError catch (error) {
      throw CloudCryptoException('object authentication failed', error);
    } on RangeError catch (error) {
      throw CloudCryptoException('encrypted object is truncated', error);
    }
  }

  String _objectAad(String id, String kind) =>
      '$cloudSyncProtocol/v1/object/$kind/$id';
  String _boxIdentity(String role) =>
      'key-envelope/v${WrappedMasterKey.currentVersion}/$role';
  Future<void> verifyEnvelope(
    SecretKey masterKey,
    WrappedMasterKey wrapped,
  ) async {
    _requireSupportedKdf(wrapped.kdf);
    final keyBytes = await masterKey.extractBytes();
    if (keyBytes.length != 32) {
      throw const CloudCryptoException('invalid master key size');
    }
    final expected = _mac(keyBytes, wrapped.authenticatedBytes());
    if (!_constantTimeEquals(expected, wrapped.authentication)) {
      throw const CloudCryptoException('key envelope authentication failed');
    }
  }

  Future<WrappedMasterKey> _authenticatedEnvelope({
    required SecretKey masterKey,
    required KdfParameters kdf,
    required Uint8List salt,
    required Uint8List passwordBox,
    required Uint8List? recoveryBox,
  }) async {
    _requireSupportedKdf(kdf);
    final unsigned = WrappedMasterKey(
      kdf: kdf,
      salt: salt,
      passwordBox: passwordBox,
      recoveryBox: recoveryBox,
      authentication: Uint8List(32),
    );
    final keyBytes = await masterKey.extractBytes();
    if (keyBytes.length != 32) {
      throw const CloudCryptoException('invalid master key size');
    }
    final authentication = _mac(keyBytes, unsigned.authenticatedBytes());
    return WrappedMasterKey(
      kdf: kdf,
      salt: Uint8List.fromList(salt),
      passwordBox: Uint8List.fromList(passwordBox),
      recoveryBox: recoveryBox == null ? null : Uint8List.fromList(recoveryBox),
      authentication: Uint8List.fromList(authentication),
    );
  }

  void _requireSupportedKdf(KdfParameters parameters) {
    if (!parameters.isSupportedProfile) {
      throw const CloudCryptoException('unsupported KDF profile');
    }
  }

  bool _constantTimeEquals(List<int> left, List<int> right) {
    if (left.length != right.length) return false;
    var difference = 0;
    for (var index = 0; index < left.length; index++) {
      difference |= left[index] ^ right[index];
    }
    return difference == 0;
  }

  List<int> _mac(List<int> key, List<int> bytes) =>
      hashes.Hmac(hashes.sha256, key).convert(bytes).bytes;
  Future<SecretKey> _passwordKey(
    String password,
    List<int> salt,
    KdfParameters parameters,
  ) {
    _requireSupportedKdf(parameters);
    if (password.isEmpty) {
      throw const CloudCryptoException('password must not be empty');
    }
    return Argon2id(
      parallelism: parameters.parallelism,
      memory: parameters.memory,
      iterations: parameters.iterations,
      hashLength: 32,
    ).deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
  }

  Future<Uint8List> _seal(
    List<int> bytes,
    SecretKey key,
    String identity,
  ) async {
    final box = await _aes.encrypt(
      bytes,
      secretKey: key,
      nonce: _randomBytes(_aes.nonceLength),
      aad: utf8.encode('$cloudSyncProtocol|$identity'),
    );
    return Uint8List.fromList([
      ...box.nonce,
      ...box.cipherText,
      ...box.mac.bytes,
    ]);
  }

  Future<Uint8List> _open(
    List<int> bytes,
    SecretKey key,
    String identity,
  ) async {
    if (bytes.length < _aes.nonceLength + 16) {
      throw RangeError('missing nonce or tag');
    }
    final nonceEnd = _aes.nonceLength;
    final tagStart = bytes.length - 16;
    final box = SecretBox(
      bytes.sublist(nonceEnd, tagStart),
      nonce: bytes.sublist(0, nonceEnd),
      mac: Mac(bytes.sublist(tagStart)),
    );
    return Uint8List.fromList(
      await _aes.decrypt(
        box,
        secretKey: key,
        aad: utf8.encode('$cloudSyncProtocol|$identity'),
      ),
    );
  }

  Uint8List _randomBytes(int length) =>
      Uint8List.fromList(List.generate(length, (_) => _random.nextInt(256)));
  String _encodeRecovery(List<int> bytes) {
    final payload = base64Url.encode(bytes).replaceAll('=', '');
    return '$_recoveryPrefix$payload-${_recoveryChecksum(bytes)}';
  }

  Uint8List _decodeRecovery(String code) {
    final match = RegExp(
      r'^AA1-([A-Za-z0-9_-]{43})-([0-9a-f]{8})$',
    ).firstMatch(code);
    if (match == null) {
      throw const CloudCryptoException('invalid recovery key encoding');
    }
    final bytes = base64Url.decode('${match.group(1)}=');
    if (_recoveryChecksum(bytes) != match.group(2)) {
      throw const CloudCryptoException('recovery key checksum mismatch');
    }
    return Uint8List.fromList(bytes);
  }

  String _recoveryChecksum(List<int> bytes) => hashes.sha256
      .convert(bytes)
      .bytes
      .take(4)
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}
