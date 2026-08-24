import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';

class _UnauthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

class _AuthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    status: AuthStatus.authenticated,
    accountId: 'account-1',
    displayName: 'Alice',
  );
}

class _MemorySecureStorage extends SecureStorageService {
  bool cleared = false;

  @override
  Future<void> clearAuth() async {
    cleared = true;
  }
}

final _queueAuthGateTestProvider = Provider<bool>(
  (ref) => requireAuthenticatedAction(ref, AuthPromptReason.queueExecution),
);

void main() {
  test('unauthenticated generation is blocked before changing parameters', () async {
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_UnauthenticatedAuthNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    container.read(authNotifierProvider);
    const params = ImageParams(
      prompt: 'keep this prompt',
      negativePrompt: 'keep this negative prompt',
      width: 512,
      height: 768,
    );

    await container
        .read(imageGenerationNotifierProvider.notifier)
        .generate(params);

    final generation = container.read(imageGenerationNotifierProvider);
    final request = container.read(authPromptRequestProvider);
    expect(generation.status, GenerationStatus.error);
    expect(generation.errorMessage, 'AUTH_REQUIRED');
    expect(params.prompt, 'keep this prompt');
    expect(params.negativePrompt, 'keep this negative prompt');
    expect(request?.reason, AuthPromptReason.imageGeneration);
  });

  test('queue auth gate publishes a queue-specific login request', () {
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_UnauthenticatedAuthNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    container.read(authNotifierProvider);
    expect(container.read(_queueAuthGateTestProvider), isFalse);
    expect(
      container.read(authPromptRequestProvider)?.reason,
      AuthPromptReason.queueExecution,
    );
  });

  test('expired session logout publishes a login request', () async {
    final storage = _MemorySecureStorage();
    final container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(storage),
        authNotifierProvider.overrideWith(_AuthenticatedAuthNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(authNotifierProvider.notifier)
        .logout(errorCode: AuthErrorCode.authFailed, httpStatusCode: 401);

    final authState = container.read(authNotifierProvider);
    final request = container.read(authPromptRequestProvider);
    expect(storage.cleared, isTrue);
    expect(authState.status, AuthStatus.error);
    expect(authState.httpStatusCode, 401);
    expect(request?.reason, AuthPromptReason.sessionExpired);
  });

  test('auto-login network failure remains visible and retryable', () {
    final error = DioException(
      type: DioExceptionType.connectionTimeout,
      requestOptions: RequestOptions(path: '/user/subscription'),
    );

    final state = autoLoginFailureState(error);

    expect(state.status, AuthStatus.error);
    expect(state.errorCode, AuthErrorCode.networkTimeout);
  });
}
