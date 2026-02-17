import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database_manager.dart';

part 'database_providers.g.dart';

/// 数据库管理器 Provider (V2)
/// 
/// 使用新的 DatabaseManagerV2，支持热重启和恢复后自动重建
@Riverpod(keepAlive: true)
Future<DatabaseManager> databaseManager(Ref ref) async {
  final manager = await DatabaseManager.initialize();
  await manager.initialized;
  return manager;
}

/// 数据库初始化状态 Provider
@riverpod
Future<bool> databaseInitialized(Ref ref) async {
  final manager = await ref.watch(databaseManagerProvider.future);
  await manager.initialized;
  return manager.isInitialized;
}

/// 数据库统计信息 Provider
@riverpod
Future<Map<String, dynamic>> databaseStatistics(Ref ref) async {
  final manager = await ref.watch(databaseManagerProvider.future);
  await manager.initialized;
  return await manager.getStatistics();
}
