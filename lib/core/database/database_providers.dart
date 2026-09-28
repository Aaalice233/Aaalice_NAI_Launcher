import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'database_manager.dart';

part 'database_providers.g.dart';

@Riverpod(keepAlive: true)
Future<DatabaseManager> databaseManager(Ref ref) async {
  final manager = await DatabaseManager.initialize();
  await manager.initialized;
  return manager;
}

@riverpod
Future<bool> databaseInitialized(Ref ref) async {
  final manager = await ref.watch(databaseManagerProvider.future);
  await manager.initialized;
  return manager.isInitialized;
}

@riverpod
Future<Map<String, dynamic>> databaseStatistics(Ref ref) async {
  final manager = await ref.watch(databaseManagerProvider.future);
  await manager.initialized;
  return await manager.getStatistics();
}
