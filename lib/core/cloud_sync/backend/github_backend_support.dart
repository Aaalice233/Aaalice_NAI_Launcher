import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:crypto/crypto.dart';

import 'backend_http.dart';
import 'cloud_namespace.dart';
import 'cloud_sync_backend.dart';

class GitHubBackendSupport {
  const GitHubBackendSupport._();

  static dynamic decodeJson(Response<Uint8List> response) {
    try {
      return jsonDecode(BackendHttp.rawTextOf(response));
    } on FormatException {
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        'GitHub 返回了无法解析的 JSON。',
      );
    }
  }

  static bool isRateLimited(Response<Uint8List> response) {
    final status = response.statusCode ?? 0;
    if (status == 429) return true;
    if (status != 403) return false;
    final remaining = int.tryParse(
      response.headers.value('x-ratelimit-remaining') ?? '',
    );
    if (remaining == 0 || response.headers.value('retry-after') != null) {
      return true;
    }
    final message = BackendHttp.rawTextOf(response).toLowerCase();
    return message.contains('secondary rate limit') ||
        message.contains('abuse detection');
  }

  static Never throwResponse(Response<Uint8List> response, String action) {
    final status = response.statusCode ?? 0;
    if (isRateLimited(response)) {
      final reset = int.tryParse(
        response.headers.value('x-ratelimit-reset') ?? '',
      );
      final retryAfterSeconds = int.tryParse(
        response.headers.value('retry-after') ?? '',
      );
      throw CloudBackendException(
        CloudBackendErrorKind.rateLimited,
        '$action失败：GitHub API 速率限制已用尽，请稍后重试。',
        statusCode: status,
        retryAfter: reset != null
            ? DateTime.fromMillisecondsSinceEpoch(reset * 1000, isUtc: true)
            : retryAfterSeconds == null
            ? null
            : DateTime.now().toUtc().add(
                Duration(
                  seconds: retryAfterSeconds < 0 ? 0 : retryAfterSeconds,
                ),
              ),
      );
    }
    final kind = switch (status) {
      401 => CloudBackendErrorKind.authentication,
      403 => CloudBackendErrorKind.authorization,
      404 => CloudBackendErrorKind.notFound,
      409 || 422 => CloudBackendErrorKind.conflict,
      413 => CloudBackendErrorKind.quota,
      _ => CloudBackendErrorKind.invalidResponse,
    };
    final diagnosis = switch (status) {
      401 => 'Token 无效或已过期。',
      403 => 'Token scope/细粒度权限不足，或分支保护拒绝写入；请授予 Contents 读写权限。',
      404 => '资源不存在；对于私有仓库，这也可能表示 Token 无权访问 owner/repo/branch/path。',
      409 || 422 => '远端分支或文件 SHA 已变化，禁止 force，请重新读取后合并。',
      413 => '文件超过 GitHub Contents API 容量限制。',
      _ => 'GitHub 返回了无法处理的响应。',
    };
    throw CloudBackendException(
      kind,
      '$action失败（HTTP $status）：$diagnosis',
      statusCode: status,
    );
  }

  static void validateId(String value) {
    if (!RegExp(r'^[A-Za-z0-9._-]{1,180}$').hasMatch(value) ||
        value == '.' ||
        value == '..') {
      throw const FormatException('Invalid cloud object id');
    }
  }

  static void validatePath(String value) {
    CloudNamespace.validate(value);
  }

  static String contentSha(Map<String, dynamic> response) {
    final content = response['content'];
    final value = content is Map ? content['sha'] : null;
    if (value is! String || value.isEmpty) {
      throw const CloudBackendException(
        CloudBackendErrorKind.invalidResponse,
        'GitHub 未返回文件 SHA。',
      );
    }
    return value;
  }

  static void checkContentsSize(Uint8List bytes, int limit) {
    if (bytes.length > limit) {
      throw const CloudBackendException(
        CloudBackendErrorKind.quota,
        '文件超过 GitHub Contents API 100 MiB 限制；本后端不使用 LFS 或 Releases。',
      );
    }
  }

  static bool matchesGitBlobSha(Uint8List bytes, String expected) {
    if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(expected)) return false;
    final header = utf8.encode('blob ${bytes.length}\u0000');
    return sha1.convert([...header, ...bytes]).toString() == expected;
  }
}
