import 'package:dio/dio.dart';

import '../../../../../data/models/prompt_assistant/prompt_assistant_models.dart';
import '../../../../../data/models/prompt_assistant/vertex_target.dart';
import '../gemini_transport.dart';
import '../prompt_assistant_adapter.dart';
import 'vertex_access_tokens.dart';
import 'vertex_credential.dart';

const _publisherModelPrefix = 'publishers/google/models/';

/// Vertex AI 上的 Gemini：OAuth 凭据走项目/区域路径，API Key 走 express 路径。
class VertexGeminiTransport extends GeminiTransport {
  const VertexGeminiTransport(this._tokens);

  /// 模型列表按页拉取，防止异常分页令牌造成无限循环。
  static const _maxModelPages = 20;

  final VertexAccessTokens _tokens;

  @override
  Future<GeminiRequestTarget> resolve({
    required Dio dio,
    required ProviderConfig provider,
    required String? credential,
    required String model,
    required GeminiMethod method,
  }) async {
    final parsed = VertexCredential.parse(credential ?? '');
    final modelPath = '$_publisherModelPrefix${vertexModelId(model)}';
    final root = vertexApiRoot(provider, parsed, version: 'v1');
    final path = switch (parsed) {
      VertexApiKeyCredential() => modelPath,
      VertexOAuthCredential() =>
        '${_projectLocationPath(provider, parsed)}/$modelPath',
    };
    return GeminiRequestTarget(
      endpoint: '$root/$path:${method.name}',
      headers: await _headers(dio, parsed),
    );
  }

  @override
  Future<List<String>> fetchModels({
    required Dio dio,
    required ProviderConfig provider,
    required String? credential,
  }) async {
    final parsed = VertexCredential.parse(credential ?? '');
    final endpoint =
        '${vertexApiRoot(provider, parsed, version: 'v1beta1')}/'
        'publishers/google/models';
    // 列表接口不需要项目，但生成需要；提前校验，免得连接检查通过而生成失败。
    if (parsed is VertexOAuthCredential) {
      _projectLocationPath(provider, parsed);
    }
    final headers = await _headers(dio, parsed);
    final models = <String>{};
    String? pageToken;
    for (var page = 0; page < _maxModelPages; page++) {
      final response = await dio.get<dynamic>(
        endpoint,
        queryParameters: {
          'pageSize': 200,
          if (pageToken != null) 'pageToken': pageToken,
        },
        options: Options(
          headers: headers,
          sendTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      final data = response.data;
      if (data is! Map) break;
      models.addAll(vertexGenerativeModelIds(data['publisherModels']));
      final next = data['nextPageToken'];
      if (next is! String || next.isEmpty) break;
      pageToken = next;
    }
    return models.toList()..sort();
  }

  @override
  void onUnauthorized(String? credential) {
    try {
      if (VertexCredential.parse(credential ?? '')
          case final VertexOAuthCredential oauth) {
        _tokens.invalidate(oauth);
      }
    } on VertexCredentialFormatException {
      return;
    }
  }

  Future<Map<String, dynamic>> _headers(
    Dio dio,
    VertexCredential credential,
  ) async {
    return {
      'Content-Type': 'application/json',
      ...switch (credential) {
        VertexApiKeyCredential(:final apiKey) => {'x-goog-api-key': apiKey},
        VertexOAuthCredential() => {
          'Authorization':
              'Bearer ${await _tokens.accessToken(dio, credential)}',
          // 与 google-auth 一致：只有用户凭据声明了配额项目才带。
          if (credential case VertexAuthorizedUserCredential(
            :final quotaProjectId?,
          ))
            'x-goog-user-project': quotaProjectId,
        },
      },
    };
  }

  String _projectLocationPath(
    ProviderConfig provider,
    VertexOAuthCredential credential,
  ) => 'projects/${_projectId(provider, credential)}/'
      'locations/${_location(provider)}';

  String _projectId(ProviderConfig provider, VertexCredential credential) {
    final configured = provider.vertexTarget.projectId.trim();
    final projectId = configured.isNotEmpty
        ? configured
        : credential.projectId;
    if (projectId == null || projectId.isEmpty) {
      throw const VertexConfigurationException(
        'Project ID is not configured and the credential has none',
      );
    }
    return Uri.encodeComponent(projectId);
  }
}

String _location(ProviderConfig provider) {
  final location = provider.vertexTarget.effectiveLocation;
  if (!VertexTarget.isValidLocation(location)) {
    throw VertexConfigurationException('Invalid location "$location"');
  }
  return location;
}

/// 自定义 Base URL 只替换主机部分，末尾的 API 版本按请求重新拼接。
String vertexApiRoot(
  ProviderConfig provider,
  VertexCredential credential, {
  required String version,
}) {
  final custom = normalizedBaseUrl(
    provider.baseUrl,
  ).replaceFirst(RegExp(r'/v\d+(beta\d*)?$'), '');
  if (custom.isNotEmpty) return '$custom/$version';
  final location = credential is VertexApiKeyCredential
      ? VertexTarget.defaultLocation
      : _location(provider);
  final domain = credential.universeDomain;
  final host = switch (location) {
    VertexTarget.defaultLocation => 'aiplatform.$domain',
    'us' || 'eu' => 'aiplatform.$location.rep.$domain',
    _ => '$location-aiplatform.$domain',
  };
  return 'https://$host/$version';
}

String vertexModelId(String model) {
  final trimmed = model.trim();
  if (trimmed.startsWith(_publisherModelPrefix)) {
    return trimmed.substring(_publisherModelPrefix.length);
  }
  if (trimmed.startsWith('models/')) {
    return trimmed.substring('models/'.length);
  }
  return trimmed;
}

Iterable<String> vertexGenerativeModelIds(Object? publisherModels) sync* {
  if (publisherModels is! List) return;
  for (final model in publisherModels) {
    if (model is! Map) continue;
    final name = model['name'];
    if (name is! String) continue;
    final id = vertexModelId(name);
    if (isVertexChatModel(id)) yield id;
  }
}

/// 按连字符分段匹配，避免关键词误伤更长的单词。
const _nonChatModelSegments = {
  'embedding',
  'tts',
  'image',
  'transcribe',
  'live',
  'audio',
};

/// 发布方模型列表没有“支持的方法”字段，只能按模型 ID 判断能否用于文本对话；
/// 误滤的新模型仍可在模型管理里手动添加。
bool isVertexChatModel(String id) {
  if (!id.startsWith('gemini-')) return false;
  // 图像生成模型的产品名不带 image 段。
  if (id.startsWith('gemini-nano-banana')) return false;
  return !id.split('-').any(_nonChatModelSegments.contains);
}

class VertexConfigurationException implements Exception {
  const VertexConfigurationException(this.message);

  final String message;

  @override
  String toString() => 'Vertex AI configuration error: $message';
}
