import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/network/dio_client.dart';
import 'package:nai_launcher/core/network/nai_api_endpoint.dart';
import 'package:nai_launcher/core/network/nai_api_endpoint_service.dart';
import 'package:nai_launcher/core/storage/secure_storage_service.dart';
import 'package:nai_launcher/data/datasources/remote/nai_auth_api_service.dart';
import 'package:nai_launcher/data/services/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _oldToken = 'pst-existing-session-12345';
const _newToken = 'pst-candidate-session-67890';
const _oldState = AuthState(
  status: AuthStatus.authenticated,
  accountId: 'existing',
  displayName: 'Existing account',
  subscriptionInfo: {'tier': 3},
);
final _interceptorProvider = Provider<AuthInterceptor>(AuthInterceptor.new);

void main() {
  late _ObservedSecureStorage storage;
  late ProviderContainer container;
  late NaiApiEndpointService endpoints;
  late Dio dio;
  late _ScriptedAdapter adapter;
  late Map<String, String> savedCredentials;
  const secureStorage = FlutterSecureStorage();

  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({'auto_login_enabled': true});
    storage = _ObservedSecureStorage(storage: secureStorage);
    await storage.clearAll();
    await storage.saveAuth(
      accessToken: _oldToken,
      expiry: DateTime.utc(2030),
      email: 'existing@example.invalid',
    );
    await storage.saveAccountToken('existing', _oldToken);
    savedCredentials = Map.of(await secureStorage.readAll());
    endpoints = NaiApiEndpointService();
    adapter = _ScriptedAdapter();
    dio = Dio()..httpClientAdapter = adapter;
    container = ProviderContainer(
      overrides: [
        secureStorageServiceProvider.overrideWithValue(storage),
        naiApiEndpointServiceProvider.overrideWithValue(endpoints),
        naiAuthApiServiceProvider.overrideWithValue(NAIAuthApiService(dio)),
        authNotifierProvider.overrideWith(_SessionAuthNotifier.new),
      ],
    );
    dio.interceptors.add(container.read(_interceptorProvider));
  });

  tearDown(() async {
    dio.close(force: true);
    container.dispose();
    await storage.clearAll();
  });

  Future<bool> login() => container
      .read(authNotifierProvider.notifier)
      .loginWithToken(
        _newToken,
        accountId: 'candidate',
        displayName: 'Candidate',
      );

  for (final thirdParty in [false, true]) {
    for (final failure in ['connection', 'timeout', 'unauthorized']) {
      final accountType = thirdParty ? 'third-party' : 'official';
      test(
        'failed $failure login preserves the $accountType session',
        () async {
          final previousEndpoint = thirdParty
              ? NaiApiEndpointConfig.fromInput(
                  mainBaseUrl: 'https://relay.invalid',
                )
              : NaiApiEndpointConfig.official;
          endpoints.setCurrent(previousEndpoint);
          Map<String, String>? credentialsDuringValidation;
          NaiApiEndpointConfig? endpointDuringValidation;
          adapter.respond = (options) async {
            credentialsDuringValidation = Map.of(await secureStorage.readAll());
            endpointDuringValidation = endpoints.current;
            if (failure == 'unauthorized') {
              return ResponseBody.fromString('unauthorized', 401);
            }
            throw DioException(
              requestOptions: options,
              type: failure == 'timeout'
                  ? DioExceptionType.connectionTimeout
                  : DioExceptionType.connectionError,
            );
          };

          expect(await login(), isFalse);
          expect(credentialsDuringValidation, savedCredentials);
          expect(endpointDuringValidation, previousEndpoint);
          expect(await secureStorage.readAll(), savedCredentials);
          expect(await storage.getAccessToken(), _oldToken);
          expect(endpoints.current, previousEndpoint);
          final state = container.read(authNotifierProvider);
          expect(state.isAuthenticated, isTrue);
          expect(state.accountId, _oldState.accountId);
          expect(state.displayName, _oldState.displayName);
          expect(state.subscriptionInfo, _oldState.subscriptionInfo);
          expect(state.hasError, isTrue);
          expect(
            adapter.requests.single.headers['Authorization'],
            'Bearer $_newToken',
          );
          expect(adapter.requests.single.uri.host, 'image.novelai.net');

          adapter.respond = (_) async => _subscriptionResponse();
          await dio.get<dynamic>(endpoints.userUrl('/user/subscription'));
          expect(
            adapter.requests.last.headers['Authorization'],
            'Bearer $_oldToken',
          );
        },
      );
    }
  }

  test(
    'a successful validation replaces credentials only after validating',
    () async {
      final previousEndpoint = NaiApiEndpointConfig.fromInput(
        mainBaseUrl: 'https://relay.invalid',
      );
      endpoints.setCurrent(previousEndpoint);
      Map<String, String>? credentialsDuringValidation;
      NaiApiEndpointConfig? endpointDuringValidation;
      NaiApiEndpointConfig? endpointDuringSave;
      storage.afterSave = () => endpointDuringSave = endpoints.current;
      adapter.respond = (_) async {
        credentialsDuringValidation = Map.of(await secureStorage.readAll());
        endpointDuringValidation = endpoints.current;
        return _subscriptionResponse();
      };

      expect(await login(), isTrue);
      expect(credentialsDuringValidation, savedCredentials);
      expect(endpointDuringValidation, previousEndpoint);
      expect(endpointDuringSave, NaiApiEndpointConfig.official);
      expect(await storage.getAccessToken(), _newToken);
      expect(await storage.getUserEmail(), 'Candidate');
      expect(await storage.getAccountToken('existing'), _oldToken);
      expect(endpoints.current, NaiApiEndpointConfig.official);
      expect(container.read(authNotifierProvider).accountId, 'candidate');
    },
  );

  test('invalid token format does not touch stored credentials', () async {
    final success = await container
        .read(authNotifierProvider.notifier)
        .loginWithToken('invalid');

    expect(success, isFalse);
    expect(adapter.requests, isEmpty);
    expect(await secureStorage.readAll(), savedCredentials);
    expect(await storage.getAccessToken(), _oldToken);
    expect(container.read(authNotifierProvider).accountId, 'existing');
  });
}

ResponseBody _subscriptionResponse() => ResponseBody.fromString(
  '{"tier":3}',
  200,
  headers: {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  },
);

class _SessionAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => _oldState;
}

class _ObservedSecureStorage extends SecureStorageService {
  _ObservedSecureStorage({required super.storage});

  void Function()? afterSave;

  @override
  Future<void> saveAuth({
    required String accessToken,
    required DateTime expiry,
    required String email,
  }) async {
    await super.saveAuth(
      accessToken: accessToken,
      expiry: expiry,
      email: email,
    );
    afterSave?.call();
  }
}

class _ScriptedAdapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Future<ResponseBody> Function(RequestOptions) respond = (_) async =>
      _subscriptionResponse();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}
