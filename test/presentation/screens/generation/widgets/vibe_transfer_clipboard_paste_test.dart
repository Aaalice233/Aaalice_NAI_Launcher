import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/platform/platform_capabilities.dart';
import 'package:nai_launcher/core/storage/local_storage_service.dart';
import 'package:nai_launcher/data/models/vibe/vibe_library_entry.dart';
import 'package:nai_launcher/data/services/vibe_library_storage_service.dart';
import 'package:nai_launcher/l10n/app_localizations.dart';
import 'package:nai_launcher/presentation/screens/generation/widgets/vibe_transfer_content.dart';

/// 没有 OS 级文件拖入的平台要在「添加风格参考」旁边补一个剪贴板入口；
/// 桌面端沿用上游（只有添加按钮 + DropRegion）。
void main() {
  tearDown(() {
    PlatformCapabilities.debugOverride = null;
  });

  testWidgets('触屏平台的空状态补出剪贴板入口', (tester) async {
    await _pumpVibeTransferContent(tester, TargetPlatform.iOS);

    expect(
      find.byKey(const Key('vibe-transfer-empty-paste-from-clipboard')),
      findsOneWidget,
    );
  });

  testWidgets('桌面端不出现剪贴板入口', (tester) async {
    await _pumpVibeTransferContent(tester, TargetPlatform.windows);

    expect(
      find.byKey(const Key('vibe-transfer-empty-paste-from-clipboard')),
      findsNothing,
    );
  });
}

Future<void> _pumpVibeTransferContent(
  WidgetTester tester,
  TargetPlatform platform,
) async {
  PlatformCapabilities.debugOverride = PlatformCapabilities.forPlatform(
    platform,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWith(
          (ref) => _TestLocalStorageService(),
        ),
        vibeLibraryStorageServiceProvider.overrideWithValue(
          _TestVibeLibraryStorageService(),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: 720,
              child: VibeTransferContent(
                vibes: const [],
                normalizeVibeStrength: true,
                showBackground: false,
                onAddVibe: () {},
                onAddLibraryVibe: (_) {},
                onRemoveVibe: (_) {},
                onUpdateStrength: (_, _) {},
                onUpdateInfoExtracted: (_, _) {},
                onUpdateEnabled: (_, _) {},
                onClearAll: () {},
                onImportDroppedResources: (_) async => 0,
                recentEntries: const [],
                isRecentCollapsed: false,
                onToggleRecentCollapsed: () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _TestLocalStorageService extends LocalStorageService {
  final Map<String, Object?> _settings = {};

  @override
  T? getSetting<T>(String key, {T? defaultValue}) {
    final value = _settings[key];
    return value is T ? value : defaultValue;
  }

  @override
  Future<void> setSetting<T>(String key, T value) async {
    _settings[key] = value;
  }

  @override
  String getLastPrompt() => '';

  @override
  String getLastNegativePrompt() => '';

  @override
  String getDefaultModel() => 'nai-diffusion-4-5-full';

  @override
  String getDefaultSampler() => 'k_euler_ancestral';

  @override
  int getDefaultSteps() => 28;

  @override
  double getDefaultScale() => 5.0;

  @override
  int getDefaultWidth() => 832;

  @override
  int getDefaultHeight() => 1216;

  @override
  bool getLastSmea() => false;

  @override
  bool getLastSmeaDyn() => false;

  @override
  double getLastCfgRescale() => 0.0;

  @override
  String getLastNoiseSchedule() => 'native';

  @override
  bool getLastVarietyPlus() => false;

  @override
  bool getSeedLocked() => false;

  @override
  int? getLockedSeedValue() => null;
}

class _TestVibeLibraryStorageService extends VibeLibraryStorageService {
  @override
  Future<List<VibeLibraryEntry>> getRecentDisplayEntries({
    int limit = 20,
  }) async {
    return const [];
  }

  @override
  Future<void> saveGenerationStateJson(String stateJson) async {}
}
