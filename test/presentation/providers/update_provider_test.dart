import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/core/services/app_installation_service.dart';
import 'package:nai_launcher/core/services/update_check_service.dart';
import 'package:nai_launcher/core/services/update_installer_service.dart';
import 'package:nai_launcher/data/models/version/release_asset_info.dart';
import 'package:nai_launcher/data/models/version/version_info.dart';
import 'package:nai_launcher/presentation/providers/update_provider.dart';

void main() {
  test('automatic update provider performs the real startup check', () async {
    const versionInfo = VersionInfo(
      version: '2.0.0',
      currentVersion: '1.0.0',
      releaseNotes: 'test',
      isNewer: true,
    );
    final checkService = _MockUpdateCheckService();
    final installer = _MockUpdateInstallerService();
    when(installer.consumeExecutionResult).thenAnswer((_) async => null);
    when(installer.restorePendingUpdate).thenAnswer((_) async => null);
    when(checkService.shouldCheckOnStartup).thenAnswer((_) async => true);
    when(
      () => checkService.checkForUpdates(ignoreSkipped: false),
    ).thenAnswer((_) async => versionInfo);
    final container = ProviderContainer(
      overrides: [
        updateCheckServiceReadyProvider.overrideWith(
          (ref) async => checkService,
        ),
        updateCheckServiceProvider.overrideWithValue(checkService),
        updateInstallerServiceProvider.overrideWithValue(installer),
      ],
    );
    addTearDown(container.dispose);

    await container.read(automaticUpdateCheckProvider(onStartup: true).future);

    final state = container.read(updateStateProvider);
    expect(state.status, UpdateStatus.available);
    expect(state.versionInfo, versionInfo);
    expect(state.notificationVisible, isTrue);
    verify(checkService.shouldCheckOnStartup).called(1);
    verify(() => checkService.checkForUpdates(ignoreSkipped: false)).called(1);
  });

  test(
    'manual check exposes a safe typed failure without raw exception text',
    () async {
      final checkService = _MockUpdateCheckService();
      when(checkService.clearReminder).thenAnswer((_) async {});
      when(() => checkService.checkForUpdates(ignoreSkipped: true)).thenThrow(
        const UpdateCheckException(
          '检查更新失败',
          type: UpdateCheckFailureType.rateLimited,
          originalError: 'raw Dio stack and proxy details',
        ),
      );
      final container = ProviderContainer(
        overrides: [updateCheckServiceProvider.overrideWithValue(checkService)],
      );
      addTearDown(container.dispose);

      await container
          .read(updateStateNotifierProvider.notifier)
          .checkForUpdates(manual: true);

      final state = container.read(updateStateNotifierProvider);
      expect(state.status, UpdateStatus.error);
      expect(state.checkFailureType, UpdateCheckFailureType.rateLimited);
      expect(state.installFailure, isNull);
    },
  );

  group('install failures are exposed as types for localization', () {
    const asset = ReleaseAssetInfo(
      type: ReleaseAssetType.windowsPortable,
      platform: 'windows',
      fileName: 'update.zip',
      downloadUrl: 'https://example.test/update.zip',
      sha256: 'hash',
      size: 7,
    );
    const versionInfo = VersionInfo(
      version: '2.0.0',
      currentVersion: '1.0.0',
      releaseNotes: 'test',
      primaryAsset: asset,
      assets: [asset],
      isNewer: true,
    );

    Future<UpdateState> download(_ScriptedInstaller installer) async {
      final checkService = _MockUpdateCheckService();
      when(
        () => checkService.checkForUpdates(ignoreSkipped: false),
      ).thenAnswer((_) async => versionInfo);
      when(checkService.clearReminder).thenAnswer((_) async {});
      final container = ProviderContainer(
        overrides: [
          updateCheckServiceProvider.overrideWithValue(checkService),
          updateInstallerServiceProvider.overrideWithValue(installer),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(updateStateNotifierProvider.notifier);
      await notifier.checkForUpdates();
      await notifier.downloadUpdate();
      if (container.read(updateStateNotifierProvider).hasDownloadedUpdate) {
        await notifier.installAndRestart();
      }
      return container.read(updateStateNotifierProvider);
    }

    Future<UpdateState> initializeWith(UpdateExecutionResult result) async {
      final installer = _MockUpdateInstallerService();
      when(installer.consumeExecutionResult).thenAnswer((_) async => result);
      when(installer.restorePendingUpdate).thenAnswer((_) async => null);
      final container = ProviderContainer(
        overrides: [
          updateCheckServiceProvider.overrideWithValue(
            _MockUpdateCheckService(),
          ),
          updateInstallerServiceProvider.overrideWithValue(installer),
        ],
      );
      addTearDown(container.dispose);
      await container.read(updateStateNotifierProvider.notifier).initialize();
      return container.read(updateStateNotifierProvider);
    }

    test('download failure keeps the release and its failure type', () async {
      final state = await download(
        _ScriptedInstaller(
          downloadError: const UpdateInstallException(
            '磁盘空间不足，无法保存更新包',
            failure: UpdateInstallFailure.diskFull,
          ),
        ),
      );

      expect(state.status, UpdateStatus.error);
      expect(state.versionInfo, versionInfo);
      expect(state.installFailure, UpdateInstallFailure.diskFull);
      expect(state.checkFailureType, isNull);
    });

    test('unexpected errors fall back to the unknown install failure', () async {
      final state = await download(
        _ScriptedInstaller(downloadError: StateError('raw internal detail')),
      );

      expect(state.status, UpdateStatus.error);
      expect(state.installFailure, UpdateInstallFailure.unknown);
    });

    test('install failure keeps the verified package for a retry', () async {
      final downloaded = DownloadedUpdate(
        file: File('update.zip'),
        asset: asset,
        version: versionInfo.version,
      );
      final state = await download(
        _ScriptedInstaller(
          downloaded: downloaded,
          installError: const UpdateInstallException(
            '更新程序未能启动',
            failure: UpdateInstallFailure.updaterNotStarted,
          ),
        ),
      );

      expect(state.status, UpdateStatus.error);
      expect(state.downloadedUpdate, same(downloaded));
      expect(state.installFailure, UpdateInstallFailure.updaterNotStarted);
    });

    test('a failed updater run reports its log without the raw message', () async {
      final state = await initializeWith(
        const UpdateExecutionResult(
          success: false,
          version: '2.0.0',
          message: 'Installer exited with code 2.',
          logPath: r'C:\Temp\update_2.0.0.log',
        ),
      );

      expect(state.status, UpdateStatus.error);
      expect(state.installFailure, UpdateInstallFailure.installFailed);
      expect(state.errorLogPath, r'C:\Temp\update_2.0.0.log');
      expect(state.notificationVisible, isTrue);
    });

    test('an interrupted updater run is reported separately', () async {
      final state = await initializeWith(
        const UpdateExecutionResult(
          success: false,
          version: '2.0.0',
          interrupted: true,
        ),
      );

      expect(state.installFailure, UpdateInstallFailure.installInterrupted);
      expect(state.errorLogPath, isNull);
    });
  });

  test(
    'completed download wins a cancellation at the commit boundary',
    () async {
      const asset = ReleaseAssetInfo(
        type: ReleaseAssetType.windowsPortable,
        platform: 'windows',
        fileName: 'update.zip',
        downloadUrl: 'https://example.test/update.zip',
        sha256: 'hash',
        size: 7,
      );
      const versionInfo = VersionInfo(
        version: '2.0.0',
        currentVersion: '1.0.0',
        releaseNotes: 'test',
        primaryAsset: asset,
        assets: [asset],
        isNewer: true,
      );
      final downloaded = DownloadedUpdate(
        file: File('update.zip'),
        asset: asset,
        version: versionInfo.version,
      );
      final checkService = _MockUpdateCheckService();
      when(
        () => checkService.checkForUpdates(ignoreSkipped: false),
      ).thenAnswer((_) async => versionInfo);
      when(checkService.clearReminder).thenAnswer((_) async {});
      final container = ProviderContainer(
        overrides: [
          updateCheckServiceProvider.overrideWithValue(checkService),
          updateInstallerServiceProvider.overrideWithValue(
            _CommitBoundaryInstaller(downloaded),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(updateStateNotifierProvider.notifier);

      await notifier.checkForUpdates();
      await notifier.downloadUpdate();

      final state = container.read(updateStateNotifierProvider);
      expect(state.status, UpdateStatus.downloaded);
      expect(state.downloadedUpdate, same(downloaded));
      expect(state.downloadProgress, 1);
    },
  );
}

class _MockUpdateCheckService extends Mock implements UpdateCheckService {}

class _MockUpdateInstallerService extends Mock
    implements UpdateInstallerService {}

class _SupportedInstallationService extends AppInstallationService {
  @override
  bool get supportsInAppInstall => true;
}

class _CommitBoundaryInstaller extends UpdateInstallerService {
  _CommitBoundaryInstaller(this.downloaded)
    : super(dio: Dio(), installationService: _SupportedInstallationService());

  final DownloadedUpdate downloaded;

  @override
  Future<DownloadedUpdate> downloadUpdate(
    VersionInfo versionInfo, {
    void Function(UpdateDownloadProgress progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    cancelToken?.cancel('completed at the cancellation boundary');
    return downloaded;
  }
}

class _ScriptedInstaller extends UpdateInstallerService {
  _ScriptedInstaller({this.downloaded, this.downloadError, this.installError})
    : super(dio: Dio(), installationService: _SupportedInstallationService());

  final DownloadedUpdate? downloaded;
  final Object? downloadError;
  final Object? installError;

  @override
  Future<DownloadedUpdate> downloadUpdate(
    VersionInfo versionInfo, {
    void Function(UpdateDownloadProgress progress)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final error = downloadError;
    if (error != null) throw error;
    return downloaded!;
  }

  @override
  Future<void> installAndRestart(DownloadedUpdate update) async {
    final error = installError;
    if (error != null) throw error;
  }
}
