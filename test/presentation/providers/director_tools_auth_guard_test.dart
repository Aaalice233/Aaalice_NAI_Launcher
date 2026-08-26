import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_enhancement_api_service.dart';
import 'package:nai_launcher/data/models/user/user_subscription.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/director_tools_notifier.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';

void main() {
  for (final status in [AuthStatus.unauthenticated, AuthStatus.loading]) {
    test('Director Tools 在 $status 时不上传且保持业务状态', () async {
      final apiService = _RecordingEnhancementApiService();
      final container = _createContainer(apiService, status);
      addTearDown(container.dispose);
      final notifier = container.read(directorToolsNotifierProvider.notifier);
      final source = Uint8List.fromList([1, 2, 3]);
      await notifier.init(source, initialPrompt: 'keep prompt');
      final before = container.read(directorToolsNotifierProvider);

      await notifier.runTool();

      final after = container.read(directorToolsNotifierProvider);
      expect(apiService.uploadCalls, 0);
      expect(after.isRunning, isFalse);
      expect(after.sourceImage, same(before.sourceImage));
      expect(after.prompt, before.prompt);
      expect(after.selectedTool, before.selectedTool);
      expect(after.result, before.result);
      expect(after.error, before.error);
      expect(
        container.read(authPromptRequestProvider)?.reason,
        AuthPromptReason.directorTools,
      );
    });
  }

  test('Director Tools 登录后保留成功调用路径', () async {
    final apiService = _RecordingEnhancementApiService();
    final container = _createContainer(apiService, AuthStatus.authenticated);
    addTearDown(container.dispose);
    final notifier = container.read(directorToolsNotifierProvider.notifier);
    await notifier.init(Uint8List.fromList([1, 2, 3]));

    await notifier.runTool();

    final state = container.read(directorToolsNotifierProvider);
    expect(apiService.uploadCalls, 1);
    expect(state.isRunning, isFalse);
    expect(state.result, Uint8List.fromList([9, 8, 7]));
    expect(state.error, isNull);
    expect(container.read(authPromptRequestProvider), isNull);
  });
}

ProviderContainer _createContainer(
  _RecordingEnhancementApiService apiService,
  AuthStatus status,
) {
  return ProviderContainer(
    overrides: [
      authNotifierProvider.overrideWith(() => _TestAuthNotifier(status)),
      naiImageEnhancementApiServiceProvider.overrideWithValue(apiService),
      subscriptionNotifierProvider.overrideWith(_TestSubscriptionNotifier.new),
    ],
  );
}

class _TestAuthNotifier extends AuthNotifier {
  _TestAuthNotifier(this.authStatus);

  final AuthStatus authStatus;

  @override
  AuthState build() => AuthState(status: authStatus);
}

class _RecordingEnhancementApiService extends NAIImageEnhancementApiService {
  _RecordingEnhancementApiService() : super(Dio());

  int uploadCalls = 0;

  @override
  Future<Uint8List> removeBackground(Uint8List image) async {
    uploadCalls++;
    return Uint8List.fromList([9, 8, 7]);
  }
}

class _TestSubscriptionNotifier extends SubscriptionNotifier {
  @override
  SubscriptionState build() => const SubscriptionState.initial();

  @override
  void schedulePostBillingRefresh({
    Duration delay = SubscriptionNotifier.postBillingRefreshDelay,
  }) {}
}
