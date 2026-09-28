import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_generation_api_service.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';

class _UnauthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.unauthenticated);
}

class _InitialAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState();
}

class _LoadingAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.loading);
}

class _ErrorAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    status: AuthStatus.error,
    errorCode: AuthErrorCode.networkError,
  );
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

final _authGateRefProvider = Provider<Ref>((ref) => ref);

void main() {
  for (final factory in <AuthNotifier Function()>[
    _UnauthenticatedAuthNotifier.new,
    _LoadingAuthNotifier.new,
  ]) {
    test(
      'generation auth gate blocks before API or parameter changes',
      () async {
        final container = ProviderContainer(
          overrides: [authNotifierProvider.overrideWith(factory)],
        );
        addTearDown(container.dispose);

        container.read(authNotifierProvider);
        const params = ImageParams(
          prompt: 'keep this prompt',
          negativePrompt: 'keep this negative prompt',
          width: 512,
          height: 768,
        );

        expect(container.exists(naiImageGenerationApiServiceProvider), isFalse);
        await container
            .read(imageGenerationNotifierProvider.notifier)
            .generate(params);

        final generation = container.read(imageGenerationNotifierProvider);
        final request = container.read(authPromptRequestProvider);
        expect(container.exists(naiImageGenerationApiServiceProvider), isFalse);
        expect(generation.status, GenerationStatus.idle);
        expect(generation.errorMessage, isNull);
        expect(params.prompt, 'keep this prompt');
        expect(params.negativePrompt, 'keep this negative prompt');
        expect(request?.reason, AuthPromptReason.imageGeneration);
      },
    );
  }

  test('all non-authenticated states are rejected with the exact reason', () {
    final factories = <AuthNotifier Function()>[
      _InitialAuthNotifier.new,
      _LoadingAuthNotifier.new,
      _UnauthenticatedAuthNotifier.new,
      _ErrorAuthNotifier.new,
    ];

    for (final factory in factories) {
      final container = ProviderContainer(
        overrides: [authNotifierProvider.overrideWith(factory)],
      );
      final ref = container.read(_authGateRefProvider);

      expect(
        requireAuthenticatedAction(ref, AuthPromptReason.directorTools),
        isFalse,
      );
      expect(
        container.read(authPromptRequestProvider)?.reason,
        AuthPromptReason.directorTools,
      );
      container.dispose();
    }
  });

  test(
    'pending login prompts use monotonic ids and exact consume semantics',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(authPromptRequestProvider.notifier);

      notifier.publish(AuthPromptReason.kritaBridge);
      final first = container.read(authPromptRequestProvider)!;
      notifier.consume(first.id + 1);
      expect(container.read(authPromptRequestProvider)?.id, first.id);

      notifier.publish(AuthPromptReason.vibeEncoding);
      final second = container.read(authPromptRequestProvider)!;
      expect(second.id, greaterThan(first.id));
      notifier.consume(first.id);
      expect(container.read(authPromptRequestProvider)?.id, second.id);

      notifier.consume(second.id);
      expect(container.read(authPromptRequestProvider), isNull);
    },
  );

  test('Krita prompt remains pending until a late listener consumes it', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(authPromptRequestProvider.notifier);
    notifier.publish(AuthPromptReason.kritaBridge);

    AuthPromptRequest? delivered;
    final subscription = container.listen<AuthPromptRequest?>(
      authPromptRequestProvider,
      (_, next) => delivered = next,
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    expect(delivered?.reason, AuthPromptReason.kritaBridge);
    notifier.consume(delivered!.id);
    expect(container.read(authPromptRequestProvider), isNull);
  });

  test('queue auth gate publishes a queue-specific login request', () {
    final container = ProviderContainer(
      overrides: [
        authNotifierProvider.overrideWith(_UnauthenticatedAuthNotifier.new),
      ],
    );
    addTearDown(container.dispose);

    container.read(authNotifierProvider);
    final ref = container.read(_authGateRefProvider);
    expect(
      requireAuthenticatedAction(ref, AuthPromptReason.queueExecution),
      isFalse,
    );
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
