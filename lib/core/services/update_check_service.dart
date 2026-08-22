import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/datasources/remote/github_api_service.dart';
import '../../../data/models/version/version_info.dart';
import '../storage/local_storage_service.dart';
import 'app_installation_service.dart';

part 'update_check_service.g.dart';

/// 更新检查异常
class UpdateCheckException implements Exception {
  /// 错误消息
  final String message;

  /// 原始异常
  final Object? originalError;

  const UpdateCheckException(this.message, {this.originalError});

  @override
  String toString() =>
      'UpdateCheckException: $message${originalError != null ? ' (原始错误: $originalError)' : ''}';
}

/// 更新检查存储接口
///
/// 定义更新检查所需的存储操作
abstract class UpdateCheckStorage {
  /// 获取上次成功完成更新检查的时间
  DateTime? getLastUpdateCheckTime();

  /// 保存上次成功完成更新检查的时间
  Future<void> setLastUpdateCheckTime(DateTime? time);

  /// 获取最近一次更新检查尝试时间
  DateTime? getLastUpdateCheckAttemptTime();

  /// 保存最近一次更新检查尝试时间
  Future<void> setLastUpdateCheckAttemptTime(DateTime? time);

  /// 获取跳过的更新版本
  String? getSkippedUpdateVersion();

  /// 保存跳过的更新版本
  Future<void> setSkippedUpdateVersion(String? version);

  /// 获取上次发现的新版本
  String? getLastKnownUpdateVersion();

  /// 保存上次发现的新版本
  Future<void> setLastKnownUpdateVersion(String? version);

  /// 获取更新提示延后时间
  DateTime? getUpdateRemindAfter();

  /// 保存更新提示延后时间
  Future<void> setUpdateRemindAfter(DateTime? time);

  /// 获取是否包含预发布版本
  bool getIncludePrereleaseUpdates();

  /// 保存是否包含预发布版本
  Future<void> setIncludePrereleaseUpdates(bool value);
}

/// 内存存储实现（用于测试或无需持久化的场景）
class _MemoryUpdateCheckStorage implements UpdateCheckStorage {
  DateTime? _lastUpdateCheckTime;
  DateTime? _lastUpdateCheckAttemptTime;
  String? _skippedUpdateVersion;
  String? _lastKnownUpdateVersion;
  DateTime? _updateRemindAfter;
  bool _includePrereleaseUpdates = false;

  @override
  DateTime? getLastUpdateCheckTime() => _lastUpdateCheckTime;

  @override
  Future<void> setLastUpdateCheckTime(DateTime? time) async {
    _lastUpdateCheckTime = time;
  }

  @override
  DateTime? getLastUpdateCheckAttemptTime() => _lastUpdateCheckAttemptTime;

  @override
  Future<void> setLastUpdateCheckAttemptTime(DateTime? time) async {
    _lastUpdateCheckAttemptTime = time;
  }

  @override
  String? getSkippedUpdateVersion() => _skippedUpdateVersion;

  @override
  Future<void> setSkippedUpdateVersion(String? version) async {
    _skippedUpdateVersion = version;
  }

  @override
  String? getLastKnownUpdateVersion() => _lastKnownUpdateVersion;

  @override
  Future<void> setLastKnownUpdateVersion(String? version) async {
    _lastKnownUpdateVersion = version;
  }

  @override
  DateTime? getUpdateRemindAfter() => _updateRemindAfter;

  @override
  Future<void> setUpdateRemindAfter(DateTime? time) async {
    _updateRemindAfter = time;
  }

  @override
  bool getIncludePrereleaseUpdates() => _includePrereleaseUpdates;

  @override
  Future<void> setIncludePrereleaseUpdates(bool value) async {
    _includePrereleaseUpdates = value;
  }
}

/// LocalStorageService 的适配器，实现 UpdateCheckStorage 接口
class _LocalStorageUpdateCheckStorage implements UpdateCheckStorage {
  final LocalStorageService _storage;

  _LocalStorageUpdateCheckStorage(this._storage);

  @override
  DateTime? getLastUpdateCheckTime() => _storage.getLastUpdateCheckTime();

  @override
  Future<void> setLastUpdateCheckTime(DateTime? time) async {
    await _storage.setLastUpdateCheckTime(time);
  }

  @override
  DateTime? getLastUpdateCheckAttemptTime() =>
      _storage.getLastUpdateCheckAttemptTime();

  @override
  Future<void> setLastUpdateCheckAttemptTime(DateTime? time) async {
    await _storage.setLastUpdateCheckAttemptTime(time);
  }

  @override
  String? getSkippedUpdateVersion() => _storage.getSkippedUpdateVersion();

  @override
  Future<void> setSkippedUpdateVersion(String? version) async {
    await _storage.setSkippedUpdateVersion(version);
  }

