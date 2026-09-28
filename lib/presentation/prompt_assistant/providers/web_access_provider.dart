import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/network/web_access/exa_search_client.dart';
import '../../../core/network/web_access/safe_web_reader.dart';
import '../../../core/network/web_access/searxng_search_client.dart';
import '../../../core/network/web_access/web_access_models.dart';
import '../../../core/network/web_access/web_access_http_transport.dart';
import '../../../core/network/web_access/web_access_service.dart';
import '../../../core/storage/local_storage_service.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../providers/proxy_settings_provider.dart';

class WebAccessConfigState {
  const WebAccessConfigState({
    this.config = const WebAccessConfig(),
    this.initialized = false,
    this.hasExaApiKey = false,
  });

  final WebAccessConfig config;
  final bool initialized;
  final bool hasExaApiKey;

  WebAccessConfigState copyWith({
    WebAccessConfig? config,
    bool? initialized,
    bool? hasExaApiKey,
  }) {
    return WebAccessConfigState(
      config: config ?? this.config,
      initialized: initialized ?? this.initialized,
      hasExaApiKey: hasExaApiKey ?? this.hasExaApiKey,
    );
  }
}

final webAccessConfigProvider =
    StateNotifierProvider<WebAccessConfigNotifier, WebAccessConfigState>(
      (ref) => WebAccessConfigNotifier(ref),
    );

class WebAccessConfigNotifier extends StateNotifier<WebAccessConfigState> {
  WebAccessConfigNotifier(this._ref) : super(const WebAccessConfigState()) {
    _load();
  }

  final Ref _ref;
  int _apiKeyMutation = 0;

  LocalStorageService get _local => _ref.read(localStorageServiceProvider);
  SecureStorageService get _secure => _ref.read(secureStorageServiceProvider);

  Future<void> _load() async {
    var config = const WebAccessConfig();
    final raw = _local.getSetting<String>(StorageKeys.agentWebAccessConfigJson);
    if (raw != null && raw.isNotEmpty) {
      try {
        config = WebAccessConfig.decode(raw);
      } catch (_) {
        config = const WebAccessConfig();
      }
    }
    state = state.copyWith(config: config);
    final keyMutation = _apiKeyMutation;
    final apiKey = await _secure.getAgentWebAccessExaApiKey();
    if (keyMutation == _apiKeyMutation) {
      state = state.copyWith(
        initialized: true,
        hasExaApiKey: apiKey != null && apiKey.trim().isNotEmpty,
      );
    } else {
      state = state.copyWith(initialized: true);
    }
  }

  Future<void> _setConfig(WebAccessConfig config) async {
    state = state.copyWith(config: config);
    await _local.setSetting(
      StorageKeys.agentWebAccessConfigJson,
      config.encode(),
    );
  }

  Future<void> setEnabled(bool value) =>
      _setConfig(state.config.copyWith(enabled: value));

  Future<void> setMode(WebSearchMode value) =>
      _setConfig(state.config.copyWith(mode: value));

  Future<void> setSearxngBaseUrl(String value) =>
      _setConfig(state.config.copyWith(searxngBaseUrl: value.trim()));

  Future<void> setDefaultResultCount(int value) =>
      _setConfig(state.config.copyWith(defaultResultCount: value));

  Future<void> setExaApiKey(String value) async {
    _apiKeyMutation++;
    final key = value.trim();
    if (key.isEmpty) {
      await _secure.deleteAgentWebAccessExaApiKey();
    } else {
      await _secure.saveAgentWebAccessExaApiKey(key);
    }
    state = state.copyWith(hasExaApiKey: key.isNotEmpty);
  }
}

final webAccessDioProvider = Provider<Dio>((ref) {
  final proxyAddress = ref.watch(currentProxyAddressProvider);
  final dio = createWebAccessDio(
    options: _webAccessBaseOptions(),
    proxyAddress: proxyAddress,
  );
  ref.onDispose(() => dio.close(force: true));
  return dio;
});

final webReaderDioProvider = Provider<Dio>((ref) {
  final proxyAddress = ref.watch(currentProxyAddressProvider);
  final dio = createWebAccessDio(
    options: _webAccessBaseOptions(),
    proxyAddress: proxyAddress,
    protectPublicTargetsAtConnect: true,
  );
  ref.onDispose(() => dio.close(force: true));
  return dio;
});

final webAccessGatewayProvider = Provider<WebAccessGateway>((ref) {
  final searchDio = ref.watch(webAccessDioProvider);
  final readerDio = ref.watch(webReaderDioProvider);
  final proxyAddress = ref.watch(currentProxyAddressProvider);
  final secureStorage = ref.watch(secureStorageServiceProvider);
  return WebAccessService(
    searxng: SearxngSearchClient(searchDio),
    exa: ExaSearchClient(searchDio),
    reader: SafeWebReader(
      readerDio,
      trustProxyForHostnames: proxyAddress != null && proxyAddress.isNotEmpty,
    ),
    loadExaApiKey: secureStorage.getAgentWebAccessExaApiKey,
  );
});

BaseOptions _webAccessBaseOptions() => BaseOptions(
  connectTimeout: const Duration(seconds: 20),
  sendTimeout: const Duration(seconds: 30),
  receiveTimeout: const Duration(seconds: 60),
);
