import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_logger.dart';
import '../../providers/cloud_sync/cloud_sync_ui_provider.dart';

/// Owned above the form so restores and layout switches keep unsaved input.
final cloudSyncSetupDraftProvider =
    ChangeNotifierProvider.autoDispose<CloudSyncSetupDraft>((ref) {
      final draft = CloudSyncSetupDraft(ref.read(cloudSyncUiPortProvider));
      ref.listen<bool>(
        cloudSyncUiStateProvider.select((state) => state.isConnected),
        (wasConnected, connected) {
          if (connected && wasConnected != true) draft.reset();
        },
      );
      return draft;
    });

class CloudSyncSetupDraft extends ChangeNotifier {
  CloudSyncSetupDraft(this._port) {
    for (final controller in _controllers) {
      controller.addListener(_notify);
    }
  }

  static const _defaultBranch = 'main';
  static const _defaultPath = 'aaalice-sync';

  final CloudSyncUiPort _port;
  final url = TextEditingController();
  final username = TextEditingController();
  final secret = TextEditingController();
  final owner = TextEditingController();
  final repository = TextEditingController();
  final branch = TextEditingController(text: _defaultBranch);
  final path = TextEditingController(text: _defaultPath);
  var _backend = CloudSyncBackendKind.webDav;
  var _allowInsecureHttp = false;
  var _authorizingOAuth = false;
  var _oauthGeneration = 0;
  CloudSyncConnectionDraft? _oauthDraft;
  var _disposed = false;

  Iterable<TextEditingController> get _controllers => [
    url,
    username,
    secret,
    owner,
    repository,
    branch,
    path,
  ];

  CloudSyncBackendKind get backend => _backend;
  bool get allowInsecureHttp => _allowInsecureHttp;
  bool get authorizingOAuth => _authorizingOAuth;
  String? get oauthAccountLabel => _oauthDraft?.accountLabel;

  CloudSyncConnectionDraft get connection {
    final oauth = _oauthDraft;
    final remotePath = _trimmedOr(path, _defaultPath);
    if (_backend.usesOAuth && oauth != null) {
      return CloudSyncConnectionDraft(
        backend: _backend,
        path: remotePath,
        accountId: oauth.accountId,
        accountLabel: oauth.accountLabel,
      );
    }
    return CloudSyncConnectionDraft(
      backend: _backend,
      serverUrl: url.text.trim(),
      username: username.text.trim(),
      secret: secret.text,
      owner: owner.text.trim(),
      repository: repository.text.trim(),
      branch: _trimmedOr(branch, _defaultBranch),
      path: remotePath,
      allowInsecureHttp: _allowInsecureHttp,
    );
  }

  bool get canConnect => switch (_backend) {
    CloudSyncBackendKind.webDav =>
      url.text.trim().isNotEmpty &&
          username.text.trim().isNotEmpty &&
          secret.text.isNotEmpty,
    CloudSyncBackendKind.github =>
      owner.text.trim().isNotEmpty &&
          repository.text.trim().isNotEmpty &&
          secret.text.isNotEmpty,
    CloudSyncBackendKind.googleDrive || CloudSyncBackendKind.oneDrive =>
      _oauthDraft?.backend == _backend &&
          (_oauthDraft?.accountId.isNotEmpty ?? false),
  };

  void changeBackend(CloudSyncBackendKind value) {
    if (value == _backend) return;
    _abandonOAuth('discard OAuth draft after backend change');
    _backend = value;
    _notify();
  }

  void setAllowInsecureHttp(bool value) {
    if (value == _allowInsecureHttp) return;
    _allowInsecureHttp = value;
    _notify();
  }

  Future<void> authorizeOAuth() async {
    final backend = _backend;
    final generation = _oauthGeneration;
    final stopwatch = Stopwatch()..start();
    _authorizingOAuth = true;
    _notify();
    AppLogger.i(
      'OAuth authorization UI started: backend=${backend.name}',
      'CloudSync',
    );
    try {
      final previous = _oauthDraft;
      final connected = await _port.authorizeCloudDrive(backend);
      if (_disposed || generation != _oauthGeneration) {
        await _port.discardCloudDriveAuthorization(connected);
        return;
      }
      _oauthDraft = connected;
      _notify();
      if (previous != null && previous.accountId != connected.accountId) {
        try {
          await _port.discardCloudDriveAuthorization(previous);
        } catch (error, stackTrace) {
          AppLogger.e(
            'Failed to discard replaced OAuth draft: '
                'backend=${backend.name}',
            error,
            stackTrace,
            'CloudSync',
          );
        }
      }
    } finally {
      if (!_disposed && generation == _oauthGeneration) {
        _authorizingOAuth = false;
        _notify();
      }
      AppLogger.i(
        'OAuth authorization UI finished: backend=${backend.name}, '
            'elapsedMs=${stopwatch.elapsedMilliseconds}',
        'CloudSync',
      );
    }
  }

  Future<void> cancelOAuth() => _port.cancelCloudDriveAuthorization(_backend);

  /// Saving owns this session until it fails, so teardown must not revoke it.
  CloudSyncConnectionDraft? handOffOAuthDraft() {
    final draft = _backend.usesOAuth ? _oauthDraft : null;
    if (draft == null) return null;
    _oauthDraft = null;
    _notify();
    return draft;
  }

  Future<void> reclaimOAuthDraft(CloudSyncConnectionDraft draft) async {
    if (_disposed) {
      await _port.discardCloudDriveAuthorization(draft);
      return;
    }
    _oauthDraft = draft;
    _notify();
  }

  void reset() {
    _abandonOAuth('discard OAuth draft after connecting');
    _backend = CloudSyncBackendKind.webDav;
    _allowInsecureHttp = false;
    for (final controller in [url, username, secret, owner, repository]) {
      controller.clear();
    }
    branch.text = _defaultBranch;
    path.text = _defaultPath;
    _notify();
  }

  void _abandonOAuth(String action) {
    _oauthGeneration++;
    if (_authorizingOAuth) {
      _authorizingOAuth = false;
      _runBackgroundCleanup(
        _port.cancelCloudDriveAuthorization(_backend),
        'cancel active OAuth authorization',
      );
    }
    final pending = _oauthDraft;
    _oauthDraft = null;
    if (pending != null) {
      _runBackgroundCleanup(
        _port.discardCloudDriveAuthorization(pending),
        action,
      );
    }
  }

  void _runBackgroundCleanup(Future<void> cleanup, String action) {
    unawaited(
      cleanup.onError((error, stackTrace) {
        AppLogger.e(
          'Cloud sync cleanup failed: action=$action',
          error,
          stackTrace,
          'CloudSync',
        );
      }),
    );
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  static String _trimmedOr(TextEditingController controller, String fallback) {
    final value = controller.text.trim();
    return value.isEmpty ? fallback : value;
  }

  @override
  void dispose() {
    _abandonOAuth('discard OAuth draft');
    _disposed = true;
    for (final controller in _controllers) {
      controller.removeListener(_notify);
      controller.dispose();
    }
    super.dispose();
  }
}
