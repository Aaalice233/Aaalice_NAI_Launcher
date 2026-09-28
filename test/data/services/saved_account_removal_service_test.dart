import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/auth_error_service.dart';
import 'package:nai_launcher/data/services/account_manager_provider.dart';
import 'package:nai_launcher/data/services/auth_provider.dart';
import 'package:nai_launcher/data/services/saved_account_removal_service.dart';

void main() {
  late List<String> calls;

  ProviderContainer createContainer({
    required String? sessionAccountId,
    Error? removalError,
  }) {
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(
          () => _RecordingAuthNotifier(sessionAccountId, calls),
        ),
        accountManagerNotifierProvider.overrideWith(
          () => _RecordingAccountManager(calls, removalError),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() => calls = []);

  test('移除非当前会话账号时不退出登录', () async {
    final container = createContainer(sessionAccountId: 'session');
    final service = container.read(savedAccountRemovalServiceProvider);

    expect(service.isSessionAccount('other'), isFalse);
    await service.remove('other');

    expect(calls, ['remove:other']);
    expect(container.read(authNotifierProvider).accountId, 'session');
  });

  test('移除当前会话账号时先退出登录再移除', () async {
    final container = createContainer(sessionAccountId: 'session');
    final service = container.read(savedAccountRemovalServiceProvider);

    expect(service.isSessionAccount('session'), isTrue);
    await service.remove('session');

    expect(calls, ['logout', 'remove:session']);
    expect(container.read(authNotifierProvider).accountId, isNull);
  });

  test('未登录时移除任何账号都不触发退出登录', () async {
    final container = createContainer(sessionAccountId: null);

    await container.read(savedAccountRemovalServiceProvider).remove('saved');

    expect(calls, ['remove:saved']);
  });

  test('移除失败时把异常交给调用方', () async {
    final container = createContainer(
      sessionAccountId: 'session',
      removalError: StateError('storage unavailable'),
    );

    await expectLater(
      container.read(savedAccountRemovalServiceProvider).remove('other'),
      throwsStateError,
    );
    expect(calls, ['remove:other']);
  });
}

class _RecordingAuthNotifier extends AuthNotifier {
  _RecordingAuthNotifier(this._sessionAccountId, this._calls);

  final String? _sessionAccountId;
  final List<String> _calls;

  @override
  AuthState build() => _sessionAccountId == null
      ? const AuthState(status: AuthStatus.unauthenticated)
      : AuthState(
          status: AuthStatus.authenticated,
          accountId: _sessionAccountId,
        );

  @override
  Future<void> logout({AuthErrorCode? errorCode, int? httpStatusCode}) async {
    _calls.add('logout');
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

class _RecordingAccountManager extends AccountManagerNotifier {
  _RecordingAccountManager(this._calls, this._removalError);

  final List<String> _calls;
  final Error? _removalError;

  @override
  AccountManagerState build() => const AccountManagerState();

  @override
  Future<void> removeAccount(String accountId) async {
    _calls.add('remove:$accountId');
    if (_removalError case final error?) throw error;
  }
}
