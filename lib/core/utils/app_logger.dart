import 'dart:convert';
import 'dart:io';
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
  static Future<void> initialize({bool isTestEnvironment = false}) async {
    if (_initialized) return;

    _isTestEnvironment = isTestEnvironment;

    // 设置日志目录
    await _setupLogDirectory();

    // 清理旧日志文件（超大小或超数量）
    await _cleanupOldLogs();

    // 创建新的日志文件
    await _createNewLogFile();

    // 初始化 Logger - 同时输出到控制台和文件
    _logger = Logger(
      filter: ProductionFilter(), // Release 模式下也能输出日志
      printer: SimplePrinter(printTime: true),
      level: Level.all,
      output: MultiOutput([
        ConsoleOutput(),  // 控制台输出
        _fileOutput!,     // 文件输出
      ]),
    );

    _initialized = true;

    i('日志系统初始化完成', 'AppLogger');
    i('日志文件: $_currentLogFile', 'AppLogger');
    i('运行环境: ${_isTestEnvironment ? "测试" : "正式"}', 'AppLogger');
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
      }).toList();

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
      }).toList();

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
    final timestamp = '${now.year}${_pad(now.month)}${_pad(now.day)}_'
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
    }).toList();

    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  /// 检查并轮转日志文件（如果超过100MB则创建新文件）
  static void _checkAndRotateLogFile() {
    if (_currentLogFile == null) return;

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
          final timestamp = '${now.year}${_pad(now.month)}${_pad(now.day)}_'
              '${_pad(now.hour)}${_pad(now.minute)}${_pad(now.second)}';

          final prefix = _isTestEnvironment ? 'test' : 'app';
          final fileName = '${prefix}_$timestamp.log';
          _currentLogFile = path.join(_logDirectory!, fileName);

          _fileOutput = FileOutput(file: File(_currentLogFile!));
          _fileOutput!.init();

          // 更新 logger 的输出 - 同时输出到控制台和文件
          _logger = Logger(
            filter: ProductionFilter(),
            printer: SimplePrinter(printTime: true),
            level: Level.all,
            output: MultiOutput([
              ConsoleOutput(),  // 控制台输出
              _fileOutput!,     // 文件输出
            ]),
          );
        }
      }
    } catch (e) {
      // 忽略轮转错误
    }
  }

  /// 确保 Logger 已初始化
  static void _ensureInitialized() {
    if (!_initialized) {
      // 未初始化时使用默认控制台输出
      _logger ??= Logger(
        printer: PrettyPrinter(
          methodCount: 0,
          errorMethodCount: 5,
          lineLength: 80,
          colors: true,
          printEmojis: true,
        ),
      );
    }
  }

  /// 调试日志
  static void d(String message, [String? tag]) {
    _checkAndRotateLogFile();
    _ensureInitialized();
    final tagPrefix = tag != null ? '[$tag] ' : '';
    _logger!.d('$tagPrefix$message');
  }

  /// 信息日志
  static void i(String message, [String? tag]) {
    _checkAndRotateLogFile();
    _ensureInitialized();
    final tagPrefix = tag != null ? '[$tag] ' : '';
    _logger!.i('$tagPrefix$message');
  }

  /// 警告日志
  static void w(String message, [String? tag]) {
    _checkAndRotateLogFile();
    _ensureInitialized();
    final tagPrefix = tag != null ? '[$tag] ' : '';
    _logger!.w('$tagPrefix$message');
  }

  /// 错误日志
  static void e(
    String message, [
    dynamic error,
    StackTrace? stackTrace,
    String? tag,
  ]) {
    _checkAndRotateLogFile();
    _ensureInitialized();
    final tagPrefix = tag != null ? '[$tag] ' : '';
    _logger!.e('$tagPrefix$message', error: error, stackTrace: stackTrace);
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
class FileOutput extends LogOutput {
  final File file;
  final bool overrideExisting;
  final Encoding encoding;
  IOSink? _sink;
  bool _isFlushing = false;

  FileOutput({
    required this.file,
    this.overrideExisting = false,
    this.encoding = utf8,
  });

  @override
  Future<void> init() async {
    _sink = file.openWrite(
      mode: overrideExisting ? FileMode.writeOnly : FileMode.writeOnlyAppend,
      encoding: encoding,
    );
  }

  @override
  void output(OutputEvent event) {
    if (_sink == null) return;
    
    try {
      _sink!.writeln(event.lines.join('\n'));
      // 避免频繁 flush 导致的竞争条件，只在非 flush 状态下执行
      if (!_isFlushing) {
        _isFlushing = true;
        _sink!.flush().whenComplete(() => _isFlushing = false);
      }
    } catch (e) {
      // 忽略写入错误，避免日志系统本身导致崩溃
    }
  }

  @override
  Future<void> destroy() async {
    try {
      await _sink?.flush();
      await _sink?.close();
    } catch (e) {
      // 忽略关闭错误
    }
    _sink = null;
  }
}
