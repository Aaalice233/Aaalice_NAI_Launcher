import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('交互数据在 Splash 准备，维护与大型通用缓存保持延迟', () {
    final startupSource = [
      File(
        'lib/presentation/providers/startup_initialization_provider.dart',
      ).readAsStringSync(),
      File(
        'lib/presentation/providers/warmup_provider.dart',
      ).readAsStringSync(),
    ].join('\n');

    for (final forbidden in <String>[
      'IsolateMetadataService.instance.initialize',
      'getTotalImageCount()',
      'ProxyService.testNovelAIConnection',
      'GoogleFonts.pendingFonts',
      'startPostWarmupTasks',
      'initializeInteractiveReadiness',
    ]) {
      expect(startupSource, isNot(contains(forbidden)), reason: forbidden);
    }

    final initializationSource = File(
      'lib/presentation/providers/startup_initialization_provider.dart',
    ).readAsStringSync();
    final criticalStart = initializationSource.indexOf(
      'initializeCriticalServices: () async',
    );
    final mainShellStart = initializationSource.indexOf(
      'initializeMainShellData: () async',
      criticalStart,
    );
    final deferredStart = initializationSource.indexOf(
      'runDeferredDataMaintenance: () async',
      mainShellStart,
    );
    expect(criticalStart, greaterThanOrEqualTo(0));
    expect(mainShellStart, greaterThan(criticalStart));
    expect(deferredStart, greaterThan(mainShellStart));
    final mainShellSource = initializationSource.substring(
      mainShellStart,
      deferredStart,
    );
    expect(mainShellSource, contains('randomTagLibraryDataProvider.future'));
    expect(mainShellSource, contains('randomPresetNotifierProvider.notifier'));
    expect(mainShellSource, contains('tagLibraryNotifierProvider.notifier'));
    expect(mainShellSource, contains('officialWordlistDataProvider.future'));
    expect(mainShellSource, contains('layoutState.rightPanelExpanded'));
    expect(mainShellSource, contains('rightPanelTab == 0'));
    expect(mainShellSource, contains('agentChatNotifierProvider.notifier'));
    expect(mainShellSource, contains('tagGroupCacheServiceProvider'));
    expect(mainShellSource, contains('onlineGalleryNotifierProvider'));
    expect(
      initializationSource.substring(criticalStart, deferredStart),
      isNot(contains('GalleryAlbumImportCoordinator')),
    );
    expect(
      initializationSource.substring(deferredStart),
      contains('GalleryAlbumImportCoordinator'),
    );

    final imageGenerationSource = File(
      'lib/presentation/providers/image_generation_provider.dart',
    ).readAsStringSync();
    expect(mainShellSource, contains('ensureGenerationHistoryRestored()'));
    expect(
      imageGenerationSource,
      isNot(contains('Future.microtask(ensureGenerationHistoryRestored)')),
    );

    final agentNotifierSource = File(
      'lib/presentation/agent_chat/providers/agent_chat_notifier.dart',
    ).readAsStringSync();
    expect(
      agentNotifierSource,
      contains('AgentChatNotifier(ref, initializeImmediately: false)'),
    );
    final agentPanelSource = File(
      'lib/presentation/agent_chat/widgets/agent_chat_panel.dart',
    ).readAsStringSync();
    expect(
      agentPanelSource,
      contains('WidgetsBinding.instance.addPostFrameCallback'),
    );
    expect(agentPanelSource, contains('.ensureInitialized'));

    final mainSource = File('lib/main.dart').readAsStringSync();
    expect(mainSource, contains('runDeferredDataMaintenance'));
    expect(mainSource, contains('InteractiveWorkGate.instance.runWhenIdle'));
    expect(mainSource, isNot(contains('Timer(const Duration(seconds: 5)')));
    expect(mainSource, contains('L2CacheCleaner().checkAndClean'));
    expect(mainSource, contains('TempImageService().cleanupOldTempFiles'));

    final cooccurrenceStartupSource = File(
      'lib/core/autocomplete/cooccurrence_data_pack_provider.dart',
    ).readAsStringSync();
    expect(cooccurrenceStartupSource, contains('FutureProvider<void>'));
    expect(cooccurrenceStartupSource, isNot(contains('scheduleTask<void>')));

    final bootstrapSource = File(
      'lib/presentation/screens/splash/app_bootstrap.dart',
    ).readAsStringSync();
    expect(bootstrapSource, isNot(contains('Timer(Duration.zero')));
    expect(bootstrapSource, isNot(contains('isPrepared')));
    expect(
      bootstrapSource,
      isNot(contains('Positioned.fill(child: _buildSplash')),
    );
  });
}
