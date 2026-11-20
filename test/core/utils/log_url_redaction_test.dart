import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/core/utils/log_url_redaction.dart';

void main() {
  group('redactUriForLog', () {
    test('removes the complete Discord signature without an empty query', () {
      final uri = Uri.parse(
        'https://cdn.discordapp.com/attachments/111/222/image.png'
        '?ex=6a1b2c3d&is=6a1a0000&hm=0123456789abcdef&',
      );

      expect(
        redactUriForLog(uri),
        'https://cdn.discordapp.com/attachments/111/222/image.png',
      );
    });

    test('removes userInfo, query and fragment but keeps the port', () {
      final uri = Uri.parse(
        'http://user:secret@example.com:8080/a/b?token=t#frag',
      );

      expect(redactUriForLog(uri), 'http://example.com:8080/a/b');
    });

    test('keeps only the path for a relative URI', () {
      expect(
        redactUriForLog(Uri.parse('/posts.json?tags=secret')),
        '/posts.json',
      );
    });

    test('preserves a percent-encoded path', () {
      const target = 'https://example.com/%E4%B8%AD%E6%96%87/a%20b.png';

      expect(redactUriForLog(Uri.parse('$target?key=secret#frag')), target);
    });

    test('does not change a URI without private components', () {
      final uri = Uri.parse('https://example.com/a/b');

      expect(redactUriForLog(uri), uri.toString());
    });

    test('removes WebSocket client identifiers', () {
      expect(
        redactUriForLog(Uri.parse('ws://127.0.0.1:8188/ws?clientId=abc')),
        'ws://127.0.0.1:8188/ws',
      );
    });

    test('keeps an authority without a scheme', () {
      expect(
        redactUriForLog(Uri.parse('//user:secret@example.com:8080/a?q=b')),
        '//example.com:8080/a',
      );
    });

    test('keeps a scheme without an authority', () {
      expect(
        redactUriForLog(Uri.parse('custom:relative/path?q=secret#frag')),
        'custom:relative/path',
      );
    });
  });

  group('redactUrlsInLogText', () {
    const cases = <String, (String, String)>{
      'HttpException URI': (
        'HttpException: Connection closed before full header was received, '
            'uri = https://danbooru.donmai.us/posts.json'
            '?tags=secret+tag&login=bob&api_key=xyz',
        'HttpException: Connection closed before full header was received, '
            'uri = https://danbooru.donmai.us/posts.json',
      ),
      'multiple URLs': (
        'first=https://a.test/a?ex=1&hm=2 second=http://u:p@b.test:8080/b#frag',
        'first=https://a.test/a second=http://b.test:8080/b',
      ),
      'JSON quotes': (
        '{"url":"https://u:p@x.test/y?q=1#f","next":"https://z.test/a?x=2"}',
        '{"url":"https://x.test/y","next":"https://z.test/a"}',
      ),
      'trailing comma': (
        'https://x.test/image.png?ex=1&hm=2, error=closed',
        'https://x.test/image.png, error=closed',
      ),
      'Markdown closing parenthesis': (
        '[a](https://x.test/y?q=1)',
        '[a](https://x.test/y)',
      ),
      'all trailing punctuation': (
        "https://x.test/y?q=1,.;:!)]}'",
        "https://x.test/y,.;:!)]}'",
      ),
      'userInfo without a query': (
        'target=https://user:secret@x.test:8080/y',
        'target=https://x.test:8080/y',
      ),
      'last userInfo separator': (
        'https://user:p@ss@x.test/y?q=1',
        'https://x.test/y',
      ),
      'authority that cannot be parsed as a URI': (
        'https://user:secret@x.test:invalid/y?key=xyz',
        'https://x.test:invalid/y',
      ),
      'commas inside a query': (
        'https://x.test/y?q=a,b&token=t tail',
        'https://x.test/y tail',
      ),
      'apostrophes and parentheses inside a query': (
        "https://x.test/y?q=O'Connor(a,b)&tags=private status=429",
        'https://x.test/y status=429',
      ),
      'full-width comma after a query': (
        'https://danbooru.donmai.us/posts.json?limit=1&tags=a+b，状态码=429',
        'https://danbooru.donmai.us/posts.json，状态码=429',
      ),
      'ComfyUI node errors separated without spaces': (
        '节点 1: https://x.test/input?key=one；节点 2: https://y.test/output#two',
        '节点 1: https://x.test/input；节点 2: https://y.test/output',
      ),
      'Chinese diagnostics immediately after a fragment': (
        'https://x.test/y?tags=private#fragment状态码=429',
        'https://x.test/y状态码=429',
      ),
      'Chinese text at the start of a query value': (
        'https://x.test/y?tags=隐藏标签&login=bob status=429',
        'https://x.test/y status=429',
      ),
      'closing single quote followed by a field': (
        "url='https://x.test/y?q=1'status=429",
        "url='https://x.test/y'status=429",
      ),
      'closing parenthesis followed by a field': (
        '(https://x.test/y?key=one)status=429',
        '(https://x.test/y)status=429',
      ),
      'adjacent URLs without a separator': (
        'https://x.test/y?q=1https://u:p@z.test/a?tag=two#frag',
        'https://x.test/yhttps://z.test/a',
      ),
      'adjacent WebSocket URL after a path': (
        'https://x.test/viewwss://u:p@y.test/ws?clientId=private',
        'https://x.test/viewwss://y.test/ws',
      ),
      'semicolon between URLs': (
        'https://x.test/y?q=a;custom://z.test/a#frag',
        'https://x.test/y;custom://z.test/a',
      ),
      'redirect URL inside a query value': (
        'https://x.test/y?redirect=https://z.test/a?tag=two#frag status=429',
        'https://x.test/y status=429',
      ),
      'authority followed directly by query': (
        'https://user:secret@x.test?login=bob&key=xyz',
        'https://x.test',
      ),
      'fragment before query': (
        'https://x.test/y#frag?token=t',
        'https://x.test/y',
      ),
      'URL delimiters': (
        '<https://x.test/y?q=1> `ws://x.test/ws?clientId=abc`\n'
            '"https://x.test/z#frag"',
        '<https://x.test/y> `ws://x.test/ws`\n"https://x.test/z"',
      ),
      'custom scheme and empty authority': (
        'Test+v1.2-3://u:p@host/a?key=x file:///path?q=secret',
        'Test+v1.2-3://host/a file:///path',
      ),
      'encoded path and path punctuation': (
        'https://x.test/%E4%B8%AD%E6%96%87/a%20b,)]@y?q=x',
        'https://x.test/%E4%B8%AD%E6%96%87/a%20b,)]@y',
      ),
      'URL with no private components': (
        'target=https://x.test/a/b',
        'target=https://x.test/a/b',
      ),
      'text without a URL': (
        'plain text /posts.json?tags=secret user:pass@host:8080',
        'plain text /posts.json?tags=secret user:pass@host:8080',
      ),
    };

    for (final entry in cases.entries) {
      test('${entry.key} is redacted and idempotent', () {
        final (input, expected) = entry.value;
        final result = redactUrlsInLogText(input);

        expect(result, expected);
        expect(redactUrlsInLogText(result), result);
      });
    }
  });
}
