import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/constants/storage_keys.dart';
import 'package:nai_launcher/data/datasources/remote/nai_generation_transport.dart';
import 'package:nai_launcher/data/datasources/remote/nai_image_generation_api_service.dart';
import 'package:nai_launcher/data/models/image/image_params.dart';
import 'package:nai_launcher/data/services/auth_provider.dart';

class MockNAIImageGenerationApiService extends Mock
    implements NAIImageGenerationApiService {}

class AuthenticatedAuthNotifier extends AuthNotifier {
  @override
  AuthState build() => const AuthState(status: AuthStatus.authenticated);
}

/// 为生成 notifier 准备临时 Hive 盒子与 mocktail 回退值，每个用例前把每次请求张数复位为 1。
void setUpImageGenerationTestEnvironment() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory hiveDirectory;

  setUpAll(() async {
    registerFallbackValue(const ImageParams());
    registerFallbackValue(NaiGenerationCancellationLease());
    hiveDirectory = await Directory.systemTemp.createTemp('nai_launcher_hive_');
    Hive.init(hiveDirectory.path);
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
    if (await hiveDirectory.exists()) {
      await hiveDirectory.delete(recursive: true);
    }
  });
}

/// 在真实事件循环里轮询 [condition]，约 2 秒内不成立即失败。
Future<void> pollUntil(bool Function() condition, {String? reason}) async {
  for (var attempt = 0; attempt < 400; attempt++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail(reason ?? 'Condition not met within timeout');
}
