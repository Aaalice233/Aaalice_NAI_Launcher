import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/auth_error_service.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';
import 'package:nai_launcher/core/storage/secure_storage_unavailable_exception.dart';
import 'package:nai_launcher/data/datasources/remote/nai_auth_api_service.dart';
import 'package:nai_launcher/data/models/auth/saved_account.dart';
import 'package:nai_launcher/data/services/account_manager_provider.dart';
import 'package:nai_launcher/data/services/auth_provider.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _unavailable = SecureStorageUnavailableException(
  SecureStorageStep.readFile,
  osErrorCode: 32,
);

final _alice = SavedAccount(
  id: 'alice',
  email: 'alice@example.invalid',
  createdAt: DateTime.utc(2026),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  ProviderContainer autoLoginContainer(_RecordingStorage storage) {
    final container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(storage),
        naiAuthApiServiceProvider.overrideWithValue(NAIAuthApiService(Dio())),
        accountManagerNotifierProvider.overrideWith(_UnreadableAccounts.new),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('存储不可用映射为独立错误码', () {
    expect(AuthState.parseError(_unavailable), (
      AuthErrorCode.secureStorageUnavailable,
      null,
    ));
    expect(
      autoLoginFailureState(_unavailable).errorCode,
      AuthErrorCode.secureStorageUnavailable,
    );
  });

  test('错误文案提示稍后重试，不再附加重复的恢复建议', () {
    final l10n = lookupAppLocalizations(const Locale('zh'));
    final service = AuthErrorService();

    final message = service.getErrorMessage(
      l10n,
      AuthErrorCode.secureStorageUnavailable,
      null,
    );

    expect(message.errorText, l10n.common_secureStorageUnavailable);
    expect(message.hasRecoveryHint, isFalse);
  });

  test('自动登录读不到账号 Token 时保留为可重试的失败状态', () async {
    final storage = _RecordingStorage();
    final container = autoLoginContainer(storage);

    await container.read(authNotifierProvider.notifier).whenInitialized;

    final state = container.read(authNotifierProvider);
    expect(state.status, AuthStatus.error);
    expect(state.errorCode, AuthErrorCode.secureStorageUnavailable);
    expect(storage.clearAuthCalls, 0);
  });

  test('全局 Token 存在但账号 Token 读不到时不清除会话', () async {
    final storage = _RecordingStorage(accessToken: 'pst-session');
    final container = autoLoginContainer(storage);

    await container.read(authNotifierProvider.notifier).whenInitialized;

    final state = container.read(authNotifierProvider);
    expect(state.status, AuthStatus.error);
    expect(state.errorCode, AuthErrorCode.secureStorageUnavailable);
    expect(storage.clearAuthCalls, 0);
  });

  test('登出时存储不可用仍完成登出', () async {
    final storage = _RecordingStorage(clearAuthFailure: _unavailable);
    final container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(storage),
        authNotifierProvider.overrideWith(_SignedInAuthNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authNotifierProvider.notifier).logout();

    expect(
      container.read(authNotifierProvider).status,
      AuthStatus.unauthenticated,
    );
    expect(storage.clearAuthCalls, 1);
  });
}

class _RecordingStorage extends SecureStorageService {
  _RecordingStorage({this.accessToken, this.clearAuthFailure});

  final String? accessToken;
  final Object? clearAuthFailure;
  int clearAuthCalls = 0;

  @override
  Future<String?> getAccessToken() async => accessToken;

  @override
  Future<void> clearAuth() async {
    clearAuthCalls++;
    final failure = clearAuthFailure;
    if (failure != null) throw failure;
  }
}

class _UnreadableAccounts extends AccountManagerNotifier {
  @override
  AccountManagerState build() => AccountManagerState(accounts: [_alice]);

  @override
  Future<String?> getAccountToken(String accountId) async => throw _unavailable;
}

class _SignedInAuthNotifier extends AuthNotifier {
  @override
  AuthState build() =>
      AuthState(status: AuthStatus.authenticated, accountId: _alice.id);
}