  @override
  String? getLastKnownUpdateVersion() => _storage.getLastKnownUpdateVersion();

  @override
  Future<void> setLastKnownUpdateVersion(String? version) async {
    await _storage.setLastKnownUpdateVersion(version);
  }

  @override
  DateTime? getUpdateRemindAfter() => _storage.getUpdateRemindAfter();

  @override
  Future<void> setUpdateRemindAfter(DateTime? time) async {
    await _storage.setUpdateRemindAfter(time);
  }

  @override
  bool getIncludePrereleaseUpdates() => _storage.getIncludePrereleaseUpdates();

  @override
  Future<void> setIncludePrereleaseUpdates(bool value) async {
    await _storage.setIncludePrereleaseUpdates(value);
  }
}

/// 更新检查服务
///
/// 负责检查应用更新，支持：
/// - 24小时检查间隔控制
/// - 版本跳过功能
/// - 预发布版本包含开关
class UpdateCheckService {
  /// GitHub API 服务
  final GitHubApiService _gitHubApiService;

  /// 存储接口
  final UpdateCheckStorage _storage;

  /// 包信息
  final PackageInfo _packageInfo;

  /// 当前安装形态检测服务
  final AppInstallationService _installationService;

  final DateTime Function() _now;

  /// 默认仓库所有者
  static const String defaultOwner = 'Aaalice233';

  /// 默认仓库名称
  static const String defaultRepo = 'Aaalice_NAI_Launcher';

  /// 默认检查间隔（24小时）
  static const Duration defaultCheckInterval = Duration(hours: 24);

  /// 检查失败后的重试间隔
  static const Duration failedCheckRetryInterval = Duration(minutes: 30);

  /// “稍后提醒”的默认延后时间
  static const Duration defaultReminderDelay = Duration(hours: 4);

  /// 当前检查间隔
  Duration _checkInterval = defaultCheckInterval;

  /// 创建更新检查服务
  ///
  /// [gitHubApiService] GitHub API 服务
  /// [packageInfo] 包信息
  /// [storage] 可选的持久存储服务；[checkStorage] 用于测试或替代实现，
  /// 两者不能同时提供。
  UpdateCheckService({
    required GitHubApiService gitHubApiService,
    required PackageInfo packageInfo,
    required AppInstallationService installationService,
    LocalStorageService? storage,
    UpdateCheckStorage? checkStorage,
    DateTime Function()? now,
  }) : assert(storage == null || checkStorage == null),
       _gitHubApiService = gitHubApiService,
       _packageInfo = packageInfo,
       _installationService = installationService,
       _now = now ?? DateTime.now,
       _storage =
           checkStorage ??
           (storage != null
               ? _LocalStorageUpdateCheckStorage(storage)
               : _MemoryUpdateCheckStorage());

  /// 获取当前检查间隔
  Duration get checkInterval => _checkInterval;

  /// 设置检查间隔
  void setCheckInterval(Duration interval) {
    _checkInterval = interval;
  }

  /// 检查是否应该执行更新检查。
  ///
  /// 成功检查使用常规 24 小时间隔；失败尝试只冷却 30 分钟。已经发现
  /// 新版本时，“稍后提醒”到期会绕过常规间隔，确保提示不会消失一天。
  Future<bool> shouldCheck() async {
    final now = _now();
    final remindAfter = _storage.getUpdateRemindAfter();
    if (remindAfter != null && now.isBefore(remindAfter)) {
      return false;
    }

    final lastAttempt = _storage.getLastUpdateCheckAttemptTime();
    if (lastAttempt != null &&
        now.difference(lastAttempt) < failedCheckRetryInterval) {
      final lastSuccess = _storage.getLastUpdateCheckTime();
      if (lastSuccess == null || lastAttempt.isAfter(lastSuccess)) {
        return false;
      }
    }

    final knownVersion = _storage.getLastKnownUpdateVersion();
    final skippedVersion = _storage.getSkippedUpdateVersion();
    if (knownVersion != null &&
        knownVersion != skippedVersion &&
        VersionInfoComparator.isNewer(knownVersion, currentVersion)) {
      return true;
    }

    final lastCheckTime = _storage.getLastUpdateCheckTime();
    if (lastCheckTime == null) return true;
    return now.difference(lastCheckTime) >= _checkInterval;
  }

  /// 兼容性方法：检查是否应该检查更新（同 shouldCheck）
  Future<bool> shouldCheckForUpdates() => shouldCheck();

