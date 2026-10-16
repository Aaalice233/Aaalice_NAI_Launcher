import 'package:hive/hive.dart';

import '../../../core/constants/storage_keys.dart';
import '../../../core/utils/app_logger.dart';
import 'cache_manager.dart';
import 'metadata_cache_evictor.dart';

/// 每周压缩一次 L2 元数据缓存 box，每小时最多查一次文件大小，超过阈值时淘汰最旧条目。
///
/// 调度时间记在 settings box，只属于本机，不参与云同步。
class L2CacheCleaner {
  L2CacheCleaner({
    LazyBox<String>? Function()? cacheBox,
    Future<Box<dynamic>> Function()? settingsBox,
    DateTime Function()? clock,
    this.sizeThresholdBytes = _defaultSizeThresholdMB * _bytesPerMB,
    this.evictor = const MetadataCacheEvictor(),
  }) : _cacheBox = cacheBox ?? _metadataCacheBox,
       _settingsBox = settingsBox ?? _openSettingsBox,
       _clock = clock ?? DateTime.now;

  static const String _lastCleanupKey = 'l2_cache_last_cleanup';
  static const String _lastSizeCheckKey = 'l2_cache_last_size_check';
  static const Duration _cleanupInterval = Duration(days: 7);
  static const Duration _sizeCheckInterval = Duration(hours: 1);

  static const int _bytesPerMB = 1024 * 1024;
  static const int _defaultSizeThresholdMB = 500;
  // 留出余量，避免每次小幅增长都重新扫描并重写整个文件
  static const double _targetRatio = 0.8;

  final LazyBox<String>? Function() _cacheBox;
  final Future<Box<dynamic>> Function() _settingsBox;
  final DateTime Function() _clock;

  final int sizeThresholdBytes;
  final MetadataCacheEvictor evictor;

  int get targetBytes => (sizeThresholdBytes * _targetRatio).floor();

  Future<void> checkAndClean() async {
    try {
      final box = _availableCacheBox();
      if (box == null) return;
      final settings = await _settingsBox();
      final now = _clock();

      if (_isDue(settings, _lastCleanupKey, _cleanupInterval, now)) {
        await box.compact();
        await settings.put(_lastCleanupKey, '${now.millisecondsSinceEpoch}');
      }
      if (_isDue(settings, _lastSizeCheckKey, _sizeCheckInterval, now)) {
        await enforceSizeLimit();
        await settings.put(_lastSizeCheckKey, '${now.millisecondsSinceEpoch}');
      }
    } catch (e, stack) {
      AppLogger.e(
        'Failed to check L2 cache cleanup',
        e,
        stack,
        'L2CacheCleaner',
      );
    }
  }

  /// box 文件超过阈值时淘汰最旧条目；未超过阈值或缓存未就绪时返回 null
  Future<MetadataCacheEvictionResult?> enforceSizeLimit() async {
    final box = _availableCacheBox();
    if (box == null) return null;
    final bytes = await MetadataCacheEvictor.fileBytes(box);
    if (bytes <= sizeThresholdBytes) return null;

    final stopwatch = Stopwatch()..start();
    final result = await evictor.evictToTarget(box, targetBytes: targetBytes);
    AppLogger.i(
      'L2 cache evicted ${result.evictedEntries} of '
          '${result.scannedEntries} entries: '
          '${_formatMB(result.bytesBefore)} MB -> '
          '${_formatMB(result.bytesAfter)} MB (threshold '
          '${_formatMB(sizeThresholdBytes)} MB) in '
          '${stopwatch.elapsedMilliseconds} ms',
      'L2CacheCleaner',
    );
    return result;
  }

  LazyBox<String>? _availableCacheBox() {
    final box = _cacheBox();
    if (box != null && box.isOpen) return box;
    AppLogger.w('Persistent box not available for cleanup', 'L2CacheCleaner');
    return null;
  }

  static bool _isDue(
    Box<dynamic> settings,
    String key,
    Duration interval,
    DateTime now,
  ) {
    final lastMillis = int.tryParse('${settings.get(key) ?? ''}');
    if (lastMillis == null) return true;
    final elapsed = now.difference(
      DateTime.fromMillisecondsSinceEpoch(lastMillis),
    );
    // 系统时间回拨后记录落在未来，不能因此长期不检查
    return elapsed.isNegative || elapsed >= interval;
  }

  static String _formatMB(int bytes) =>
      (bytes / _bytesPerMB).toStringAsFixed(1);

  static LazyBox<String>? _metadataCacheBox() => MetadataCacheManager().box;

  static Future<Box<dynamic>> _openSettingsBox() async {
    if (Hive.isBoxOpen(StorageKeys.settingsBox)) {
      return Hive.box(StorageKeys.settingsBox);
    }
    return Hive.openBox(StorageKeys.settingsBox);
  }
}
