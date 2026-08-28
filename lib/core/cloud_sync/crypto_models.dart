import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'models.dart';

class CloudCryptoException implements Exception {
  const CloudCryptoException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() => 'CloudCryptoException: $message';
}

class KdfParameters {
  const KdfParameters({
    this.version = 1,
    this.memory = 19456,
    this.iterations = 2,
    this.parallelism = 1,
  });

  final int version;
  final int memory;
  final int iterations;
  final int parallelism;

  bool get isSupportedProfile =>
      version == 1 && memory == 19456 && iterations == 2 && parallelism == 1;

  Map<String, Object> toJson() => {
    'version': version,
    'memory': memory,
    'iterations': iterations,
    'parallelism': parallelism,
  };

  factory KdfParameters.fromJson(Object? value) {
    final json = strictJsonMap(value, {
      'version',
      'memory',
      'iterations',
      'parallelism',
    });
    int integer(String key) {
      final value = json[key];
      if (value is! int) throw CloudFormatException('$key must be an integer');
      return value;
    }

    final result = KdfParameters(
      version: integer('version'),
      memory: integer('memory'),
      iterations: integer('iterations'),
      parallelism: integer('parallelism'),
    );
    if (!result.isSupportedProfile) {
      throw const CloudFormatException('unsupported KDF profile');
    }
    return result;
  }
}

class WrappedMasterKey {
  WrappedMasterKey({
    required this.kdf,
    required this.salt,
    required this.passwordBox,
    required this.recoveryBox,
    required this.authentication,
    this.version = currentVersion,
  });

  static const currentVersion = 2;
  static const algorithm = 'argon2id-aes-256-gcm+hmac-sha256';

  final int version;
  final KdfParameters kdf;
  final Uint8List salt;
  final Uint8List passwordBox;
  final Uint8List? recoveryBox;
  final Uint8List authentication;

  Map<String, Object?> toJson() => {
    'version': version,
    'protocol': cloudSyncProtocol,
    'algorithm': algorithm,
    'kdf': kdf.toJson(),
    'salt': base64Encode(salt),
    'passwordBox': base64Encode(passwordBox),
    'recoveryBox': recoveryBox == null ? null : base64Encode(recoveryBox!),
    'authentication': {
      'algorithm': 'hmac-sha256',
      'value': base64Encode(authentication),
    },
  };

  /// Protocol v2 field order, independent of received JSON representation.
  Uint8List authenticatedBytes() => Uint8List.fromList(
    utf8.encode(
      jsonEncode({
        'version': version,
        'protocol': cloudSyncProtocol,
        'algorithm': algorithm,
        'kdf': kdf.toJson(),
        'salt': base64Encode(salt),
        'passwordBox': base64Encode(passwordBox),
        'recoveryBox': recoveryBox == null ? null : base64Encode(recoveryBox!),
      }),
    ),
  );

  Uint8List encode() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  factory WrappedMasterKey.decode(List<int> bytes) {
    if (bytes.length > 64 * 1024) {
      throw const CloudFormatException('key wrapper is too large');
    }
    try {
      final json = strictJsonMap(jsonDecode(utf8.decode(bytes)), {
        'version',
        'protocol',
        'algorithm',
        'kdf',
        'salt',
        'passwordBox',
        'recoveryBox',
        'authentication',
      });
      final authentication = strictJsonMap(json['authentication'], {
        'algorithm',
        'value',
      });
      if (json['version'] != currentVersion ||
          json['protocol'] != cloudSyncProtocol ||
          json['algorithm'] != algorithm ||
          json['salt'] is! String ||
          json['passwordBox'] is! String ||
          (json['recoveryBox'] != null && json['recoveryBox'] is! String) ||
          authentication['algorithm'] != 'hmac-sha256' ||
          authentication['value'] is! String) {
        throw const CloudFormatException('invalid key wrapper schema');
      }
      final salt = base64Decode(json['salt']! as String);
      final passwordBox = base64Decode(json['passwordBox']! as String);
      final recovery = json['recoveryBox'] == null
          ? null
          : base64Decode(json['recoveryBox']! as String);
      final mac = base64Decode(authentication['value']! as String);
      if (salt.length != 16 ||
          passwordBox.length < 28 ||
          (recovery?.length ?? 28) < 28 ||
          mac.length != 32) {
        throw const CloudFormatException('invalid key wrapper size');
      }
      return WrappedMasterKey(
        kdf: KdfParameters.fromJson(json['kdf']),
        salt: Uint8List.fromList(salt),
        passwordBox: Uint8List.fromList(passwordBox),
        recoveryBox: recovery == null ? null : Uint8List.fromList(recovery),
        authentication: Uint8List.fromList(mac),
      );
    } on CloudFormatException {
      rethrow;
    } catch (error) {
      throw CloudFormatException('invalid key wrapper JSON: $error');
    }
  }
}

class CreatedMasterKey {
  const CreatedMasterKey(this.masterKey, this.wrapped, this.recoveryKey);

  final SecretKey masterKey;
  final WrappedMasterKey wrapped;
  final String recoveryKey;
}

class RecoveryResult {
  const RecoveryResult(this.masterKey, this.wrapped);

  final SecretKey masterKey;
  final WrappedMasterKey wrapped;
}
