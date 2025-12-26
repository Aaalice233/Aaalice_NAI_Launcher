import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sequential_state_service.g.dart';

/// 顺序遍历状态服务
///
/// 用于持久化 sequential 选择模式的索引状态，
/// 确保跨会话保持遍历进度。
class SequentialStateService {
  static const String _boxName = 'sequential_state';
  Box<int>? _box;
  bool _initialized = false;

  /// 初始化服务
  Future<void> init() async {
    if (_initialized) return;
    _box = await Hive.openBox<int>(_boxName);
    _initialized = true;
  }

  /// 确保已初始化
  Future<void> _ensureInitialized() async {
    if (!_initialized) {
      await init();
    }
  }

  /// 获取当前索引（不递增）
  Future<int> getCurrentIndex(String key, int itemCount) async {
    await _ensureInitialized();
    if (itemCount <= 0) return 0;

    final currentIndex = _box?.get(key, defaultValue: 0) ?? 0;
    return currentIndex % itemCount;
  }

  /// 获取下一个索引并递增
  Future<int> getNextIndex(String key, int itemCount) async {
    await _ensureInitialized();
    if (itemCount <= 0) return 0;

    final currentIndex = _box?.get(key, defaultValue: 0) ?? 0;
    final nextIndex = (currentIndex + 1) % itemCount;
    await _box?.put(key, nextIndex);

    return currentIndex % itemCount;
  }

  /// 获取下一个索引（同步版本，需要先调用 init）
  int getNextIndexSync(String key, int itemCount) {
    if (itemCount <= 0) return 0;

    final currentIndex = _box?.get(key, defaultValue: 0) ?? 0;
    final nextIndex = (currentIndex + 1) % itemCount;
    _box?.put(key, nextIndex);

    return currentIndex % itemCount;
  }

  /// 重置指定 key 的索引
  Future<void> resetIndex(String key) async {
    await _ensureInitialized();
    await _box?.delete(key);
  }

  /// 重置所有索引
  Future<void> resetAll() async {
    await _ensureInitialized();
    await _box?.clear();
  }

  /// 获取所有存储的 key
  Future<List<String>> getAllKeys() async {
    await _ensureInitialized();
    return _box?.keys.cast<String>().toList() ?? [];
  }
}

/// Provider
@Riverpod(keepAlive: true)
SequentialStateService sequentialStateService(Ref ref) {
  final service = SequentialStateService();
  // 异步初始化
  service.init();
  return service;
}
