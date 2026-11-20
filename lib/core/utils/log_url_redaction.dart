// 查询串和认证信息可能包含用户输入或签名，日志只保留网址定位信息。
String redactUriForLog(Uri uri) {
  return Uri(
    scheme: uri.hasScheme ? uri.scheme : null,
    host: uri.hasAuthority ? uri.host : null,
    port: uri.hasPort ? uri.port : null,
    path: uri.path,
  ).toString();
}

final _absoluteLogUrl = RegExp(
  r'''([A-Za-z][A-Za-z0-9+.-]*://)([^/\s"<>`?#]*)([^\s"<>`?#]*)([?#](?:= \[REDACTED\]|[^\s"<>`])*)?''',
);

String redactUrlsInLogText(String text) {
  if (!text.contains('://')) return text;

  return text.replaceAllMapped(_absoluteLogUrl, (match) {
    final authority = match.group(2)!;
    final hostAndPort = authority.substring(authority.lastIndexOf('@') + 1);
    final tail = match.group(4);
    var punctuation = '';
    if (tail != null) {
      const legacyValue = '= [REDACTED]';
      final legacyStart = tail.lastIndexOf(legacyValue);
      final legacyEnd = legacyStart < 0 ? 0 : legacyStart + legacyValue.length;
      var start = tail.length;
      while (start > legacyEnd && ",.;:!)]}'".contains(tail[start - 1])) {
        start--;
      }
      punctuation = tail.substring(start);
    }
    return '${match.group(1)}$hostAndPort${match.group(3)}$punctuation';
  });
}
