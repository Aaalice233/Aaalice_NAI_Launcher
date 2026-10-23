import 'dart:ffi';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// DPAPI 调用失败；[corruptInput] 为真表示输入本身无法解密，否则视为系统暂时不可用
class DpapiException implements Exception {
  const DpapiException(this.errorCode, {required this.corruptInput});

  final int errorCode;
  final bool corruptInput;

  @override
  String toString() =>
      'DpapiException(0x${errorCode.toUnsigned(32).toRadixString(16)}, '
      'corruptInput: $corruptInput)';
}

abstract interface class SecureBlobCipher {
  Uint8List protect(Uint8List plain);

  Uint8List unprotect(Uint8List encrypted);
}

/// 当前用户范围的 DPAPI；参数与 flutter_secure_storage_windows 一致，新旧版本可互读同一文件
class DpapiCipher implements SecureBlobCipher {
  const DpapiCipher();

  static final Uint8List _selfTestPlain = Uint8List.fromList(const [
    0x6E,
    0x61,
    0x69,
  ]);

  @override
  Uint8List protect(Uint8List plain) => _transform(plain, protect: true);

  @override
  Uint8List unprotect(Uint8List encrypted) {
    // 空输入时 CryptUnprotectData 失败但不设置错误码
    if (encrypted.isEmpty) {
      throw const DpapiException(0, corruptInput: true);
    }
    try {
      return _transform(encrypted, protect: false);
    } on DpapiException {
      // Dart VM 会在 FFI 调用之间改写线程 last error，错误码不可信：用自检区分输入损坏与 DPAPI 不可用
      if (!_selfTestPasses()) rethrow;
      try {
        return _transform(encrypted, protect: false);
      } on DpapiException catch (retry) {
        throw DpapiException(retry.errorCode, corruptInput: true);
      }
    }
  }

  bool _selfTestPasses() {
    try {
      final restored = _transform(
        _transform(_selfTestPlain, protect: true),
        protect: false,
      );
      return const ListEquality<int>().equals(restored, _selfTestPlain);
    } on DpapiException {
      return false;
    }
  }

  Uint8List _transform(Uint8List input, {required bool protect}) {
    return using((arena) {
      final inputBuffer = arena<Uint8>(input.isEmpty ? 1 : input.length);
      final inputView = inputBuffer.asTypedList(input.length)..setAll(0, input);
      final inputBlob = arena<CRYPT_INTEGER_BLOB>()
        ..ref.cbData = input.length
        ..ref.pbData = inputBuffer;
      final outputBlob = arena<CRYPT_INTEGER_BLOB>();
      try {
        final succeeded = protect
            ? CryptProtectData(
                inputBlob,
                nullptr,
                nullptr,
                nullptr,
                nullptr,
                0,
                outputBlob,
              )
            : CryptUnprotectData(
                inputBlob,
                nullptr,
                nullptr,
                nullptr,
                nullptr,
                0,
                outputBlob,
              );
        if (succeeded == 0) {
          throw DpapiException(
            GetLastError().toUnsigned(32),
            corruptInput: false,
          );
        }
        final output = outputBlob.ref.pbData;
        if (output == nullptr) {
          throw const DpapiException(ERROR_OUTOFMEMORY, corruptInput: false);
        }
        try {
          final outputView = output.asTypedList(outputBlob.ref.cbData);
          final copy = Uint8List.fromList(outputView);
          // 明文在交还系统堆前清零，避免令牌残留在已释放的内存里
          if (!protect) outputView.fillRange(0, outputView.length, 0);
          return copy;
        } finally {
          LocalFree(output);
        }
      } finally {
        inputView.fillRange(0, inputView.length, 0);
      }
    });
  }
}
