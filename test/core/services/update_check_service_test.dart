import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/services/app_installation_service.dart';
import 'package:nai_launcher/core/services/update_check_service.dart';
import 'package:nai_launcher/data/datasources/remote/github_api_service.dart';
import 'package:nai_launcher/data/models/version/version_info.dart';
import 'package:package_info_plus/package_info_plus.dart';

class _FakeGitHubApiService extends GitHubApiService {
  _FakeGitHubApiService(this.handler) : super(dio: Dio());

  final Future<VersionInfo> Function(String currentVersion) handler;

  @override
  Future<VersionInfo> fetchLatestRelease({
    required String owner,
    required String repo,
    required String currentVersion,
    String platform = 'windows',
    bool includePrerelease = false,
  }) {
    return handler(currentVersion);
  }
}

class _FakeInstallationService extends AppInstallationService {
  @override
  String getReleaseAssetPreference() => 'windows-portable';
}

class _FakeUpdateStorage implements UpdateCheckStorage {
  DateTime? success;
  DateTime? attempt;
  String? skipped;
  String? known;
  DateTime? remindAfter;
  bool prerelease = false;

  @override
  DateTime? getLastUpdateCheckTime() => success;

  @override
  Future<void> setLastUpdateCheckTime(DateTime? time) async => success = time;

  @override
  DateTime? getLastUpdateCheckAttemptTime() => attempt;

  @override
  Future<void> setLastUpdateCheckAttemptTime(DateTime? time) async =>
      attempt = time;

  @override
  String? getSkippedUpdateVersion() => skipped;

  @override
  Future<void> setSkippedUpdateVersion(String? version) async =>
      skipped = version;

  @override
  String? getLastKnownUpdateVersion() => known;

  @override
  Future<void> setLastKnownUpdateVersion(String? version) async =>
      known = version;

  @override
  DateTime? getUpdateRemindAfter() => remindAfter;

  @override
  Future<void> setUpdateRemindAfter(DateTime? time) async => remindAfter = time;

  @override
  bool getIncludePrereleaseUpdates() => prerelease;

  @override
  Future<void> setIncludePrereleaseUpdates(bool value) async =>
      prerelease = value;
}

void main() {
  late DateTime now;
  late _FakeUpdateStorage storage;

  PackageInfo packageInfo() => PackageInfo(
    appName: 'NAI Launcher',
    packageName: 'nai_launcher',
    version: '1.0.0',
    buildNumber: '1',
  );

  UpdateCheckService buildService(
    Future<VersionInfo> Function(String currentVersion) handler,
  ) {
    return UpdateCheckService(
      gitHubApiService: _FakeGitHubApiService(handler),
      packageInfo: packageInfo(),
      installationService: _FakeInstallationService(),
      checkStorage: storage,
      now: () => now,
    );
  }

  setUp(() {
    now = DateTime.utc(2026, 3, 1, 8);
    storage = _FakeUpdateStorage();
  });

  test(
    'failed checks record only an attempt and retry after 30 minutes',
    () async {
      final service = buildService(
        (_) async => throw GitHubApiException('offline'),
      );

      await expectLater(
        service.checkForUpdates(),
        throwsA(isA<UpdateCheckException>()),
      );

      expect(storage.attempt, now);
      expect(storage.success, isNull);
      expect(await service.shouldCheck(), isFalse);

      now = now.add(const Duration(minutes: 31));
      expect(await service.shouldCheck(), isTrue);
    },
  );

  test('successful checks use the regular 24 hour interval', () async {
    final service = buildService(
      (current) async => VersionInfo(
        version: current,
        currentVersion: current,
        isNewer: false,
      ),
    );

    expect(await service.checkForUpdates(), isNull);
    expect(storage.success, now);
    expect(await service.shouldCheck(), isFalse);

    now = now.add(const Duration(hours: 24));
    expect(await service.shouldCheck(), isTrue);
  });

  test('remind later suppresses a known update until the deadline', () async {
    final service = buildService(
      (current) async =>
          VersionInfo(version: '2.0.0', currentVersion: current, isNewer: true),
    );

    expect(await service.checkForUpdates(), isNotNull);
    await service.remindLater();
    expect(storage.known, '2.0.0');
    expect(await service.shouldCheck(), isFalse);

    now = now.add(const Duration(hours: 4));
    expect(await service.shouldCheck(), isTrue);
  });

  test('manual checks can reveal a previously skipped version', () async {
    final service = buildService(
      (current) async =>
          VersionInfo(version: '2.0.0', currentVersion: current, isNewer: true),
    );
    await service.skipVersion('2.0.0');

    expect(await service.checkForUpdates(), isNull);
    expect(await service.checkForUpdates(ignoreSkipped: true), isNotNull);
  });
}
