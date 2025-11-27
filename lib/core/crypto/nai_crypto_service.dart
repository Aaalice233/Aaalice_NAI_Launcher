import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../constants/api_constants.dart';
import '../utils/app_logger.dart';

part 'nai_crypto_service.g.dart';

/// NovelAI 加密服务
/// 实现 NovelAI 的认证加密算法：Blake2b + Argon2id
class NAICryptoService {
  /// Blake2b 哈希算法实例 (16字节输出，与 Python digest_size=16 一致)
  final Blake2b _blake2b16 = Blake2b(hashLengthInBytes: 16);

  /// 生成 Access Key 的盐值
  ///
  /// NovelAI 的盐值生成规则：
  /// pre_salt = password[:6] + email + "novelai_data_access_key"
  /// salt = blake2b(pre_salt, digest_size=16)
  Future<Uint8List> generateAccessKeySalt(String email, String password) async {
    // 取密码前6个字符（如果不足6个则取全部）
    final passwordPrefix = password.substring(0, min(6, password.length));

    // 构造预盐值
    final preSalt = '$passwordPrefix$email${ApiConstants.accessKeySuffix}';

    // 使用 Blake2b 哈希生成盐值 (直接输出16字节)
    final hash = await _blake2b16.hash(utf8.encode(preSalt));

    return Uint8List.fromList(hash.bytes);
  }

  /// 使用 Argon2id 派生 Access Key
  ///
  /// NovelAI 的 Argon2id 参数：
  /// - iterations (time_cost): 2
  /// - memory: 2000 KB (~2MB)
  /// - parallelism: 1
  /// - hash_len: 64 bytes
  ///
  /// 返回 Base64url 编码的 Access Key（前64字符）
  Future<String> deriveAccessKey(String email, String password) async {
    AppLogger.crypto('deriveAccessKey started', email: email);

    try {
      // 1. 生成盐值
      final salt = await generateAccessKeySalt(email, password);
      AppLogger.d('Salt generated: ${salt.length} bytes', 'Crypto');

      // 2. 配置 Argon2id 参数
      // 参考 Python: int(2000000 / 1024) = 1953 KiB
      // Dart cryptography 包的 memory 参数单位是 KB
      const memoryKB = 2000000 ~/ 1024; // = 1953 KB
      AppLogger.d('Argon2id params: memory=$memoryKB KB, iterations=2, parallelism=1, hashLength=64', 'Crypto');

      final argon2id = Argon2id(
        parallelism: 1,
        memory: memoryKB, // 1953 KB (与 Python memory_cost 一致)
        iterations: 2,
        hashLength: 64,
      );

      // 3. 派生密钥
      final secretKey = await argon2id.deriveKey(
        secretKey: SecretKey(utf8.encode(password)),
        nonce: salt,
      );

      // 4. 提取密钥字节
      final keyBytes = await secretKey.extractBytes();
      AppLogger.d('Key derived: ${keyBytes.length} bytes', 'Crypto');

      // 5. Base64url 编码并截取前64字符
      final encoded = base64Url.encode(keyBytes);

      // 移除 padding 并截取前64字符
      final accessKey = encoded.replaceAll('=', '');
      final result = accessKey.substring(0, min(64, accessKey.length));

      AppLogger.crypto('deriveAccessKey completed', email: email, keyLength: result.length, success: true);
      return result;
    } catch (e, stackTrace) {
      AppLogger.e('deriveAccessKey failed', e, stackTrace, 'Crypto');
      rethrow;
    }
  }

  /// 生成加密密钥的盐值（用于用户数据加密）
  Future<Uint8List> generateEncryptionKeySalt(String email, String password) async {
    final passwordPrefix = password.substring(0, min(6, password.length));
    final preSalt = '$passwordPrefix$email${ApiConstants.encryptionKeySuffix}';

    // 使用 Blake2b 哈希生成盐值 (直接输出16字节)
    final hash = await _blake2b16.hash(utf8.encode(preSalt));

    return Uint8List.fromList(hash.bytes);
  }

  /// 派生加密密钥（用于用户数据加密）
  ///
  /// 与 Access Key 类似，但 hash_len = 128，然后再次 Blake2b 哈希
  Future<Uint8List> deriveEncryptionKey(String email, String password) async {
    final salt = await generateEncryptionKeySalt(email, password);

    final argon2id = Argon2id(
      parallelism: 1,
      memory: 2000000 ~/ 1024, // 1953 KB (与 Python memory_cost 一致)
      iterations: 2,
      hashLength: 128,
    );

    final secretKey = await argon2id.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );

    final keyBytes = await secretKey.extractBytes();

    // 再次使用 Blake2b 哈希，输出32字节
    final blake2b32 = Blake2b(hashLengthInBytes: 32);
    final finalHash = await blake2b32.hash(keyBytes);

    return Uint8List.fromList(finalHash.bytes);
  }
}

/// NAICryptoService Provider
@riverpod
NAICryptoService naiCryptoService(Ref ref) {
  return NAICryptoService();
}
