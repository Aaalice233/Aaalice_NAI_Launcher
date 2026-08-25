import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/anlas_calculator.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_enhancement_api_service.dart';
import 'package:nai_launcher/data/models/director/director_tool_type.dart';
import 'package:nai_launcher/data/models/user/user_subscription.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/director_tools_notifier.dart';
import 'package:nai_launcher/presentation/providers/subscription_provider.dart';

void main() {
  test('Director Tools 成本估算统一复用 AnlasCalculator', () {
    const width = 1280;
    const height = 960;

    for (final tool in DirectorToolType.values) {
      final state = DirectorToolsState(
        selectedTool: tool,
        imageWidth: width,
        imageHeight: height,
      );
      if (tool.runsLocally) {
        expect(state.estimatedAnlasCost(), 0, reason: tool.name);
        expect(
          state.estimatedAnlasCost(isOpus: true),
          0,
          reason: '${tool.name} Opus',
        );
        continue;
      }
      final isBackgroundRemoval = tool == DirectorToolType.removeBackground;

      expect(
        state.estimatedAnlasCost(),
        AnlasCalculator.calculateAugmentCost(
          width: width,
          height: height,
          isBgRemoval: isBackgroundRemoval,
        ),
        reason: tool.name,
      );
      expect(
        state.estimatedAnlasCost(isOpus: true),
        AnlasCalculator.calculateAugmentCost(
          width: width,
          height: height,
          isBgRemoval: isBackgroundRemoval,
          isOpus: true,
        ),
        reason: '${tool.name} Opus',
      );
    }
  });

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

  test('本地工具未登录也直接放行，不弹登录提示', () async {
    final apiService = _RecordingEnhancementApiService();
    final container = _createContainer(apiService, AuthStatus.unauthenticated);
    addTearDown(container.dispose);
    final notifier = container.read(directorToolsNotifierProvider.notifier);
    await notifier.init(Uint8List.fromList([1, 2, 3]));
    notifier.selectTool(DirectorToolType.pixelSnap);

    await notifier.runTool();

    final after = container.read(directorToolsNotifierProvider);
    expect(apiService.uploadCalls, 0);
    expect(container.read(authPromptRequestProvider), isNull);
    // 源图是三个字节的垃圾，本机引擎解码失败收尾；有 error 就说明门禁没拦住它。
    expect(after.error, isNotNull);
    expect(after.isRunning, isFalse);
  });

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
