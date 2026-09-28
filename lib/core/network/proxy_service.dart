import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../utils/app_logger.dart';
import 'windows_proxy_helper.dart';

/// 代理测试结果
class ProxyTestResult {
  final bool success;
  final String? errorMessage;
  final int? latencyMs;

  const ProxyTestResult({
    required this.success,
    this.errorMessage,
    this.latencyMs,
  });

  factory ProxyTestResult.success(int latencyMs) =>
      ProxyTestResult(success: true, latencyMs: latencyMs);

  factory ProxyTestResult.failure(String error) =>
      ProxyTestResult(success: false, errorMessage: error);
}

/// 跨平台代理服务
///
/// 负责：
/// - 读取系统代理配置（Windows/macOS/Linux）
/// - 提供统一的代理配置接口
/// - 测试代理连接
class ProxyService {
  ProxyService._();

  /// 获取系统代理地址
  ///
  /// 返回格式: "host:port" 或 null（未检测到代理）
  static String? getSystemProxyAddress() {
    try {
      if (Platform.isWindows) {
        return _getWindowsProxy();
      } else if (Platform.isMacOS) {
        return _getMacOSProxy();
      } else if (Platform.isLinux) {
        return _getLinuxProxy();
      }
      return null;
    } catch (e, stackTrace) {
      AppLogger.e('Failed to get system proxy: $e', 'PROXY', stackTrace);
      return null;
    }
  }

  /// Windows: 通过注册表读取代理
  static String? _getWindowsProxy() {
    final proxyString = WindowsProxyHelper.getSystemProxy();
    if (proxyString == null || proxyString == 'DIRECT') {
      return null;
    }
    // WindowsProxyHelper 返回 "PROXY host:port"，需要提取 host:port
    if (proxyString.startsWith('PROXY ')) {
      return proxyString.substring(6);
    }
    return proxyString;
  }

  /// macOS: 通过 scutil 命令读取代理
  static String? _getMacOSProxy() {
    try {
      final result = Process.runSync('scutil', ['--proxy']);
      if (result.exitCode != 0) {
        AppLogger.w('scutil --proxy failed: ${result.stderr}', 'PROXY');
        return null;
      }

      final output = result.stdout as String;

      // 检查是否启用了 HTTP 代理
      final httpEnableMatch = RegExp(
        r'HTTPEnable\s*:\s*(\d)',
      ).firstMatch(output);
      if (httpEnableMatch == null || httpEnableMatch.group(1) != '1') {
        AppLogger.d('macOS HTTP proxy not enabled', 'PROXY');
        return null;
      }

      // 提取代理主机和端口
      final httpProxyMatch = RegExp(
        r'HTTPProxy\s*:\s*(\S+)',
      ).firstMatch(output);
      final httpPortMatch = RegExp(r'HTTPPort\s*:\s*(\d+)').firstMatch(output);

      if (httpProxyMatch != null && httpPortMatch != null) {
        final host = httpProxyMatch.group(1);
        final port = httpPortMatch.group(1);
        AppLogger.d('macOS proxy detected: $host:$port', 'PROXY');
        return '$host:$port';
      }

      return null;
    } catch (e) {
      AppLogger.w('Failed to read macOS proxy: $e', 'PROXY');
      return null;
    }
  }

  /// Linux: 通过环境变量读取代理
  static String? _getLinuxProxy() {
    // 尝试多个常见的环境变量
    final proxyUrl =
        Platform.environment['http_proxy'] ??
        Platform.environment['HTTP_PROXY'] ??
        Platform.environment['https_proxy'] ??
        Platform.environment['HTTPS_PROXY'];

    if (proxyUrl == null || proxyUrl.isEmpty) {
      AppLogger.d('Linux proxy environment variable not set', 'PROXY');
      return null;
    }

    // 解析 URL 格式: http://host:port 或 host:port
    try {
      String hostPort = proxyUrl;

      // 移除协议前缀
      if (hostPort.startsWith('http://')) {
        hostPort = hostPort.substring(7);
      } else if (hostPort.startsWith('https://')) {
        hostPort = hostPort.substring(8);
      }

      // 移除尾部斜杠
      if (hostPort.endsWith('/')) {
        hostPort = hostPort.substring(0, hostPort.length - 1);
      }

      // 移除认证信息 (user:pass@host:port -> host:port)
      if (hostPort.contains('@')) {
        hostPort = hostPort.split('@').last;
      }

      AppLogger.d('Linux proxy detected: $hostPort', 'PROXY');
      return hostPort;
    } catch (e) {
      AppLogger.w('Failed to parse Linux proxy URL: $proxyUrl', 'PROXY');
      return null;
    }
  }

  /// 创建测试用的 Dio 实例
  static Dio _createTestDio({String? proxyAddress, Duration? timeout}) {
    final dio = Dio(
      BaseOptions(
        connectTimeout: timeout ?? const Duration(seconds: 10),
        receiveTimeout: timeout ?? const Duration(seconds: 10),
        followRedirects: true,
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    if (proxyAddress != null && proxyAddress.isNotEmpty) {
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.findProxy = (uri) => 'PROXY $proxyAddress';
          client.badCertificateCallback = (cert, host, port) => true;
          return client;
        },
      );
    }

    return dio;
  }

  static String _getErrorMessage(DioException e) {
    return switch (e.type) {
      DioExceptionType.connectionTimeout => '连接超时',
      DioExceptionType.connectionError => '无法连接到服务器',
      _ => e.message ?? '连接失败',
    };
  }

  /// 测试代理连接
  static Future<ProxyTestResult> testProxyConnection(
    String proxyAddress,
  ) async {
    final stopwatch = Stopwatch()..start();
    final dio = _createTestDio(proxyAddress: proxyAddress);

    try {
      final testUrls = [
        'https://www.google.com/generate_204',
        'https://www.gstatic.com/generate_204',
        'https://api.github.com',
      ];

      for (final url in testUrls) {
        try {
          final response = await dio.get(url);
          if (response.statusCode == 200 || response.statusCode == 204) {
            return ProxyTestResult.success(stopwatch.elapsedMilliseconds);
          }
        } catch (e) {
          AppLogger.d('Proxy test URL failed ($url): $e', 'ProxyService');
        }
      }
      return ProxyTestResult.failure('无法连接到测试服务器');
    } on DioException catch (e) {
      return ProxyTestResult.failure(_getErrorMessage(e));
    } catch (e) {
      return ProxyTestResult.failure('测试失败: $e');
    } finally {
      dio.close();
    }
  }

  /// 测试 NovelAI 连接
  static Future<ProxyTestResult> testNovelAIConnection({
    String? proxyAddress,
    Duration? timeout,
  }) async {
    final stopwatch = Stopwatch()..start();
    final dio = _createTestDio(
      proxyAddress: proxyAddress,
      timeout: timeout ?? const Duration(seconds: 5),
    );

    try {
      final response = await dio.get('https://novelai.net');
      if (response.statusCode == 200 ||
          response.statusCode == 307 ||
          response.statusCode == 302) {
        return ProxyTestResult.success(stopwatch.elapsedMilliseconds);
      }
      return ProxyTestResult.failure('HTTP ${response.statusCode}');
    } on DioException catch (e) {
      return ProxyTestResult.failure(_getErrorMessage(e));
    } catch (e) {
      return ProxyTestResult.failure('测试失败: $e');
    } finally {
      dio.close();
    }
  }
}
