import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// 增强版应用日志工具类
///
/// 功能：
/// - 支持控制台和文件双输出
/// - 自动保留最近3个启动的日志文件
/// - 正式环境：app_YYYYMMDD_HHMMSS.log
/// - 测试环境：test_YYYYMMDD_HHMMSS.log
/// - 日志目录：Documents/NAI_Launcher/logs/ (与 images/ 平级)
class AppLogger {
  static Logger? _logger;
  static FileOutput? _fileOutput;
  static bool _initialized = false;
  static bool _isTestEnvironment = false;
  static bool _fileLoggingEnabled = false;
  static Level? _minimumLevelOverride;

  /// 文件日志轮转检查摊销阈值。
  static const int _rotateCheckLogInterval = 500;
  static const Duration _rotateCheckTimeInterval = Duration(seconds: 30);
  static int _logsSinceRotateCheck = 0;
  static DateTime? _lastRotateCheckAt;

  /// 日志文件最大数量
  static const int _maxLogFiles = 3;

  /// 单个日志文件最大大小 (100MB)
  static const int _maxLogFileSize = 100 * 1024 * 1024;

  /// 日志目录路径
  static String? _logDirectory;

  /// 当前日志文件路径
  static String? _currentLogFile;

  /// 初始化日志系统
  ///
  /// [isTestEnvironment] - 是否为测试环境（影响日志文件名前缀）
  /// [enableFileLogging] - 是否写入日志文件。应用启动时由设置项控制。
  static Future<void> initialize({
    bool isTestEnvironment = false,
    bool enableFileLogging = true,
  }) async {
    if (_initialized) {
      final environmentChanged = isTestEnvironment != _isTestEnvironment;
      _isTestEnvironment = isTestEnvironment;

      if (enableFileLogging != _fileLoggingEnabled) {
        await setFileLoggingEnabled(enableFileLogging);
      } else if (environmentChanged && _fileLoggingEnabled) {
        await _recreateFileOutput();
      }
      return;
    }

    _isTestEnvironment = isTestEnvironment;
    _fileLoggingEnabled = enableFileLogging;

    if (_fileLoggingEnabled) {
      _fileLoggingEnabled = await _enableFileOutput();
    }

    _logger = _buildLogger();

    _initialized = true;

    i('日志系统初始化完成', 'AppLogger');
    if (_fileLoggingEnabled) {
      i('日志文件: $_currentLogFile', 'AppLogger');
    } else {
      i('文件日志记录已关闭', 'AppLogger');
    }
    i('运行环境: ${_isTestEnvironment ? "测试" : "正式"}', 'AppLogger');
  }

  static Logger _buildLogger() {
    final outputs = <LogOutput>[ConsoleOutput()];
    if (_fileLoggingEnabled && _fileOutput != null) {
      outputs.add(_fileOutput!);
    }

    return Logger(
      filter: ProductionFilter(),
      printer: SimplePrinter(printTime: true),
      level: _minimumLevel,
      output: outputs.length == 1 ? outputs.first : MultiOutput(outputs),
    );
  }

  static Level get _minimumLevel {
    return _minimumLevelOverride ??
        (kReleaseMode ? Level.warning : Level.trace);
  }

  static bool _shouldLog(Level level) => level >= _minimumLevel;

  @visibleForTesting
  static void debugSetMinimumLevelForTesting(Level? level) {
    _minimumLevelOverride = level;
    if (_logger != null) {
      _logger = _buildLogger();
    }
  }

  static Future<bool> _enableFileOutput() async {
    try {
      await _setupLogDirectory();
      await _cleanupOldLogs();
      await _createNewLogFile();
      return _fileOutput != null;
    } catch (_) {
      // File logging is optional at startup; logger output may not exist yet.
      await _fileOutput?.destroy();
      _fileOutput = null;
      _currentLogFile = null;
      return false;
    }
  }

  static Future<void> _recreateFileOutput() async {
    final oldFileOutput = _fileOutput;
    _fileOutput = null;
    _currentLogFile = null;

    await oldFileOutput?.destroy();

    _fileLoggingEnabled = await _enableFileOutput();
    _logger = _buildLogger();

    if (_fileLoggingEnabled) {
      i('日志文件: $_currentLogFile', 'AppLogger');
    } else {
      w('文件日志记录重新初始化失败，已回退到控制台日志', 'AppLogger');
    }
  }

