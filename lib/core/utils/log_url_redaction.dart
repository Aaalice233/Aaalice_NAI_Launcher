// 查询串和认证信息可能包含用户输入或签名，日志只保留网址定位信息。
String redactUriForLog(Uri uri) {
  return Uri(
    scheme: uri.hasScheme ? uri.scheme : null,
    host: uri.hasAuthority ? uri.host : null,
    port: uri.hasPort ? uri.port : null,
    path: uri.path,
  ).toString();
}

const _scheme = r'[A-Za-z][A-Za-z0-9+.-]*';
final _proxyUrlScheme = RegExp('^$_scheme://');

String formatProxyAddressForLog(String address) {
  final uri = Uri.tryParse(
    '//${address.trim().replaceFirst(_proxyUrlScheme, '')}',
  );
  if (uri == null || uri.host.isEmpty) return '[invalid proxy address]';
  return uri.replace(userInfo: '').authority;
}

const _urlDelimiters =
    r'''\s"<>`‘’“”\u3000-\u303F'''
    r'\uFF01-\uFF0F\uFF1A-\uFF20\uFF3B-\uFF40\uFF5B-\uFF65';
// 紧随查询赋值符的 URL 是查询值。
const _nextUrl =
    r'(?:(?<![?=&#])(?:https?|wss?)|(?<=[,;])'
    '$_scheme)://';
const _joinedField = r"""[')](?=[A-Za-z_][\w-]*[:=])""";
final _legacyQueryValue = RegExp(r'= \[REDACTED\]', caseSensitive: false);

final _absoluteLogUrl = RegExp(
  '($_scheme://)'
  '((?:(?!$_nextUrl)[^/$_urlDelimiters?#])*)'
  '((?:(?!$_nextUrl)[^$_urlDelimiters?#])*)'
  '([?#](?:${_legacyQueryValue.pattern}'
  r'|(?<=[=#])\p{Script=Han}+'
  '|(?!$_nextUrl|$_joinedField)[^$_urlDelimiters\\p{Script=Han}])*)?',
  caseSensitive: false,
  unicode: true,
);

String redactUrlsInLogText(String text) {
  if (!text.contains('://')) return text;

  return text.replaceAllMapped(_absoluteLogUrl, (match) {
    final authority = match.group(2)!;
    final hostAndPort = authority.substring(authority.lastIndexOf('@') + 1);
    final tail = match.group(4);
    var punctuation = '';
    if (tail != null) {
      final legacyEnd = _legacyQueryValue.allMatches(tail).lastOrNull?.end ?? 0;
      var start = tail.length;
      while (start > legacyEnd && ",.;:!)]}'".contains(tail[start - 1])) {
        start--;
      }
      punctuation = tail.substring(start);
    }
    return '${match.group(1)}$hostAndPort${match.group(3)}$punctuation';
  });
}
