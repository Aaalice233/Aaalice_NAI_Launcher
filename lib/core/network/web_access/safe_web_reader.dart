import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import 'web_access_models.dart';
import 'web_access_utils.dart';

typedef WebTargetValidator = Future<void> Function(Uri uri);
typedef WebAddressResolver =
    Future<List<InternetAddress>> Function(String hostname);

class SafeWebReader {
  SafeWebReader(
    this._dio, {
    WebTargetValidator? validateTarget,
    WebAddressResolver? resolveAddresses,
    bool trustProxyForHostnames = false,
  }) : _customTargetValidator = validateTarget,
       _resolveAddresses =
           resolveAddresses ?? ((hostname) => InternetAddress.lookup(hostname)),
       _trustProxyForHostnames = trustProxyForHostnames;

  static const int minContentCharacters = 500;
  static const int maxContentCharacters = 30000;
  static const int _maxResponseBytes = 2 * 1024 * 1024;
  static const int _maxRedirects = 5;
  static const Duration _timeout = Duration(seconds: 30);

  final Dio _dio;
  final WebTargetValidator? _customTargetValidator;
  final WebAddressResolver _resolveAddresses;
  final bool _trustProxyForHostnames;

  Future<WebPageContent> read(
    String rawUrl, {
    int maxCharacters = 12000,
    CancelToken? cancelToken,
  }) async {
    var uri = _parseTarget(rawUrl);
    final boundedCharacters = maxCharacters.clamp(
      minContentCharacters,
      maxContentCharacters,
    );

    for (var redirects = 0; redirects <= _maxRedirects; redirects++) {
      await _validateTarget(uri);
      try {
        final response = await _dio.getUri<ResponseBody>(
          uri,
          cancelToken: cancelToken,
          options: Options(
            headers: const {
              'Accept':
                  'text/html, text/plain, application/json, application/xml, text/xml;q=0.9',
              'User-Agent': 'Aaalice-NAI-Launcher/2 WebReader',
            },
            responseType: ResponseType.stream,
            followRedirects: false,
            sendTimeout: _timeout,
            receiveTimeout: _timeout,
            validateStatus: (_) => true,
          ),
        );
        final status = response.statusCode ?? 0;
        if (_isRedirect(status)) {
          if (redirects == _maxRedirects) {
            throw const WebAccessException(
              WebAccessErrorKind.network,
              'Web page redirected too many times.',
              backend: WebSearchBackend.localReader,
            );
          }
          final location = response.headers.value(HttpHeaders.locationHeader);
          await _discardBody(response.data);
          if (location == null || location.trim().isEmpty) {
            throw const WebAccessException(
              WebAccessErrorKind.invalidResponse,
              'Web page redirect is missing the Location header.',
              backend: WebSearchBackend.localReader,
            );
          }
          uri = uri.resolve(location);
          continue;
        }
        if (status < 200 || status >= 300) {
          await _discardBody(response.data);
          throw WebAccessException(
            WebAccessErrorKind.network,
            'Web page request failed (HTTP $status).',
            backend: WebSearchBackend.localReader,
            statusCode: status,
          );
        }

        final contentType = _contentType(response.headers);
        if (!_isReadableContentType(contentType)) {
          await _discardBody(response.data);
          throw WebAccessException(
            WebAccessErrorKind.unsupportedContent,
            'Unsupported web content type: $contentType.',
            backend: WebSearchBackend.localReader,
          );
        }
        final declaredLength = int.tryParse(
          response.headers.value(HttpHeaders.contentLengthHeader) ?? '',
        );
        if (declaredLength != null && declaredLength > _maxResponseBytes) {
          await _discardBody(response.data);
          throw const WebAccessException(
            WebAccessErrorKind.responseTooLarge,
            'Web page exceeds the 2 MiB reader limit.',
            backend: WebSearchBackend.localReader,
          );
        }

        final bytes = await _readBoundedBody(response.data, cancelToken);
        final decoded = _decodeBody(bytes, response.headers);
        final extracted = contentType.contains('html')
            ? _extractHtml(decoded)
            : (title: '', content: decoded.trim());
        if (extracted.content.isEmpty) {
          throw const WebAccessException(
            WebAccessErrorKind.invalidResponse,
            'Web page did not contain readable text.',
            backend: WebSearchBackend.localReader,
          );
        }
        final truncated = extracted.content.runes.length > boundedCharacters;
        return WebPageContent(
          url: uri.toString(),
          title: truncateWebText(extracted.title, 300),
          content: truncated
              ? truncateWebText(extracted.content, boundedCharacters)
              : extracted.content,
          contentType: contentType,
          truncated: truncated,
        );
      } on WebAccessException {
        rethrow;
      } on DioException catch (error) {
        throw mapWebDioException(
          error,
          WebSearchBackend.localReader,
          service: 'Web page',
        );
      }
    }
    throw const WebAccessException(
      WebAccessErrorKind.network,
      'Web page redirected too many times.',
      backend: WebSearchBackend.localReader,
    );
  }