  /// 当前是否启用文件日志记录。
  static bool get fileLoggingEnabled => _fileLoggingEnabled;

  /// 即时开启或关闭文件日志记录。
  static Future<void> setFileLoggingEnabled(bool enabled) async {
    if (!_initialized) {
      await initialize(
        isTestEnvironment: _isTestEnvironment,
        enableFileLogging: enabled,
      );
      return;
    }

    if (enabled == _fileLoggingEnabled) return;

    if (enabled) {
      _fileLoggingEnabled = true;
      _fileLoggingEnabled = await _enableFileOutput();
      _logger = _buildLogger();
      _resetRotateCheckState();

      if (_fileLoggingEnabled) {
        i('文件日志记录已开启', 'AppLogger');
        i('日志文件: $_currentLogFile', 'AppLogger');
      } else {
        w('文件日志记录开启失败，已回退到控制台日志', 'AppLogger');
      }
      return;
    }

    i('文件日志记录即将关闭', 'AppLogger');
    await flush();

    final oldFileOutput = _fileOutput;
    _fileOutput = null;
    _currentLogFile = null;
    _fileLoggingEnabled = false;
    _resetRotateCheckState();
    _logger = _buildLogger();

    await oldFileOutput?.destroy();
    i('文件日志记录已关闭', 'AppLogger');
  }

  /// 设置日志目录
  ///
  /// 日志目录：Documents/NAI_Launcher/logs/ (与 images/ 平级)
  static Future<void> _setupLogDirectory() async {
    try {
      // 使用 Documents/NAI_Launcher/logs/ 路径，与 images/ 平级
      final appDir = await getApplicationDocumentsDirectory();
      _logDirectory = path.join(appDir.path, 'NAI_Launcher', 'logs');

      // 创建目录
      final dir = Directory(_logDirectory!);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } catch (e) {
      // 回退到临时目录
      _logDirectory = Directory.systemTemp.path;
    }
  }

  /// 清理旧日志文件（保留最近3个，单个文件最大100MB）
  static Future<void> _cleanupOldLogs() async {
    if (_logDirectory == null) return;

    try {
      final dir = Directory(_logDirectory!);
      if (!await dir.exists()) return;

      // 获取所有日志文件
      final files = await dir
          .list()
          .where((entity) => entity is File)
          .map((entity) => entity as File)
          .where((file) {
            final name = path.basename(file.path);
            return name.startsWith('app_') || name.startsWith('test_');
          })
          .toList();

      // 按修改时间排序（最新的在前）
      files.sort((a, b) {
        return b.lastModifiedSync().compareTo(a.lastModifiedSync());
      });

      // 删除超大日志文件（超过100MB）
      for (final file in files) {
        try {
          final size = await file.length();
          if (size > _maxLogFileSize) {
            await file.delete();
          }
        } catch (e) {
          // 忽略删除失败的文件
        }
      }

      // 重新获取文件列表（可能已删除部分）
      final remainingFiles = await dir
          .list()
          .where((entity) => entity is File)
          .map((entity) => entity as File)
          .where((file) {
            final name = path.basename(file.path);
            return name.startsWith('app_') || name.startsWith('test_');
          })
          .toList();

      remainingFiles.sort((a, b) {
        return b.lastModifiedSync().compareTo(a.lastModifiedSync());
      });

      // 删除超过数量限制的旧日志文件
      if (remainingFiles.length >= _maxLogFiles) {
        final filesToDelete = remainingFiles.sublist(_maxLogFiles - 1);
        for (final file in filesToDelete) {
          try {
            await file.delete();
          } catch (e) {
            // 忽略删除失败的文件
          }
        }
      }
    } catch (e) {
      // 忽略清理错误
    }
  }

  /// 创建新的日志文件
  static Future<void> _createNewLogFile() async {
    if (_logDirectory == null) return;

    final now = DateTime.now();
    final timestamp =
        '${now.year}${_pad(now.month)}${_pad(now.day)}_'
        '${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';

    final prefix = _isTestEnvironment ? 'test' : 'app';
    final fileName = '${prefix}_$timestamp.log';
    _currentLogFile = path.join(_logDirectory!, fileName);

    _fileOutput = FileOutput(file: File(_currentLogFile!));
    await _fileOutput!.init();
  }

