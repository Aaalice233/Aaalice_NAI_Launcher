import 'package:dio/dio.dart';

import 'chrome_identity.dart';
import 'request_correlation.dart';

/// 关闭追踪头的 `Options.extra` 标记。
const String kOmitTrackingHeadersExtra = 'naiOmitTrackingHeaders';

/// 供调用方声明该请求不带 `x-correlation-id` / `x-initiated-at`。
Map<String, dynamic> omitTrackingHeadersExtra() => const {
  kOmitTrackingHeadersExtra: true,
};

/// 把 NovelAI 官网前端在浏览器里自动获得的请求头补齐到 Dio 请求上。
class BrowserHeadersInterceptor extends Interceptor {
  BrowserHeadersInterceptor({
    required this.identity,
    required this.resolveAcceptLanguage,
  });

  final ChromeIdentity identity;
  final String Function() resolveAcceptLanguage;

  static const String _origin = 'https://novelai.net';
  static const String _referer = 'https://novelai.net/';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final headers = options.headers;

    // 调用方显式声明的 Accept 表示要求特定响应格式，浏览器默认值不能盖掉它。
    headers.putIfAbsent('accept', () => '*/*');
    headers['accept-language'] = resolveAcceptLanguage();
    headers['sec-ch-ua'] = identity.secChUa;
    headers['sec-ch-ua-mobile'] = identity.secChUaMobile;
    headers['sec-ch-ua-platform'] = identity.secChUaPlatform;
    headers['sec-fetch-dest'] = 'empty';
    headers['sec-fetch-mode'] = 'cors';
    headers['sec-fetch-site'] = 'same-site';
    headers['origin'] = _origin;
    headers['referer'] = _referer;
    headers['user-agent'] = identity.userAgent;

    if (options.extra[kOmitTrackingHeadersExtra] == true) {
      handler.next(options);
      return;
    }

    headers.putIfAbsent(
      'x-correlation-id',
      RequestCorrelation.newCorrelationId,
    );
    headers.putIfAbsent('x-initiated-at', RequestCorrelation.nowInitiatedAt);

    handler.next(options);
  }
}