  static Uri _parseTarget(String rawUrl) {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.userInfo.isNotEmpty) {
      throw const WebAccessException(
        WebAccessErrorKind.configuration,
        'web_read requires an HTTP(S) URL without embedded credentials.',
        backend: WebSearchBackend.localReader,
      );
    }
    return uri;
  }

  Future<void> _validateTarget(Uri uri) {
    final customValidator = _customTargetValidator;
    return customValidator == null
        ? _validatePublicTarget(uri)
        : customValidator(uri);
  }

  Future<void> _validatePublicTarget(Uri uri) async {
    final hostname = uri.host.toLowerCase();
    if (hostname == 'localhost' || hostname.endsWith('.localhost')) {
      throw WebAccessException(
        WebAccessErrorKind.blockedAddress,
        'Blocked internal hostname: $hostname.',
        backend: WebSearchBackend.localReader,
      );
    }
    final literalAddress = InternetAddress.tryParse(hostname);
    if (literalAddress != null) {
      if (_isBlockedAddress(literalAddress)) {
        throw WebAccessException(
          WebAccessErrorKind.blockedAddress,
          'Blocked internal address: $hostname.',
          backend: WebSearchBackend.localReader,
        );
      }
      return;
    }
    // The configured proxy resolves hostnames at the transport boundary. A
    // local lookup would inspect the proxy's synthetic DNS answer instead of
    // the address that receives the request.
    if (_trustProxyForHostnames) return;

    final addresses = <InternetAddress>[];
    try {
      addresses.addAll(await _resolveAddresses(hostname));
    } on SocketException catch (error) {
      throw WebAccessException(
        WebAccessErrorKind.network,
        'Unable to resolve $hostname: ${error.message}.',
        backend: WebSearchBackend.localReader,
      );
    }
    if (addresses.isEmpty) {
      throw WebAccessException(
        WebAccessErrorKind.network,
        'Unable to resolve $hostname.',
        backend: WebSearchBackend.localReader,
      );
    }
    for (final address in addresses) {
      if (_isBlockedAddress(address)) {
        throw WebAccessException(
          WebAccessErrorKind.blockedAddress,
          'Blocked internal address resolved for $hostname.',
          backend: WebSearchBackend.localReader,
        );
      }
    }
  }

  static bool _isBlockedAddress(InternetAddress address) {
    if (address.isLoopback || address.isLinkLocal || address.isMulticast) {
      return true;
    }
    final bytes = address.rawAddress;
    if (address.type == InternetAddressType.IPv4) {
      return _isBlockedIpv4(bytes);
    }
    if (bytes.length != 16) return true;
    if (bytes.every((byte) => byte == 0)) return true;
    if ((bytes[0] & 0xfe) == 0xfc ||
        (bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80) ||
        bytes[0] == 0xff) {
      return true;
    }
    final ipv4Mapped =
        bytes.take(10).every((byte) => byte == 0) &&
        bytes[10] == 0xff &&
        bytes[11] == 0xff;
    return ipv4Mapped && _isBlockedIpv4(Uint8List.fromList(bytes.sublist(12)));
  }

  static bool _isBlockedIpv4(Uint8List bytes) {
    if (bytes.length != 4) return true;
    final a = bytes[0];
    final b = bytes[1];
    if (a == 0 || a == 10 || a == 127 || a >= 224) return true;
    if (a == 100 && b >= 64 && b <= 127) return true;
    if (a == 169 && b == 254) return true;
    if (a == 172 && b >= 16 && b <= 31) return true;
    final c = bytes[2];
    if (a == 192 && b == 168) return true;
    if (a == 192 && b == 0 && (c == 0 || c == 2)) return true;
    if (a == 192 && b == 88 && c == 99) return true;
    if (a == 198 && (b == 18 || b == 19)) return true;
    if (a == 198 && b == 51 && c == 100) return true;
    if (a == 203 && b == 0 && c == 113) return true;
    return false;
  }

  static Future<Uint8List> _readBoundedBody(
    ResponseBody? body,
    CancelToken? cancelToken,
  ) async {
    if (body == null) {
      throw const WebAccessException(
        WebAccessErrorKind.invalidResponse,
        'Web page returned an empty response body.',
        backend: WebSearchBackend.localReader,
      );
    }
    final builder = BytesBuilder(copy: false);
    var length = 0;
    await for (final chunk in body.stream) {
      if (cancelToken?.isCancelled == true) {
        throw const WebAccessException(
          WebAccessErrorKind.aborted,
          'Web request was cancelled.',
          backend: WebSearchBackend.localReader,
        );
      }
      length += chunk.length;
      if (length > _maxResponseBytes) {
        throw const WebAccessException(
          WebAccessErrorKind.responseTooLarge,
          'Web page exceeds the 2 MiB reader limit.',
          backend: WebSearchBackend.localReader,
        );
      }
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  static Future<void> _discardBody(ResponseBody? body) async {
    if (body == null) return;
    final subscription = body.stream.listen((_) {});
    await subscription.cancel();
  }

  static String _decodeBody(Uint8List bytes, Headers headers) {
    final contentType = headers.value(HttpHeaders.contentTypeHeader) ?? '';
    final charset = RegExp(
      r'''charset\s*=\s*["']?([^;"'\s]+)''',
      caseSensitive: false,
    ).firstMatch(contentType)?.group(1)?.toLowerCase();
    if (charset == 'iso-8859-1' || charset == 'latin1') {
      return latin1.decode(bytes, allowInvalid: true);
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  static ({String title, String content}) _extractHtml(String source) {
    final document = html_parser.parse(source);
    for (final selector in const [
      'script',
      'style',
      'noscript',
      'svg',
      'form',
      'nav',
      'footer',
      'header',
      'aside',
    ]) {
      for (final element in document.querySelectorAll(selector)) {
        element.remove();
      }
    }
    final root =
        document.querySelector('article') ??
        document.querySelector('main') ??
        document.body ??
        document.documentElement;
    if (root == null) return (title: '', content: '');

    final blocks = <String>[];
    String? previous;
    for (final element in root.querySelectorAll(
      'h1, h2, h3, h4, p, li, blockquote, pre, td, th',
    )) {
      final text = _elementText(element);
      if (text.isEmpty || text == previous) continue;
      blocks.add(text);
      previous = text;
    }
    var content = blocks.join('\n\n').trim();
    if (content.runes.length < 200) content = _elementText(root);
    return (
      title: normalizeWebText(document.querySelector('title')?.text),
      content: content,
    );
  }

  static String _elementText(Element element) => element.text
      .replaceAll(RegExp(r'[\t\x0B\f\r ]+'), ' ')
      .replaceAll(RegExp(r'\n\s*\n+'), '\n\n')
      .trim();

  static bool _isRedirect(int status) =>
      status == 301 ||
      status == 302 ||
      status == 303 ||
      status == 307 ||
      status == 308;

  static String _contentType(Headers headers) =>
      (headers.value(HttpHeaders.contentTypeHeader) ?? 'text/plain')
          .split(';')
          .first
          .trim()
          .toLowerCase();

  static bool _isReadableContentType(String value) =>
      value.startsWith('text/') ||
      value == 'application/json' ||
      value == 'application/xml' ||
      value == 'application/xhtml+xml';
}
