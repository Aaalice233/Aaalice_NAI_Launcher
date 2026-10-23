import 'dart:typed_data';

import 'package:nai_launcher/core/storage/windows/dpapi_cipher.dart';

/// 可在任意平台运行的可逆加密替身；不带魔数的输入按 DPAPI 的损坏输入处理
class FakeSecureBlobCipher implements SecureBlobCipher {
  static const List<int> _magic = [0x46, 0x4B];
  static const int _mask = 0x5A;

  bool protectUnavailable = false;
  bool unprotectUnavailable = false;
  int protectCalls = 0;

  @override
  Uint8List protect(Uint8List plain) {
    protectCalls++;
    if (protectUnavailable) {
      throw const DpapiException(14, corruptInput: false);
    }
    return Uint8List.fromList([..._magic, for (final b in plain) b ^ _mask]);
  }

  @override
  Uint8List unprotect(Uint8List encrypted) {
    if (unprotectUnavailable) {
      throw const DpapiException(1722, corruptInput: false);
    }
    if (encrypted.length < _magic.length ||
        encrypted[0] != _magic[0] ||
        encrypted[1] != _magic[1]) {
      throw const DpapiException(13, corruptInput: true);
    }
    return Uint8List.fromList([
      for (final b in encrypted.skip(_magic.length)) b ^ _mask,
    ]);
  }
}