  static String _pad(int number) => number.toString().padLeft(2, '0');

  /// 获取日志目录路径
  static String? get logDirectory => _logDirectory;

  /// 获取用于显示的日志路径
  static String getDisplayPath() {
    return 'Documents/NAI_Launcher/logs/';
  }

  /// 获取当前日志文件路径
  static String? get currentLogFile => _currentLogFile;

  /// 获取所有日志文件列表（按时间倒序）
  static Future<List<File>> getLogFiles() async {
    if (_logDirectory == null) return [];

    final dir = Directory(_logDirectory!);
    if (!await dir.exists()) return [];

    final files = await dir
        .list()
        .where((entity) => entity is File)
        .map((entity) => entity as File)
        .where((file) {
          final name = path.basename(file.path);
          return name.startsWith('app_') || name.startsWith('test_');
        })
        .toList();

    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  /// 检查并轮转日志文件（如果超过100MB则创建新文件）
  static void _checkAndRotateLogFile() {
    if (!_fileLoggingEnabled ||
        _currentLogFile == null ||
        _logDirectory == null) {
      return;
    }
    if (!_shouldCheckRotateNow()) return;

    try {
      final file = File(_currentLogFile!);
      if (file.existsSync()) {
        final size = file.lengthSync();
        if (size > _maxLogFileSize) {
          // 关闭当前文件输出
          _fileOutput?.destroy();
          _fileOutput = null;

          // 创建新的日志文件
          final now = DateTime.now();
          final timestamp =
              '${now.year}${_pad(now.month)}${_pad(now.day)}_'
              '${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';

          final prefix = _isTestEnvironment ? 'test' : 'app';
          final fileName = '${prefix}_$timestamp.log';
          _currentLogFile = path.join(_logDirectory!, fileName);

          _fileOutput = FileOutput(file: File(_currentLogFile!));
          _fileOutput!.init();

          // 更新 logger 的输出 - 同时输出到控制台和文件
          _logger = _buildLogger();
        }
      }
    } catch (e) {
      // 忽略轮转错误
    }
  }

  /// 确保 Logger 已初始化
  static void _ensureInitialized() {
    if (!_initialized) {
      // 未初始化时使用简洁格式，与初始化后保持一致
      _logger ??= Logger(
        filter: ProductionFilter(),
        printer: SimplePrinter(printTime: true),
        level: _minimumLevel,
        output: ConsoleOutput(),
      );
    }
  }

  static bool _shouldCheckRotateNow() {
    final now = DateTime.now();
    _logsSinceRotateCheck++;

    final countDue = _logsSinceRotateCheck >= _rotateCheckLogInterval;
    final timeDue =
        _lastRotateCheckAt == null ||
        now.difference(_lastRotateCheckAt!) >= _rotateCheckTimeInterval;

    if (!countDue && !timeDue) return false;

    _logsSinceRotateCheck = 0;
    _lastRotateCheckAt = now;
    return true;
  }

  static void _resetRotateCheckState() {
    _logsSinceRotateCheck = 0;
    _lastRotateCheckAt = null;
  }

  static String _resolveMessage(Object message) {
    if (message is String Function()) {
      return message();
    }
    return message.toString();
  }

  static String _formatMessage(Object message, String? tag) {
    final resolved = _resolveMessage(message);
    final tagPrefix = tag != null ? '[$tag] ' : '';
    return '$tagPrefix$resolved';
  }

  /// 调试日志
  static void d(Object message, [String? tag]) {
    if (!_shouldLog(Level.debug)) return;
    _checkAndRotateLogFile();
    _ensureInitialized();
    _logger!.d(_formatMessage(message, tag));
  }

  /// 信息日志
  static void i(Object message, [String? tag]) {
    if (!_shouldLog(Level.info)) return;
    _checkAndRotateLogFile();
    _ensureInitialized();
    _logger!.i(_formatMessage(message, tag));
  }

  /// 警告日志
  static void w(Object message, [String? tag]) {
    if (!_shouldLog(Level.warning)) return;
    _checkAndRotateLogFile();
    _ensureInitialized();
    _logger!.w(_formatMessage(message, tag));
  }

  /// 错误日志
  static void e(
    Object message, [
    dynamic error,
    StackTrace? stackTrace,
    String? tag,
  ]) {
    if (!_shouldLog(Level.error)) return;
    _checkAndRotateLogFile();
    _ensureInitialized();
    _logger!.e(
      _formatMessage(message, tag),
      error: error,
      stackTrace: stackTrace,
    );
    unawaited(flush());
  }

  /// Flush buffered file logs. This is intentionally explicit so normal
  /// debug/info logging stays buffered and cheap.
  static Future<void> flush() async {
    if (!_fileLoggingEnabled) return;

    try {
      await _fileOutput?.flush();
    } catch (_) {
      // Logging must never become the source of application failures.
    }
  }

  /// 网络请求日志
  static void network(
    String method,
    String url, {
    dynamic data,
    dynamic response,
    dynamic error,
  }) {
    _ensureInitialized();
    if (error != null) {
      _logger!.e('[HTTP] $method $url', error: error);
    } else if (response != null) {
      _logger!.i(
        '[HTTP] $method $url\nResponse: ${_truncate(response.toString(), 500)}',
      );
    } else {
      _logger!.d(
        '[HTTP] $method $url\nData: ${_truncate(data?.toString() ?? 'null', 500)}',
      );
    }
  }

  /// 加密相关日志（敏感数据脱敏）
  static void crypto(
    String operation, {
    String? email,
    int? keyLength,
    bool? success,
  }) {
    _ensureInitialized();
    final emailMasked = email != null ? _maskEmail(email) : null;
    final parts = <String>[
      '[Crypto] $operation',
      if (emailMasked != null) 'email: $emailMasked',
      if (keyLength != null) 'keyLength: $keyLength',
      if (success != null) 'success: $success',
    ];
    if (success == false) {
      _logger!.w(parts.join(' | '));
    } else {
      _logger!.i(parts.join(' | '));
    }
  }

  /// 认证相关日志
  static void auth(
    String action, {
    String? email,
    bool? success,
    String? error,
  }) {
    _ensureInitialized();
    final emailMasked = email != null ? _maskEmail(email) : null;
    final parts = <String>[
      '[Auth] $action',
      if (emailMasked != null) 'email: $emailMasked',
      if (success != null) 'success: $success',
      if (error != null) 'error: $error',
    ];
    if (success == false || error != null) {
      _logger!.w(parts.join(' | '));
    } else {
      _logger!.i(parts.join(' | '));
    }
  }

  /// 脱敏邮箱地址
  static String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return '***';
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) {
      return '${name[0]}***@$domain';
    }
    return '${name.substring(0, 2)}***@$domain';
  }

  /// 截断过长字符串
  static String _truncate(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}... (truncated)';
  }
}

