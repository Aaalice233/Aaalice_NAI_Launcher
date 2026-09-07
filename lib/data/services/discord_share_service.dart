import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/community_links.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/storage_keys.dart';
import '../../core/storage/local_storage_service.dart';
import '../../core/storage/secure_storage_service.dart';
import '../../core/utils/image_share_sanitizer.dart';

const discordShareRelayUrl =
    'https://aaalice-discord-share.ljk2515448788ljk.workers.dev';
const discordCommunityUrl = CommunityLinks.discord;
const _discordOAuthOrigin = 'http://127.0.0.1';

class DiscordShareUser {
  const DiscordShareUser({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;

  String get effectiveName {
    final value = displayName?.trim();
    return value == null || value.isEmpty ? username : value;
  }

  factory DiscordShareUser.fromJson(Map<String, dynamic> json) {
    return DiscordShareUser(
      id: '${json['id'] ?? ''}',
      username: '${json['username'] ?? ''}',
      displayName: (json['global_name'] ?? json['display_name'])?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    if (displayName != null) 'display_name': displayName,
    if (avatarUrl != null) 'avatar_url': avatarUrl,
  };
}

class DiscordShareSession {
  const DiscordShareSession({required this.token, required this.user});

  final String token;
  final DiscordShareUser user;

  factory DiscordShareSession.fromJson(Map<String, dynamic> json) {
    return DiscordShareSession(
      token: '${json['token'] ?? ''}',
      user: DiscordShareUser.fromJson(
        Map<String, dynamic>.from(json['user'] as Map? ?? const {}),
      ),
    );
  }

  Map<String, dynamic> toJson() => {'token': token, 'user': user.toJson()};
}

class DiscordShareTarget {
  const DiscordShareTarget({
    required this.id,
    required this.label,
    required this.selectedByDefault,
    required this.preferPromptFile,
  });

  final String id;
  final String label;
  final bool selectedByDefault;
  final bool preferPromptFile;

  factory DiscordShareTarget.fromJson(Map<String, dynamic> json) {
    return DiscordShareTarget(
      id: '${json['id'] ?? ''}',
      label: '${json['label'] ?? ''}',
      selectedByDefault: json['default'] == true,
      preferPromptFile: json['prefer_prompt_file'] == true,
    );
  }
}

class DiscordShareResult {
  const DiscordShareResult({
    required this.deliveredTargets,
    required this.failedTargets,
    this.failedTargetIds = const [],
  });

  final List<String> deliveredTargets;
  final List<String> failedTargets;
  final List<String> failedTargetIds;

  bool get isPartial => failedTargets.isNotEmpty;
}

class DiscordShareException implements Exception {
  const DiscordShareException({
    required this.code,
    required this.message,
    this.status,
    this.communityUrl,
    this.retryAfter,
    this.businessCode,
  });

  final String code;
  final String message;
  final int? status;
  final String? communityUrl;
  final Duration? retryAfter;
  final String? businessCode;

  bool get isUnauthorized => status == 401 || code == 'unauthorized';
  bool get isNotMember => code == 'not_member';

  @override
  String toString() => message;
}

typedef DiscordExternalUrlLauncher = Future<bool> Function(Uri uri);

class DiscordShareService {
  DiscordShareService({
    required SecureStorageService secureStorage,
    required LocalStorageService localStorage,
    Dio? dio,
    DiscordExternalUrlLauncher? externalUrlLauncher,
  }) : _secureStorage = secureStorage,
       _localStorage = localStorage,
       _dio = dio ?? Dio(BaseOptions(baseUrl: discordShareRelayUrl)),
       _externalUrlLauncher =
           externalUrlLauncher ??
           ((uri) => launchUrl(uri, mode: LaunchMode.externalApplication));

  final SecureStorageService _secureStorage;
  final LocalStorageService _localStorage;
  final Dio _dio;
  final DiscordExternalUrlLauncher _externalUrlLauncher;
  Future<DiscordShareResult>? _shareInFlight;

  Future<DiscordShareSession?> loadSession() async {
    final raw = await _secureStorage.read(StorageKeys.discordShareSession);
    if (raw == null || raw.isEmpty) return null;
    try {
      final session = DiscordShareSession.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
      if (session.token.isEmpty || session.user.id.isEmpty) return null;
      return session;
    } catch (_) {
      await clearSession();
      return null;
    }
  }

  Future<void> clearSession() {
    return _secureStorage.delete(StorageKeys.discordShareSession);
  }

  Future<DiscordShareSession> verifySession(DiscordShareSession session) async {
    final response = await _request(
      () => _dio.get<Object?>(
        '/v1/session',
        options: Options(
          headers: _authorizationHeaders(session.token),
          responseType: ResponseType.plain,
        ),
      ),
      clearSessionOnAuthFailure: true,
    );
    final user = DiscordShareUser.fromJson(
      Map<String, dynamic>.from(response['user'] as Map? ?? const {}),
    );
    final verified = DiscordShareSession(token: session.token, user: user);
    await _saveSession(verified);
    return verified;
  }

  Future<DiscordShareSession> authenticate({
    Duration timeout = const Duration(minutes: 5),
    CancelToken? cancelToken,
  }) async {
    final verifier = _randomBase64Url(32);
    final challenge = base64Url
        .encode(sha256.convert(utf8.encode(verifier)).bytes)
        .replaceAll('=', '');
    final nonce = const Uuid().v4().replaceAll('-', '');
    final authorizeUri = Uri.parse('$discordShareRelayUrl/v1/oauth/start')
        .replace(
          queryParameters: {
            'origin': _discordOAuthOrigin,
            'nonce': nonce,
            'challenge': challenge,
          },
        );
    if (!await _externalUrlLauncher(authorizeUri)) {
      throw const DiscordShareException(
        code: 'browser_unavailable',
        message: 'Could not open the Discord verification page.',
      );
    }

    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (cancelToken?.isCancelled == true) {
        throw const DiscordShareException(
          code: 'cancelled',
          message: 'Discord verification was cancelled.',
        );
      }
      late final Response<Object?> response;
      try {
        response = await _dio.post<Object?>(
          '/v1/oauth/result',
          data: {'nonce': nonce, 'verifier': verifier},
          options: Options(
            headers: {'Origin': _discordOAuthOrigin},
            responseType: ResponseType.plain,
            validateStatus: (status) => status != null && status < 500,
          ),
          cancelToken: cancelToken,
        );
      } on DioException catch (error) {
        if (CancelToken.isCancel(error)) {
          throw const DiscordShareException(
            code: 'cancelled',
            message: 'Discord verification was cancelled.',
          );
        }
        final payload = _responsePayload(error.response?.data) ?? {};
        throw _exceptionFromPayload(
          payload,
          error.response?.statusCode,
          fallback: error.message ?? 'Discord verification failed.',
          transportType: error.type,
          retryAfterHeader: error.response?.headers.value('retry-after'),
        );
      }
      final payload =
          _responsePayload(response.data) ?? const <String, dynamic>{};
      if (response.statusCode == 202 || payload['pending'] == true) continue;
      if (response.statusCode != null && response.statusCode! >= 400) {
        throw _exceptionFromPayload(
          payload,
          response.statusCode,
          retryAfterHeader: response.headers.value('retry-after'),
        );
      }
      if (payload['ok'] != true || '${payload['token'] ?? ''}'.isEmpty) {
        throw _exceptionFromPayload(payload, response.statusCode);
      }
      final session = DiscordShareSession(
        token: '${payload['token']}',
        user: DiscordShareUser.fromJson(
          Map<String, dynamic>.from(payload['user'] as Map? ?? const {}),
        ),
      );
      await _saveSession(session);
      return session;
    }
    throw const DiscordShareException(
      code: 'timeout',
      message: 'Discord verification timed out.',
    );
  }

  Future<List<DiscordShareTarget>> loadTargets(
    DiscordShareSession session,
  ) async {
    final payload = await _request(
      () => _dio.get<Object?>(
        '/v1/targets',
        options: Options(
          headers: _authorizationHeaders(session.token),
          responseType: ResponseType.plain,
        ),
      ),
      clearSessionOnAuthFailure: true,
    );
    final targets = (payload['targets'] as List? ?? const [])
        .whereType<Map>()
        .map((entry) => DiscordShareTarget.fromJson(Map.from(entry)))
        .where((entry) => entry.id.isNotEmpty && entry.label.isNotEmpty)
        .toList(growable: false);
    if (targets.isEmpty) {
      throw const DiscordShareException(
        code: 'no_targets',
        message: 'No Discord share channels are available.',
      );
    }
    return targets;
  }

  Set<String> loadSelectedTargetIds(List<DiscordShareTarget> targets) {
    final available = targets.map((entry) => entry.id).toSet();
    final saved = _localStorage.getSetting<List<dynamic>>(
      StorageKeys.discordShareTargetIds,
    );
    final selected = saved
        ?.map((entry) => entry.toString())
        .where(available.contains)
        .toSet();
    if (selected != null) return selected;
    final defaults = targets
        .where((entry) => entry.selectedByDefault)
        .map((entry) => entry.id)
        .toSet();
    return defaults.isNotEmpty ? defaults : {targets.first.id};
  }

  Set<String>? loadPromptCategoryIds() {
    final saved = _localStorage.getSetting<List<dynamic>>(
      StorageKeys.discordSharePromptCategories,
    );
    return saved?.map((entry) => entry.toString()).toSet();
  }

  bool loadIncludeMetadataPreference() =>
      _localStorage.getSetting<bool>(
        StorageKeys.discordShareIncludeMetadata,
        defaultValue: false,
      ) ??
      false;

  bool loadLongPromptAsFilePreference() =>
      _localStorage.getSetting<bool>(
        StorageKeys.discordShareLongPromptAsFile,
        defaultValue: true,
      ) ??
      true;

  Future<void> savePreferences({
    required Set<String> targetIds,
    required Set<String> promptCategoryIds,
    required bool includeMetadata,
    required bool longPromptAsFile,
  }) {
    return Future.wait([
      _localStorage.setSetting(
        StorageKeys.discordShareTargetIds,
        targetIds.toList(growable: false),
      ),
      _localStorage.setSetting(
        StorageKeys.discordSharePromptCategories,
        promptCategoryIds.toList(growable: false),
      ),
      _localStorage.setSetting(
        StorageKeys.discordShareIncludeMetadata,
        includeMetadata,
      ),
      _localStorage.setSetting(
        StorageKeys.discordShareLongPromptAsFile,
        longPromptAsFile,
      ),
    ]).then((_) {});
  }

  Future<DiscordShareResult> share({
    required DiscordShareSession session,
    required SanitizedShareImage image,
    required Set<String> targetIds,
    required String prompt,
    required String caption,
    required int? width,
    required int? height,
    required bool longPromptAsFile,
  }) {
    if (_shareInFlight != null) {
      return Future<DiscordShareResult>.error(
        const DiscordShareException(
          code: 'share_in_progress',
          message: 'A Discord share is already in progress.',
        ),
      );
    }

    late final Future<DiscordShareResult> operation;
    operation =
        _performShare(
          session: session,
          image: image,
          targetIds: targetIds,
          prompt: prompt,
          caption: caption,
          width: width,
          height: height,
          longPromptAsFile: longPromptAsFile,
        ).whenComplete(() {
          if (identical(_shareInFlight, operation)) {
            _shareInFlight = null;
          }
        });
    _shareInFlight = operation;
    return operation;
  }

  Future<DiscordShareResult> _performShare({
    required DiscordShareSession session,
    required SanitizedShareImage image,
    required Set<String> targetIds,
    required String prompt,
    required String caption,
    required int? width,
    required int? height,
    required bool longPromptAsFile,
  }) async {
    final formData = FormData();
    formData.files.add(
      MapEntry(
        'image',
        MultipartFile.fromBytes(
          image.bytes,
          filename: image.fileName,
          contentType: DioMediaType.parse(image.mimeType),
        ),
      ),
    );
    formData.fields
      ..add(MapEntry('filename', image.fileName))
      ..add(MapEntry('prompt', prompt.trim()))
      ..add(MapEntry('caption', caption.trim()))
      ..add(MapEntry('width', width?.toString() ?? ''))
      ..add(MapEntry('height', height?.toString() ?? ''))
      ..add(MapEntry('long_prompt_as_file', '$longPromptAsFile'))
      ..addAll(targetIds.map((id) => MapEntry('target', id)));

    final payload = await _request(
      () => _dio.post<Object?>(
        '/v1/share',
        data: formData,
        options: Options(
          headers: {'Authorization': 'Bearer ${session.token}'},
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 500,
        ),
      ),
      clearSessionOnAuthFailure: true,
      acceptedStatuses: const {200, 207},
    );
    final delivered = (payload['delivered_targets'] as List? ?? const [])
        .whereType<Map>()
        .map((entry) => '${entry['label'] ?? entry['id'] ?? ''}')
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
    final failed = (payload['failed_targets'] as List? ?? const [])
        .whereType<Map>()
        .map((entry) => '${entry['label'] ?? entry['id'] ?? ''}')
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
    return DiscordShareResult(
      deliveredTargets: delivered,
      failedTargets: failed,
      failedTargetIds: (payload['failed_targets'] as List? ?? const [])
          .whereType<Map>()
          .map((entry) => '${entry['id'] ?? ''}')
          .where((id) => id.isNotEmpty && targetIds.contains(id))
          .toList(growable: false),
    );
  }

  Future<void> _saveSession(DiscordShareSession session) {
    return _secureStorage.write(
      StorageKeys.discordShareSession,
      jsonEncode(session.toJson()),
    );
  }

  Map<String, String> _authorizationHeaders(String token) => {
    'Accept': 'application/json',
    'Authorization': 'Bearer $token',
  };

  Future<Map<String, dynamic>> _request(
    Future<Response<Object?>> Function() request, {
    bool clearSessionOnAuthFailure = false,
    Set<int> acceptedStatuses = const {200},
  }) async {
    try {
      final response = await request();
      final status = response.statusCode ?? 0;
      if (!acceptedStatuses.contains(status)) {
        final payload = _responsePayload(response.data) ?? {};
        if (clearSessionOnAuthFailure && (status == 401 || status == 403)) {
          await clearSession();
        }
        throw _exceptionFromPayload(
          payload,
          status,
          retryAfterHeader: response.headers.value('retry-after'),
        );
      }
      final payload = _responsePayload(response.data);
      if (payload == null) throw _exceptionFromPayload({}, status);
      return payload;
    } on DiscordShareException {
      rethrow;
    } on DioException catch (error) {
      final response = error.response;
      final payload = _responsePayload(response?.data) ?? {};
      final status = response?.statusCode;
      if (clearSessionOnAuthFailure && (status == 401 || status == 403)) {
        await clearSession();
      }
      throw _exceptionFromPayload(
        payload,
        status,
        fallback: error.message ?? 'Discord sharing failed.',
        transportType: error.type,
        retryAfterHeader: response?.headers.value('retry-after'),
      );
    }
  }

  // Read the HTTP status before interpreting the body. Proxies may send HTML
  // or malformed JSON for a 429 even when the content type claims JSON.
  Map<String, dynamic>? _responsePayload(Object? data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is! String) return null;
    try {
      final decoded = jsonDecode(data);
      return decoded is Map ? Map<String, dynamic>.from(decoded) : null;
    } on FormatException {
      return null;
    }
  }

  DiscordShareException _exceptionFromPayload(
    Map<String, dynamic> payload,
    int? status, {
    String fallback = 'Discord sharing failed.',
    String? retryAfterHeader,
    DioExceptionType? transportType,
  }) {
    final businessCode = payload['code']?.toString();
    final code = switch (status) {
      429 => 'rate_limited',
      401 || 403 => businessCode ?? 'unauthorized',
      _ when businessCode != null => businessCode,
      _ when status != null => 'request_failed',
      _
          when transportType == DioExceptionType.connectionError ||
              transportType == DioExceptionType.connectionTimeout ||
              transportType == DioExceptionType.sendTimeout ||
              transportType == DioExceptionType.receiveTimeout =>
        'network_error',
      _ => 'request_failed',
    };
    return DiscordShareException(
      code: code,
      businessCode: businessCode,
      message: '${payload['message'] ?? fallback}',
      status: status,
      communityUrl:
          payload['community_url']?.toString() ??
          (payload['code'] == 'not_member' ? discordCommunityUrl : null),
      retryAfter:
          _retryAfterHeader(retryAfterHeader) ??
          _retryAfter(payload['retry_after_seconds']) ??
          _retryAfter(payload['retry_after']),
    );
  }

  Duration? _retryAfterHeader(String? value) {
    if (value == null) return null;
    final seconds = _retryAfter(value);
    if (seconds != null) return seconds;
    try {
      final delay = HttpDate.parse(value).difference(DateTime.now().toUtc());
      return delay > Duration.zero ? delay : null;
    } on HttpException {
      return null;
    }
  }

  Duration? _retryAfter(Object? raw) {
    final seconds = raw is num ? raw.toDouble() : double.tryParse('$raw');
    if (seconds == null || !seconds.isFinite || seconds <= 0) return null;
    return Duration(milliseconds: (seconds * 1000).ceil());
  }

  String _randomBase64Url(int byteCount) {
    final random = Random.secure();
    final bytes = Uint8List.fromList(
      List<int>.generate(byteCount, (_) => random.nextInt(256)),
    );
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}

final discordShareServiceProvider = Provider<DiscordShareService>((ref) {
  return DiscordShareService(
    secureStorage: ref.watch(secureStorageServiceProvider),
    localStorage: ref.watch(localStorageServiceProvider),
  );
});
