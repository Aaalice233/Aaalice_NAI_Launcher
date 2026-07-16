import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/krita/krita_bridge_server.dart';
import '../../../core/utils/app_logger.dart';
import '../../../data/datasources/remote/nai_image_generation_api_service.dart';
import '../fixed_tags_provider.dart';
import '../generation/image_workflow_controller.dart';
import '../image_generation_provider.dart';
import '../image_save_settings_provider.dart';
import 'krita_bridge_service.dart';

typedef KritaBridgeServerFactory = KritaBridgeServer Function();
typedef KritaBridgeEnabledPersister = FutureOr<void> Function(bool enabled);
typedef KritaBridgeServiceFactory =
    KritaBridgeMessageService Function(KritaBridgeServer server);

enum KritaBridgeStatus { disabled, starting, listening, connected, error }

class KritaBridgeState {
  const KritaBridgeState({
    this.enabled = false,
    this.status = KritaBridgeStatus.disabled,
    this.port,
    this.secret,
    this.discoveryFilePath,
    this.connectedClientLabel,
    this.activeRequestId,
    this.errorMessage,
  });

  final bool enabled;
  final KritaBridgeStatus status;
  final int? port;
  final String? secret;
  final String? discoveryFilePath;
  final String? connectedClientLabel;
  final String? activeRequestId;
  final String? errorMessage;

  bool get isActive =>
      status == KritaBridgeStatus.listening ||
      status == KritaBridgeStatus.connected;

  bool get isBridgeGenerating => activeRequestId != null;

