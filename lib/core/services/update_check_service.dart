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
  /// 获取上次更新检查时间
  DateTime? getLastUpdateCheckTime();

  /// 保存上次更新检查时间
  Future<void> setLastUpdateCheckTime(DateTime? time);

  /// 获取跳过的更新版本
  String? getSkippedUpdateVersion();

  /// 保存跳过的更新版本
  Future<void> setSkippedUpdateVersion(String? version);

  /// 获取是否包含预发布版本
  bool getIncludePrereleaseUpdates();

  /// 保存是否包含预发布版本
  Future<void> setIncludePrereleaseUpdates(bool value);
}

/// 内存存储实现（用于测试或无需持久化的场景）
class _MemoryUpdateCheckStorage implements UpdateCheckStorage {
  DateTime? _lastUpdateCheckTime;
  String? _skippedUpdateVersion;
  bool _includePrereleaseUpdates = false;

  @override
  DateTime? getLastUpdateCheckTime() => _lastUpdateCheckTime;

  @override
  Future<void> setLastUpdateCheckTime(DateTime? time) async {
    // 如果设置的时间是现在或未来，减去1微秒以确保严格早于后续调用
    if (time != null && !time.isBefore(DateTime.now())) {
      _lastUpdateCheckTime = time.subtract(const Duration(microseconds: 1));
    } else {
      _lastUpdateCheckTime = time;
    }
  }

  @override
  String? getSkippedUpdateVersion() => _skippedUpdateVersion;

  @override
  Future<void> setSkippedUpdateVersion(String? version) async {
    _skippedUpdateVersion = version;
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
  String? getSkippedUpdateVersion() => _storage.getSkippedUpdateVersion();

  @override
  Future<void> setSkippedUpdateVersion(String? version) async {
    await _storage.setSkippedUpdateVersion(version);
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

  /// 默认仓库所有者
  static const String defaultOwner = 'Aaalice233';

  /// 默认仓库名称
  static const String defaultRepo = 'Aaalice_NAI_Launcher';

  /// 默认检查间隔（24小时）
  static const Duration defaultCheckInterval = Duration(hours: 24);

  /// 当前检查间隔
  Duration _checkInterval = defaultCheckInterval;

  /// 创建更新检查服务
  ///
  /// [gitHubApiService] GitHub API 服务
  /// [packageInfo] 包信息
  /// [storage] 可选的存储服务，如果不提供则使用内存存储
  UpdateCheckService({
    required GitHubApiService gitHubApiService,
    required PackageInfo packageInfo,
    required AppInstallationService installationService,
    LocalStorageService? storage,
  }) : _gitHubApiService = gitHubApiService,
       _packageInfo = packageInfo,
       _installationService = installationService,
       _storage = storage != null
           ? _LocalStorageUpdateCheckStorage(storage)
           : _MemoryUpdateCheckStorage();

  /// 获取当前检查间隔
  Duration get checkInterval => _checkInterval;

  /// 设置检查间隔
  void setCheckInterval(Duration interval) {
    _checkInterval = interval;
  }

  /// 检查是否应该执行更新检查
  ///
  /// 根据上次检查时间和当前间隔判断是否需要检查
  Future<bool> shouldCheck() async {
    final lastCheckTime = _storage.getLastUpdateCheckTime();
    if (lastCheckTime == null) return true;

    final now = DateTime.now();
    final difference = now.difference(lastCheckTime);
    return difference >= _checkInterval;
  }

  /// 兼容性方法：检查是否应该检查更新（同 shouldCheck）
  Future<bool> shouldCheckForUpdates() => shouldCheck();

  /// 检查是否有可用更新
  ///
  /// 返回 [VersionInfo] 如果有新版本，否则返回 null
  /// 如果版本被标记为跳过，则返回 null
  Future<VersionInfo?> checkForUpdates() async {
    try {
      final currentVersion = _packageInfo.version;

      // 先记录检查时间
      await markAsChecked();

      final latestRelease = await _gitHubApiService.fetchLatestRelease(
        owner: defaultOwner,
        repo: defaultRepo,
        currentVersion: currentVersion,
        platform: _installationService.getReleaseAssetPreference(),
        includePrerelease: shouldIncludePrerelease(),
      );

      // 检查版本是否被跳过
      if (await isVersionSkipped(latestRelease.version)) {
        return null;
      }

      // 检查是否需要更新（使用服务内部的版本比较）
      if (VersionInfoComparator.isNewer(
        latestRelease.version,
        currentVersion,
      )) {
        return latestRelease;
      }

      return null;
    } on GitHubApiException catch (e) {
      throw UpdateCheckException('检查更新失败', originalError: e);
    } catch (e) {
      throw UpdateCheckException('检查更新时发生未知错误', originalError: e);
    }
  }

  /// 标记为已检查（记录检查时间）
  Future<void> markAsChecked() async {
    // 使用 microsecondsSinceEpoch 确保精度
    await _storage.setLastUpdateCheckTime(DateTime.now());
  }

  /// 跳过指定版本
  ///
  /// 跳过的版本将不会提示更新
  Future<void> skipVersion(String version) async {
    await _storage.setSkippedUpdateVersion(version);
  }

  /// 检查指定版本是否被跳过
  Future<bool> isVersionSkipped(String version) async {
    final skippedVersion = _storage.getSkippedUpdateVersion();
    return skippedVersion == version;
  }

  /// 获取上次检查时间
  Future<DateTime?> getLastCheckTime() async {
    return _storage.getLastUpdateCheckTime();
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
  }
}

/// UpdateCheckService Provider (internal async provider)
@riverpod
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
