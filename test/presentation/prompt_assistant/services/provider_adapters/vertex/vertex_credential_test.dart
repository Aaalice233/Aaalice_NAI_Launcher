import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/vertex/vertex_credential.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/vertex/vertex_credential_check.dart';
import 'package:nai_launcher/presentation/prompt_assistant/services/provider_adapters/vertex/vertex_jwt_assertion.dart';

import 'vertex_test_support.dart';

Matcher _formatError(String fragment) => throwsA(
  isA<VertexCredentialFormatException>().having(
    (e) => e.message,
    'message',
    contains(fragment),
  ),
);

void main() {
  group('VertexCredential.parse', () {
    test('非 JSON 文本按 Vertex API Key 处理', () {
      final credential = VertexCredential.parse('  AQ.vertex-key  ');
      expect(credential, isA<VertexApiKeyCredential>());
      expect((credential as VertexApiKeyCredential).apiKey, 'AQ.vertex-key');
      expect(credential.projectId, isNull);
    });

    test('服务账号 JSON 读出项目、令牌端点与 universe', () {
      final credential = VertexCredential.parse(serviceAccountJson());
      expect(credential, isA<VertexServiceAccountCredential>());
      final sa = credential as VertexServiceAccountCredential;
      expect(sa.projectId, 'sa-project');
      expect(sa.clientEmail, 'tester@sa-project.iam.gserviceaccount.com');
      expect(sa.privateKeyId, 'test-key-id');
      expect(sa.tokenUri, Uri.parse('https://oauth2.googleapis.com/token'));
      expect(sa.universeDomain, 'googleapis.com');
    });

    test('gcloud ADC 用户凭据以配额项目作为默认项目', () {
      final credential = VertexCredential.parse(authorizedUserJson());
      expect(credential, isA<VertexAuthorizedUserCredential>());
      expect(credential.projectId, 'quota-project');
      expect(
        (credential as VertexAuthorizedUserCredential).tokenUri,
        Uri.parse('https://oauth2.googleapis.com/token'),
      );
    });

    test('gcloud 用户凭据忽略文件里的刷新端点', () {
      final json = jsonDecode(authorizedUserJson()) as Map<String, dynamic>
        ..['universe_domain'] = 'example-cloud.eu'
        ..['token_uri'] = 'https://oauth2.example-cloud.eu/token';
      final credential = VertexCredential.parse(jsonEncode(json))
          as VertexAuthorizedUserCredential;

      expect(
        credential.tokenUri,
        Uri.parse('https://oauth2.googleapis.com/token'),
      );
    });

    test('缓存键随凭据变化且不含明文密钥', () {
      final a = VertexCredential.parse(serviceAccountJson())
          as VertexOAuthCredential;
      final b = VertexCredential.parse(authorizedUserJson())
          as VertexOAuthCredential;
      expect(a.cacheKey, isNot(b.cacheKey));
      expect(b.cacheKey, isNot(contains('refresh-token-value')));
      expect(
        (VertexCredential.parse(serviceAccountJson()) as VertexOAuthCredential)
            .cacheKey,
        a.cacheKey,
      );
    });

    test('拒绝空值、损坏 JSON、未知类型与缺字段', () {
      expect(() => VertexCredential.parse('  '), _formatError('not configured'));
      expect(() => VertexCredential.parse('{oops'), _formatError('malformed'));
      expect(() => VertexCredential.parse('[]'), _formatError('object'));
      expect(
        () => VertexCredential.parse('{"type":"external_account"}'),
        _formatError('external_account'),
      );
      expect(
        () => VertexCredential.parse('key with space'),
        _formatError('whitespace'),
      );
      expect(
        () => VertexCredential.parse('密钥'),
        _formatError('unsupported characters'),
      );
      final missing = jsonDecode(serviceAccountJson()) as Map<String, dynamic>
        ..remove('client_email');
      expect(
        () => VertexCredential.parse(jsonEncode(missing)),
        _formatError('client_email'),
      );
    });

    test('令牌端点必须是凭据 universe 下的 HTTPS 地址', () {
      expect(
        () => VertexCredential.parse(
          serviceAccountJson(tokenUri: 'http://oauth2.googleapis.com/token'),
        ),
        _formatError('token_uri'),
      );
      expect(
        () => VertexCredential.parse(
          serviceAccountJson(tokenUri: 'https://evil.example/token'),
        ),
        _formatError('token_uri'),
      );
      final sovereign = VertexCredential.parse(
        serviceAccountJson(
          tokenUri: 'https://oauth2.example-cloud.eu/token',
          universeDomain: 'example-cloud.eu',
        ),
      );
      expect(sovereign.universeDomain, 'example-cloud.eu');
    });

    test('错误信息不回显凭据内容', () {
      try {
        checkVertexCredential(
          serviceAccountJson(privateKey: 'not-a-key-secret-material'),
        );
        fail('expected format error');
      } on VertexCredentialFormatException catch (error) {
        expect(error.toString(), isNot(contains('secret-material')));
      }
    });
  });

  group('RS256 断言', () {
    test('PKCS#8 私钥签出的 JWT 可用公钥验证，声明符合 RFC 7523', () {
      final credential =
          VertexCredential.parse(serviceAccountJson())
              as VertexServiceAccountCredential;
      final issuedAt = DateTime.utc(2026, 11, 23, 8);
      final jwt = VertexJwtAssertionSigner(
        credential,
      ).sign(issuedAt: issuedAt, scope: 'https://scope.test');

      expect(verifyRs256(jwt), isTrue);
      expect(decodeJwtPart(jwt, 0), {
        'alg': 'RS256',
        'typ': 'JWT',
        'kid': 'test-key-id',
      });
      final iat = issuedAt.millisecondsSinceEpoch ~/ 1000;
      expect(decodeJwtPart(jwt, 1), {
        'iss': 'tester@sa-project.iam.gserviceaccount.com',
        'scope': 'https://scope.test',
        'aud': 'https://oauth2.googleapis.com/token',
        'iat': iat,
        'exp': iat + 3600,
      });
      expect(jwt, isNot(contains('=')));
    });

    test('兼容 PKCS#1 与转义成字面 \\n 的 PEM', () {
      final pkcs1 = parseRsaPrivateKeyPem(testPkcs1Pem());
      expect(pkcs1.modulus, testRsaKeyPair.privateKey.modulus);
      final escaped = parseRsaPrivateKeyPem(
        testPkcs8Pem().replaceAll('\n', r'\n'),
      );
      expect(escaped.modulus, testRsaKeyPair.privateKey.modulus);
    });

    test('无效私钥在保存前的完整校验里报错', () {
      expect(
        () => checkVertexCredential(
          serviceAccountJson(privateKey: 'garbage'),
        ),
        _formatError('PEM'),
      );
      expect(
        () => checkVertexCredential(
          serviceAccountJson(
            privateKey:
                '-----BEGIN PRIVATE KEY-----\nAAAA\n-----END PRIVATE KEY-----',
          ),
        ),
        _formatError('valid RSA key'),
      );
      expect(checkVertexCredential(serviceAccountJson()), isNotNull);
    });
  });
}