  KritaBridgeState copyWith({
    bool? enabled,
    KritaBridgeStatus? status,
    int? port,
    String? secret,
    String? discoveryFilePath,
    String? connectedClientLabel,
    String? activeRequestId,
    String? errorMessage,
    bool clearSession = false,
    bool clearConnectedClientLabel = false,
    bool clearActiveRequest = false,
    bool clearError = false,
  }) {
    return KritaBridgeState(
      enabled: enabled ?? this.enabled,
      status: status ?? this.status,
      port: clearSession ? null : (port ?? this.port),
      secret: clearSession ? null : (secret ?? this.secret),
      discoveryFilePath: clearSession
          ? null
          : (discoveryFilePath ?? this.discoveryFilePath),
      connectedClientLabel: clearSession || clearConnectedClientLabel
          ? null
          : (connectedClientLabel ?? this.connectedClientLabel),
      activeRequestId: clearSession || clearActiveRequest
          ? null
          : (activeRequestId ?? this.activeRequestId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class KritaBridgeNotifier extends StateNotifier<KritaBridgeState> {
  KritaBridgeNotifier({
    KritaBridgeServerFactory? serverFactory,
    KritaBridgeEnabledPersister? persistEnabled,
    KritaBridgeServiceFactory? serviceFactory,
  }) : _serverFactory = serverFactory ?? (() => KritaBridgeServer()),
       _persistEnabled = persistEnabled,
       _serviceFactory = serviceFactory,
       super(const KritaBridgeState());

  final KritaBridgeServerFactory _serverFactory;
  final KritaBridgeEnabledPersister? _persistEnabled;
  final KritaBridgeServiceFactory? _serviceFactory;
  KritaBridgeServer? _server;
  KritaBridgeMessageService? _service;
  StreamSubscription? _messagesSubscription;
  StreamSubscription<bool>? _connectionSubscription;
  static const String _logTag = 'KritaBridge';

  KritaBridgeServer? get server => _server;

  Future<void> setEnabled(bool enabled) async {
    if (enabled) {
      await enable();
    } else {
      await disable();
    }
  }

  Future<void> enable({bool persist = true}) async {
    if (state.isActive || state.status == KritaBridgeStatus.starting) {
      return;
    }

    state = state.copyWith(
      enabled: true,
      status: KritaBridgeStatus.starting,
      clearSession: true,
      clearError: true,
    );

    final server = _serverFactory();
    try {
      AppLogger.i('Enabling Krita bridge', _logTag);
      await server.start(preferredPort: 0);
      _server = server;
      _service = _serviceFactory?.call(server);
      _service?.setActiveRequestReporter(_setActiveRequest);
      _messagesSubscription = server.messages.listen((message) {
        final service = _service;
        if (service == null) {
          return;
        }
        unawaited(service.handle(message));
      });
      _connectionSubscription = server.authenticationChanges.listen((
        connected,
      ) {
        if (!mounted || !state.enabled) {
          return;
        }
        if (!connected) {
          _service?.handleClientDisconnected();
        }
        AppLogger.i(
          connected ? 'Krita client connected' : 'Krita client disconnected',
          _logTag,
        );
        state = state.copyWith(
          status: connected
              ? KritaBridgeStatus.connected
              : KritaBridgeStatus.listening,
          connectedClientLabel: connected ? server.connectedClientLabel : null,
          clearConnectedClientLabel: !connected,
        );
      });
      if (!mounted) {
        await server.stop();
        return;
      }
      state = KritaBridgeState(
        enabled: true,
        status: KritaBridgeStatus.listening,
        port: server.port,
        secret: server.secret,
        discoveryFilePath: server.discoveryFile.path,
      );
      if (persist) {
        await _persistEnabled?.call(true);
      }
      if (!mounted) {
        await server.stop();
        return;
      }
      AppLogger.i('Krita bridge enabled on port ${server.port}', _logTag);
    } catch (error) {
      await server.stop();
      AppLogger.e('Failed to enable Krita bridge', error, null, _logTag);
      if (!mounted) {
        return;
      }
      state = KritaBridgeState(
        enabled: false,
        status: KritaBridgeStatus.error,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> disable({bool persist = true}) async {
    if (state.isBridgeGenerating) {
      _service?.handleClientDisconnected();
    }

    await _messagesSubscription?.cancel();
    await _connectionSubscription?.cancel();
    _messagesSubscription = null;
    _connectionSubscription = null;
    _service = null;

    final server = _server;
    _server = null;
    if (server != null) {
      AppLogger.i('Disabling Krita bridge', _logTag);
      await server.stop();
    }

    if (!mounted) {
      return;
    }
    state = const KritaBridgeState();
    if (persist) {
      await _persistEnabled?.call(false);
    }
    AppLogger.i('Krita bridge disabled', _logTag);
  }

  void _setActiveRequest(String? requestId) {
    if (!mounted || !state.enabled) {
      return;
    }
    state = state.copyWith(
      activeRequestId: requestId,
      clearActiveRequest: requestId == null,
    );
  }

  bool sendImageToKrita(Uint8List image, {required String name}) {
    final server = _server;
    if (server == null || !server.isClientAuthenticated) {
      AppLogger.w(
        'Cannot send image to Krita: no authenticated client',
        _logTag,
      );
      return false;
    }

    server.send({
      'type': 'push_image',
      'image': base64Encode(image),
      'name': name,
    });
    AppLogger.i('Sent image to Krita: $name (${image.length} bytes)', _logTag);
    return true;
  }

  Future<void> regenerateSession() async {
    if (!state.enabled) {
      return;
    }

    await disable(persist: false);
    await enable(persist: false);
    AppLogger.i('Krita bridge session regenerated', _logTag);
  }

  Future<void> close() async {
    await disable(persist: false);
  }

  @override
  void dispose() {
    unawaited(close());
    super.dispose();
  }
}

final kritaBridgeNotifierProvider =
    StateNotifierProvider<KritaBridgeNotifier, KritaBridgeState>((ref) {
      final box = Hive.box(StorageKeys.settingsBox);
      final notifier = KritaBridgeNotifier(
        persistEnabled: (enabled) =>
            box.put(StorageKeys.kritaBridgeEnabled, enabled),
        serviceFactory: (server) => KritaBridgeService(
          readBaseParams: () => ref.read(generationParamsNotifierProvider),
          readPromptSnapshot: (params) {
            final fixedTags = ref.read(fixedTagsNotifierProvider);
            return (
              prompt: fixedTags.applyToPrompt(params.prompt),
              negativePrompt: fixedTags.applyToNegativePrompt(
                params.negativePrompt,
              ),
            );
          },
          readMinimumContextPixels: () => ref
              .read(imageWorkflowControllerProvider)
              .minimumContextMegaPixels
              .round()
              .clamp(16, 192)
              .toInt(),
          send: server.send,
          isUiGenerating: () =>
              ref.read(imageGenerationNotifierProvider).isGenerating,
          generateStream: (request) {
            final apiService = ref.read(naiImageGenerationApiServiceProvider);
            return apiService.generateImageStream(
              request.params,
              focusedInpaintEnabled: request.focusedInpaintEnabled,
              minimumContextMegaPixels: request.minimumContextPixels,
              focusedSelectionRect: request.focusedSelectionRect,
            );
          },
          generateFallback: (request) async {
            final apiService = ref.read(naiImageGenerationApiServiceProvider);
            return apiService.generateImageArtifactsCancellable(
              request.params,
              onProgress: (_, __) {},
              focusedInpaintEnabled: request.focusedInpaintEnabled,
              minimumContextMegaPixels: request.minimumContextPixels,
              focusedSelectionRect: request.focusedSelectionRect,
            );
          },
          registerExternalImage: (image, {required params, addToDisplay}) => ref
              .read(imageGenerationNotifierProvider.notifier)
              .registerExternalImage(
                image,
                params: params,
                saveToLocal: ref
                    .read(imageSaveSettingsNotifierProvider)
                    .autoSave,
                addToDisplay: addToDisplay ?? false,
              ),
          cancelGeneration: () =>
              ref.read(naiImageGenerationApiServiceProvider).cancelGeneration(),
        ),
      );
      final enabled =
          box.get(StorageKeys.kritaBridgeEnabled, defaultValue: false) as bool;
      if (enabled) {
        unawaited(notifier.enable(persist: false));
      }
      ref.onDispose(() {
        unawaited(notifier.close());
      });
      return notifier;
    });
