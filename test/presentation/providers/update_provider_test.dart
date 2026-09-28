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
      expect(state.errorMessage, isNull);
    },
  );

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