/// 文件日志输出
///
/// 【修复】使用同步写入 + 定时刷新，避免日志截断和格式问题
class FileOutput extends LogOutput {
  final File file;
  final bool overrideExisting;
  final Encoding encoding;
  IOSink? _sink;
  bool _isDestroyed = false;

  FileOutput({
    required this.file,
    this.overrideExisting = false,
    this.encoding = utf8,
  });

  @override
  Future<void> init() async {
    // 【修复】使用 append 模式，确保不覆盖已有日志
    _sink = file.openWrite(
      mode: overrideExisting ? FileMode.writeOnly : FileMode.writeOnlyAppend,
      encoding: encoding,
    );
    _isDestroyed = false;
  }

  @override
  void output(OutputEvent event) {
    if (_sink == null || _isDestroyed) return;

    try {
      // 【修复】逐行写入，避免 join 导致的格式问题
      for (final line in event.lines) {
        _sink!.writeln(line);
      }
      // 【修复】不再每次 flush，让系统自动缓冲，提高性能
      // 在 destroy 时会强制 flush
    } catch (e) {
      // 忽略写入错误，避免日志系统本身导致崩溃
    }
  }

  /// 【新增】强制刷新到文件
  Future<void> flush() async {
    if (_sink != null && !_isDestroyed) {
      try {
        await _sink!.flush();
      } catch (e) {
        // 忽略 flush 错误
      }
    }
  }

  @override
  Future<void> destroy() async {
    _isDestroyed = true;
    try {
      await _sink?.flush();
      await _sink?.close();
    } catch (e) {
      // 忽略关闭错误
    }
    _sink = null;
  }
}
