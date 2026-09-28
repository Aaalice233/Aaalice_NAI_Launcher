import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/cloud_sync/oauth/cloud_drive_oauth_models.dart';
import 'package:nai_launcher/core/cloud_sync/oauth/cloud_drive_oauth_secure_store.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';

void main() {
  test(
    'OAuth sessions are provider/account isolated in secure storage',
    () async {
      final backend = _Storage();
      final values = <String, String>{};
      when(
        () => backend.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((invocation) async {
        values[invocation.namedArguments[#key]! as String] =
            invocation.namedArguments[#value]! as String;
      });
      when(() => backend.read(key: any(named: 'key'))).thenAnswer(
        (invocation) async =>
            values[invocation.namedArguments[#key]! as String],
      );
      when(() => backend.delete(key: any(named: 'key'))).thenAnswer(
        (invocation) async =>
            values.remove(invocation.namedArguments[#key]! as String),
      );
      final store = SecureCloudDriveOAuthSessionStore(
        SecureStorageService(storage: backend),
      );
      final expiry = DateTime.utc(2026, 3, 1, 13);
      final google = _session(
        CloudDriveOAuthProvider.googleDrive,
        'same-account',
        'google-token',
        expiry,
      );
      final microsoft = _session(
        CloudDriveOAuthProvider.oneDrive,
        'same-account',
        'microsoft-token',
        expiry,
      );

      await store.write(google);
      await store.write(microsoft);

      expect(values, hasLength(2));
      expect(values.keys.every((key) => !key.contains('same-account')), isTrue);
      expect(
        (await store.read(google.provider, google.accountId))!.accessToken,
        'google-token',
      );
      expect(
        (await store.read(
          microsoft.provider,
          microsoft.accountId,
        ))!.accessToken,
        'microsoft-token',
      );

      await store.delete(google.provider, google.accountId);
      expect(await store.read(google.provider, google.accountId), isNull);
      expect(
        await store.read(microsoft.provider, microsoft.accountId),
        isNotNull,
      );
    },
  );
}

CloudDriveOAuthSession _session(
  CloudDriveOAuthProvider provider,
  String accountId,
  String token,
  DateTime expiry,
) => CloudDriveOAuthSession(
  provider: provider,
  accountId: accountId,
  displayIdentifier: 'user@example.test',
  accessToken: token,
  refreshToken: '$token-refresh',
  expiresAt: expiry,
);

class _Storage extends Mock implements FlutterSecureStorage {}
