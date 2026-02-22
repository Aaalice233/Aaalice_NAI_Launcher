import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../utils/app_logger.dart';

/// Sqflite 启动初始化服务
///
/// 在桌面端统一初始化 sqflite FFI，全局仅执行一次，支持并发安全。
class SqfliteBootstrapService {
  SqfliteBootstrapService._();

  static final SqfliteBootstrapService instance = SqfliteBootstrapService._();

  bool _initialized = false;
  Future<void>? _initFuture;

  Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }

    _initFuture ??= _doInitialize();
    await _initFuture;
  }

  Future<void> _doInitialize() async {
    if (!(Platform.isWindows || Platform.isLinux)) {
      _initialized = true;
      return;
    }

    sqfliteFfiInit();

    var shouldAssignFfiFactory = true;
    try {
      shouldAssignFfiFactory = !identical(databaseFactory, databaseFactoryFfi);
    } on StateError {
      shouldAssignFfiFactory = true;
    }

    if (shouldAssignFfiFactory) {
      databaseFactory = databaseFactoryFfi;
    }

    _initialized = true;
    AppLogger.i('Sqflite FFI initialized for desktop', 'SqfliteBootstrap');
  }
}
