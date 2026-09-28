import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/storage/secure_storage_service.dart';
import '../../core/utils/app_logger.dart';
import '../datasources/remote/gelbooru_api_service.dart';
import '../models/online_gallery/gelbooru_credentials.dart';

part 'gelbooru_auth_service.g.dart';

enum GelbooruAuthStatus { loading, unconfigured, authenticated, invalid }

enum GelbooruAuthError {
  invalidInput,
  invalidCredentials,
  rateLimited,
  timeout,
  server,
  network,
  malformedResponse,
  storage,
  unknown,
}

class GelbooruAuthState {
  final GelbooruCredentials? credentials;
  final GelbooruAuthStatus status;
  final GelbooruAuthError? error;

  const GelbooruAuthState({
    this.credentials,
    this.status = GelbooruAuthStatus.loading,
    this.error,
  });

  bool get isConfigured => credentials != null;
  bool get isAuthenticated =>
      credentials != null && status == GelbooruAuthStatus.authenticated;

  GelbooruAuthState copyWith({
    GelbooruCredentials? credentials,
    GelbooruAuthStatus? status,
    GelbooruAuthError? error,
    bool clearCredentials = false,
    bool clearError = false,
  }) {
    return GelbooruAuthState(
      credentials: clearCredentials ? null : (credentials ?? this.credentials),
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

@Riverpod(keepAlive: true)
class GelbooruAuth extends _$GelbooruAuth {
  late final Future<void> _initialization;

  @override
  GelbooruAuthState build() {
    _initialization = _loadSavedCredentials();
    return const GelbooruAuthState();
  }

  Future<void> ensureInitialized() => _initialization;

  Future<void> _loadSavedCredentials() async {
    final storage = ref.read(secureStorageServiceProvider);
    final encoded = await storage.getGelbooruCredentials();
    if (encoded == null || encoded.isEmpty) {
      state = const GelbooruAuthState(status: GelbooruAuthStatus.unconfigured);
      return;
    }

    try {
      final credentials = GelbooruCredentials.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
      state = GelbooruAuthState(
        credentials: credentials,
        status: GelbooruAuthStatus.authenticated,
      );
    } catch (_) {
      try {
        await storage.deleteGelbooruCredentials();
      } catch (_) {
        // The unreadable value is ignored even if the platform store is locked.
      }
      state = const GelbooruAuthState(
        status: GelbooruAuthStatus.unconfigured,
        error: GelbooruAuthError.storage,
      );
      AppLogger.w('Discarded malformed Gelbooru credentials', 'GelbooruAuth');
    }
  }

  Future<bool> configure(String userIdText, String apiKey) async {
    final userId = int.tryParse(userIdText.trim());
    final normalizedApiKey = apiKey.trim();
    if (userId == null || userId <= 0 || normalizedApiKey.isEmpty) {
      state = state.copyWith(error: GelbooruAuthError.invalidInput);
      return false;
    }

    final previousState = state;
    state = state.copyWith(
      status: GelbooruAuthStatus.loading,
      clearError: true,
    );
    final credentials = GelbooruCredentials(
      userId: userId,
      apiKey: normalizedApiKey,
    );

    try {
      await ref.read(gelbooruApiServiceProvider).verifyCredentials(credentials);
      final storage = ref.read(secureStorageServiceProvider);
      final encoded = jsonEncode(credentials.toJson());
      await storage.saveGelbooruCredentials(encoded);
      final readBack = await storage.getGelbooruCredentials();
      if (readBack == null) {
        throw const FormatException('Credential read-back failed');
      }
      final persisted = GelbooruCredentials.fromJson(
        jsonDecode(readBack) as Map<String, dynamic>,
      );
      if (!credentials.hasSameValues(persisted)) {
        throw const FormatException('Credential read-back mismatch');
      }

      state = GelbooruAuthState(
        credentials: credentials,
        status: GelbooruAuthStatus.authenticated,
      );
      AppLogger.i('Gelbooru credentials verified', 'GelbooruAuth');
      return true;
    } on GelbooruApiException catch (error) {
      if (error.type == GelbooruApiErrorType.invalidCredentials) {
        state = GelbooruAuthState(
          credentials: credentials,
          status: GelbooruAuthStatus.invalid,
          error: GelbooruAuthError.invalidCredentials,
        );
      } else {
        state = previousState.copyWith(error: _mapApiError(error.type));
      }
      return false;
    } catch (_) {
      state = previousState.copyWith(error: GelbooruAuthError.storage);
      return false;
    }
  }

  void markInvalid() {
    if (state.credentials == null) return;
    state = state.copyWith(
      status: GelbooruAuthStatus.invalid,
      error: GelbooruAuthError.invalidCredentials,
    );
  }

  Future<void> logout() async {
    try {
      await ref.read(secureStorageServiceProvider).deleteGelbooruCredentials();
      state = const GelbooruAuthState(status: GelbooruAuthStatus.unconfigured);
    } catch (_) {
      state = state.copyWith(error: GelbooruAuthError.storage);
    }
  }

  void clearError() {
    state = state.copyWith(clearError: true);
  }

  GelbooruAuthError _mapApiError(GelbooruApiErrorType type) {
    switch (type) {
      case GelbooruApiErrorType.invalidCredentials:
        return GelbooruAuthError.invalidCredentials;
      case GelbooruApiErrorType.rateLimited:
        return GelbooruAuthError.rateLimited;
      case GelbooruApiErrorType.timeout:
        return GelbooruAuthError.timeout;
      case GelbooruApiErrorType.server:
        return GelbooruAuthError.server;
      case GelbooruApiErrorType.network:
        return GelbooruAuthError.network;
      case GelbooruApiErrorType.malformedResponse:
        return GelbooruAuthError.malformedResponse;
      case GelbooruApiErrorType.cancelled:
      case GelbooruApiErrorType.unknown:
        return GelbooruAuthError.unknown;
    }
  }
}
