import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';
import 'package:nai_launcher/core/storage/secure_storage_unavailable_exception.dart';

void main() {
  late _Storage backend;
  late SecureStorageService service;

  setUp(() async {
    backend = _Storage();
    when(() => backend.delete(key: any(named: 'key'))).thenAnswer((_) async {});
    service = SecureStorageService(storage: backend);
    // 内存缓存是静态的，跨用例共享
    await service.deleteMcpServerToken();
  });

  test('安全存储暂不可用时 MCP 令牌读取向上抛出，而不是当作没有令牌', () async {
    when(() => backend.read(key: any(named: 'key'))).thenThrow(
      const SecureStorageUnavailableException(
        SecureStorageStep.readFile,
        osErrorCode: 32,
      ),
    );

    await expectLater(
      service.getMcpServerToken(),
      throwsA(isA<SecureStorageUnavailableException>()),
    );
  });

  test('其他平台读取错误仍按缺失处理', () async {
    when(
      () => backend.read(key: any(named: 'key')),
    ).thenThrow(StateError('platform channel missing'));

    expect(await service.getMcpServerToken(), isNull);
  });
}

class _Storage extends Mock implements FlutterSecureStorage {}
