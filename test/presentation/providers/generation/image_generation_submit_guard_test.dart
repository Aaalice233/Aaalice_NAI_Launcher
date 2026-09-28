import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/data/datasources/remote/nai_generation_transport.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_generation_api_service.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/models/image/image_stream_chunk.dart';
import 'package:nai_launcher/presentation/providers/auth_provider.dart';
import 'package:nai_launcher/presentation/providers/image_generation_provider.dart';
import 'package:nai_launcher/presentation/providers/image_save_settings_provider.dart';
import 'package:nai_launcher/presentation/providers/notification_settings_provider.dart';

class _MockApiService extends Mock implements NAIImageGenerationApiService {}

class _AuthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.authenticated);
}

void main() {
  late Directory hiveTempDir;

  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    registerFallbackValue(const ImageParams());
    registerFallbackValue(NaiGenerationCancellationLease());
    hiveTempDir = await Directory.systemTemp.createTemp('nai_launcher_hive_');
    Hive.init(hiveTempDir.path);
    await Hive.openBox(StorageKeys.settingsBox);
    await Hive.openBox(StorageKeys.historyBox);
    await Hive.openBox(StorageKeys.statisticsCacheBox);
  });

  setUp(() async {
    await Hive.box(
      StorageKeys.settingsBox,
    ).put(StorageKeys.imagesPerRequest, 1);
  });

  tearDownAll(() async {
    await Hive.close();
    if (await hiveTempDir.exists()) {
      await hiveTempDir.delete(recursive: true);
    }
  });

  test('preparation is visible and a second tap cannot start a run', () async {
    // 用真实 controller：取消后要靠 close() 收掉订阅，否则 await 不回来。
    final stream = StreamController<ImageStreamChunk>();
    var streamCall = 0;
    final api = _stubApi(
      onStream: () {
        streamCall += 1;
        return stream.stream;
      },
    );
    final container = await _createContainer(api);

    final notifier = container.read(imageGenerationNotifierProvider.notifier);
    final params = container
        .read(generationParamsNotifierProvider)
        .copyWith(prompt: '1girl', width: 512, height: 768);

    final generation = notifier.generate(params);

    // 点击返回的同一时刻状态就必须对外可见，否则按钮会继续吞掉点击。
    final armed = container.read(imageGenerationNotifierProvider);
    expect(armed.isSubmitting, isTrue);
    expect(armed.isPreparing, isTrue);
    expect(armed.isGenerating, isFalse);
    expect(armed.isBusy, isTrue);

    await notifier.generate(params);
    await _pumpUntil(
      () => streamCall == 1,
      reason: 'the first submission never reached the API',
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(streamCall, 1);

    notifier.cancel();
    await stream.close();
    await generation;
    expect(
      container.read(imageGenerationNotifierProvider).isSubmitting,
      isFalse,
    );
  });

  test('cancel during preparation releases the guard synchronously', () async {
    final api = _stubApi(onStream: _neverEmits);
    final container = await _createContainer(api);

    final notifier = container.read(imageGenerationNotifierProvider.notifier);
    final params = container
        .read(generationParamsNotifierProvider)
        .copyWith(prompt: '1girl', width: 512, height: 768);

    final generation = notifier.generate(params);
    expect(container.read(imageGenerationNotifierProvider).isPreparing, isTrue);

    notifier.cancel();

    final released = container.read(imageGenerationNotifierProvider);
    expect(released.isSubmitting, isFalse);
    expect(released.isBusy, isFalse);

    await generation;
  });

  test('failed run releases the guard and keeps the error message', () async {
    final api = _stubApi(
      onStream: () =>
          Stream.value(ImageStreamChunk.error('API_ERROR_500|stream failed')),
    );
    final container = await _createContainer(api);

    final notifier = container.read(imageGenerationNotifierProvider.notifier);
    final params = container
        .read(generationParamsNotifierProvider)
        .copyWith(prompt: '1girl', width: 512, height: 768);

    await notifier.generate(params);

    final state = container.read(imageGenerationNotifierProvider);
    expect(state.isSubmitting, isFalse);
    expect(state.isBusy, isFalse);
    expect(state.status, GenerationStatus.error);
    // copyWith 省略 errorMessage 等于清空，释放守卫时不能顺手吞掉失败原因。
    expect(state.errorMessage, contains('stream failed'));
  });

  test('completed run releases the guard for the next submission', () async {
    final image = Uint8List.fromList(
      img.encodePng(img.Image(width: 512, height: 768)),
    );
    var streamCall = 0;
    final api = _stubApi(
      onStream: () {
        streamCall += 1;
        return Stream.value(ImageStreamChunk.complete(image));
      },
    );
    final container = await _createContainer(api);

    final notifier = container.read(imageGenerationNotifierProvider.notifier);
    final params = container
        .read(generationParamsNotifierProvider)
        .copyWith(prompt: '1girl', width: 512, height: 768);

    await notifier.generate(params);

    final completed = container.read(imageGenerationNotifierProvider);
    expect(completed.status, GenerationStatus.completed);
    expect(completed.isSubmitting, isFalse);
    expect(completed.isPreparing, isFalse);
    expect(completed.isBusy, isFalse);

    await notifier.generate(params);
    expect(streamCall, 2);
  });
}

/// 停在请求发出后永不返回，模拟服务端仍在跑的生成。
Stream<ImageStreamChunk> _neverEmits() =>
    Completer<ImageStreamChunk>().future.asStream();

Future<void> _pumpUntil(bool Function() condition, {String? reason}) async {
  for (var i = 0; i < 400; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail(reason ?? 'Condition not met within timeout');
}

_MockApiService _stubApi({
  required Stream<ImageStreamChunk> Function() onStream,
}) {
  final api = _MockApiService();
  when(
    () => api.generateImage(
      any(),
      onProgress: any(named: 'onProgress'),
      focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
      minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
      focusedSelectionRect: any(named: 'focusedSelectionRect'),
      cancellationLease: null,
    ),
  ).thenAnswer((_) async => (<Uint8List>[], <int, String>{}));
  when(
    () => api.generateImageStream(
      any(),
      focusedInpaintEnabled: any(named: 'focusedInpaintEnabled'),
      minimumContextMegaPixels: any(named: 'minimumContextMegaPixels'),
      focusedSelectionRect: any(named: 'focusedSelectionRect'),
      cancellationLease: null,
    ),
  ).thenAnswer((_) => onStream());
  when(() => api.cancelGeneration(any())).thenReturn(null);
  return api;
}

Future<ProviderContainer> _createContainer(_MockApiService api) async {
  final container = ProviderContainer(
    overrides: [
      authNotifierProvider.overrideWith(_AuthenticatedAuthNotifier.new),
      naiImageGenerationApiServiceProvider.overrideWithValue(api),
    ],
  );
  addTearDown(container.dispose);
  await container
      .read(notificationSettingsNotifierProvider.notifier)
      .setSoundEnabled(false);
  await container
      .read(imageSaveSettingsNotifierProvider.notifier)
      .setAutoSave(false);
  return container;
}