  /// 检查是否有可用更新
  ///
  /// 返回 [VersionInfo] 如果有新版本，否则返回 null
  /// 如果版本被标记为跳过，则返回 null
  Future<VersionInfo?> checkForUpdates({bool ignoreSkipped = false}) async {
    final attemptTime = _now();
    await _storage.setLastUpdateCheckAttemptTime(attemptTime);

    try {
      final latestRelease = await _gitHubApiService.fetchLatestRelease(
        owner: defaultOwner,
        repo: defaultRepo,
        currentVersion: currentVersion,
        platform: _installationService.getReleaseAssetPreference(),
        includePrerelease: shouldIncludePrerelease(),
      );

      // 只有远端响应成功才进入常规检查冷却，网络失败不会吞掉一天提示。
      await markAsChecked();

      if (VersionInfoComparator.isNewer(
        latestRelease.version,
        currentVersion,
      )) {
        await _storage.setLastKnownUpdateVersion(latestRelease.version);
        if (!ignoreSkipped && await isVersionSkipped(latestRelease.version)) {
          return null;
        }
        return latestRelease;
      }

      await _storage.setLastKnownUpdateVersion(null);
      await _storage.setUpdateRemindAfter(null);
      return null;
    } on GitHubApiException catch (e) {
      throw UpdateCheckException('检查更新失败', originalError: e);
    } catch (e) {
      if (e is UpdateCheckException) rethrow;
      throw UpdateCheckException('检查更新时发生未知错误', originalError: e);
    }
  }

  /// 当前应用版本
  String get currentVersion => _packageInfo.version;

  /// 标记为成功完成检查
  Future<void> markAsChecked() async {
    await _storage.setLastUpdateCheckTime(_now());
  }

  /// 跳过指定版本
  ///
  /// 跳过的版本将不会提示更新
  Future<void> skipVersion(String version) async {
    await _storage.setSkippedUpdateVersion(version);
    await _storage.setUpdateRemindAfter(null);
  }

  /// 检查指定版本是否被跳过
  Future<bool> isVersionSkipped(String version) async {
    final skippedVersion = _storage.getSkippedUpdateVersion();
    return skippedVersion == version;
  }

  /// 获取上次成功检查时间
  Future<DateTime?> getLastCheckTime() async {
    return _storage.getLastUpdateCheckTime();
  }

  /// 当前是否已到再次提示更新时间
  bool isReminderDue() {
    final remindAfter = _storage.getUpdateRemindAfter();
    return remindAfter == null || !_now().isBefore(remindAfter);
  }

  /// 距离更新提示恢复还剩多久；没有延后状态时返回 null。
  Duration? get reminderDelayRemaining {
    final remindAfter = _storage.getUpdateRemindAfter();
    if (remindAfter == null) return null;
    final remaining = remindAfter.difference(_now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  /// 延后当前更新提示
  Future<void> remindLater({Duration delay = defaultReminderDelay}) async {
    await _storage.setUpdateRemindAfter(_now().add(delay));
  }

  /// 清除更新提示延后状态
  Future<void> clearReminder() async {
    await _storage.setUpdateRemindAfter(null);
  }

  /// 获取是否包含预发布版本
  bool shouldIncludePrerelease() {
    return _storage.getIncludePrereleaseUpdates();
  }

  /// 设置是否包含预发布版本
  Future<void> setIncludePrerelease(bool value) async {
    await _storage.setIncludePrereleaseUpdates(value);
  }

  /// 清除跳过的版本
  Future<void> clearSkippedVersion() async {
    await _storage.setSkippedUpdateVersion(null);
    await _storage.setUpdateRemindAfter(null);
  }
}

/// UpdateCheckService Provider (internal async provider)
@Riverpod(keepAlive: true)
Future<UpdateCheckService> _updateCheckServiceFuture(Ref ref) async {
  final gitHubApiService = ref.watch(gitHubApiServiceProvider);
  final localStorageService = ref.watch(localStorageServiceProvider);
  final installationService = ref.watch(appInstallationServiceProvider);
  final packageInfo = await PackageInfo.fromPlatform();

  return UpdateCheckService(
    gitHubApiService: gitHubApiService,
    packageInfo: packageInfo,
    installationService: installationService,
    storage: localStorageService,
  );
}

/// UpdateCheckService Provider
///
/// 这是一个同步 Provider，通过监听内部的异步 Provider 来获取服务实例。
/// 在测试时可以使用 overrideWithValue 进行覆盖。
final updateCheckServiceProvider = Provider<UpdateCheckService>((ref) {
  final asyncValue = ref.watch(_updateCheckServiceFutureProvider);
  return asyncValue.when(
    data: (service) => service,
    loading: () => throw StateError(
      'UpdateCheckService is still loading. '
      'Make sure to handle loading state before accessing this provider.',
    ),
    error: (error, stack) =>
        throw StateError('Failed to initialize UpdateCheckService: $error'),
  );
});

/// 公开的异步初始化 Provider，供需要等待服务可用的调用方使用。
final updateCheckServiceReadyProvider = _updateCheckServiceFutureProvider;
