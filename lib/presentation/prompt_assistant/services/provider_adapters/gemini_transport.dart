import 'package:dio/dio.dart';

import '../../../../data/models/prompt_assistant/prompt_assistant_models.dart';
import 'prompt_assistant_adapter.dart';

enum GeminiMethod { generateContent, streamGenerateContent }

class GeminiRequestTarget {
  const GeminiRequestTarget({required this.endpoint, required this.headers});

  final String endpoint;
  final Map<String, dynamic> headers;
}

/// generateContent 协议的端点与鉴权；请求体和响应解析由适配器统一处理。
abstract class GeminiTransport {
  const GeminiTransport();

  Future<GeminiRequestTarget> resolve({
    required Dio dio,
    required ProviderConfig provider,
    required String? credential,
    required String model,
    required GeminiMethod method,
  });

  Future<List<String>> fetchModels({
    required Dio dio,
    required ProviderConfig provider,
    required String? credential,
  });

  /// 服务端拒绝鉴权后丢弃缓存的会话凭据。
  void onUnauthorized(String? credential) {}
}

/// Google AI Studio（generativelanguage.googleapis.com）及其兼容中转。
class GoogleAiStudioTransport extends GeminiTransport {
  const GoogleAiStudioTransport();

  @override
  Future<GeminiRequestTarget> resolve({
    required Dio dio,
    required ProviderConfig provider,
    required String? credential,
    required String model,
    required GeminiMethod method,
  }) async {
    final normalizedModel = model.startsWith('models/')
        ? model
        : 'models/$model';
    return GeminiRequestTarget(
      endpoint: '${_root(provider)}/$normalizedModel:${method.name}',
      headers: _headers(credential),
    );
  }

  @override
  Future<List<String>> fetchModels({
    required Dio dio,
    required ProviderConfig provider,
    required String? credential,
  }) async {
    final response = await dio.get<dynamic>(
      '${_root(provider)}/models',
      options: Options(
        headers: _headers(credential),
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
    return extractModelNames(response.data);
  }

  Map<String, dynamic> _headers(String? apiKey) {
    return {
      'Content-Type': 'application/json',
      if (apiKey != null && apiKey.trim().isNotEmpty)
        'x-goog-api-key': apiKey.trim(),
    };
  }

  String _root(ProviderConfig provider) {
    final base = normalizedBaseUrl(provider.baseUrl);
    if (base.endsWith('/v1beta') || base.endsWith('/v1')) {
      return base;
    }
    return '$base/v1beta';
  }
}
