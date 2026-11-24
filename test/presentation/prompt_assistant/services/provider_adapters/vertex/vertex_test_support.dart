import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';

/// 运行时生成的固定种子测试密钥，仓库里不存放任何私钥文件。
final testRsaKeyPair = _generateKeyPair();

String testPkcs8Pem() => _pem('PRIVATE KEY', _pkcs8(testRsaKeyPair.privateKey));

String testPkcs1Pem() =>
    _pem('RSA PRIVATE KEY', _pkcs1(testRsaKeyPair.privateKey));

String serviceAccountJson({
  String? projectId = 'sa-project',
  String tokenUri = 'https://oauth2.googleapis.com/token',
  String? universeDomain,
  String? privateKey,
}) => jsonEncode({
  'type': 'service_account',
  if (projectId != null) 'project_id': projectId,
  'private_key_id': 'test-key-id',
  'private_key': privateKey ?? testPkcs8Pem(),
  'client_email': 'tester@sa-project.iam.gserviceaccount.com',
  'client_id': '1234567890',
  'token_uri': tokenUri,
  if (universeDomain != null) 'universe_domain': universeDomain,
});

String authorizedUserJson({String? quotaProjectId = 'quota-project'}) =>
    jsonEncode({
      'type': 'authorized_user',
      'client_id': 'client-id.apps.googleusercontent.com',
      'client_secret': 'client-secret-value',
      'refresh_token': 'refresh-token-value',
      if (quotaProjectId != null) 'quota_project_id': quotaProjectId,
    });

bool verifyRs256(String jwt) {
  final parts = jwt.split('.');
  final signer = RSASigner(SHA256Digest(), '0609608648016503040201')
    ..init(false, PublicKeyParameter<RSAPublicKey>(testRsaKeyPair.publicKey));
  return signer.verifySignature(
    Uint8List.fromList(utf8.encode('${parts[0]}.${parts[1]}')),
    RSASignature(base64Url.decode(base64Url.normalize(parts[2]))),
  );
}

Map<String, dynamic> decodeJwtPart(String jwt, int index) =>
    jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(jwt.split('.')[index]))),
        )
        as Map<String, dynamic>;

/// 读 [RequestOptions.data] 而非请求体流：测试环境里该流不会结束。
class RecordedRequest {
  RecordedRequest(this.options);

  final RequestOptions options;

  Uri get uri => options.uri;

  Map<String, String> get form => {
    for (final entry in (options.data as Map).entries)
      '${entry.key}': '${entry.value}',
  };

  Map<String, dynamic> get json => options.data as Map<String, dynamic>;
}

class FakeResponse {
  const FakeResponse(this.status, this.body, {this.contentType});

  FakeResponse.json(Object body, {int status = 200})
    : this(status, jsonEncode(body), contentType: 'application/json');

  const FakeResponse.sse(String body)
    : this(200, body, contentType: 'text/event-stream');

  final int status;
  final String body;
  final String? contentType;
}

/// 按请求顺序记录，并交给 [handler] 生成响应。
class FakeGoogleServer implements HttpClientAdapter {
  FakeGoogleServer(this.handler);

  final FutureOr<FakeResponse> Function(RecordedRequest request) handler;
  final requests = <RecordedRequest>[];

  Iterable<RecordedRequest> get tokenRequests =>
      requests.where((request) => request.uri.path == '/token');

  Iterable<RecordedRequest> get apiRequests =>
      requests.where((request) => request.uri.path != '/token');

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final request = RecordedRequest(options);
    requests.add(request);
    final response = await handler(request);
    return ResponseBody.fromString(
      response.body,
      response.status,
      headers: {
        Headers.contentTypeHeader: [
          response.contentType ?? 'application/json',
        ],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

FakeResponse tokenResponse({String token = 'access-1', int expiresIn = 3600}) =>
    FakeResponse.json({
      'access_token': token,
      'expires_in': expiresIn,
      'token_type': 'Bearer',
    });

AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> _generateKeyPair() {
  final random = FortunaRandom()
    ..seed(KeyParameter(Uint8List.fromList(List.generate(32, (i) => i + 1))));
  final generator = RSAKeyGenerator()
    ..init(
      ParametersWithRandom(
        RSAKeyGeneratorParameters(BigInt.from(65537), 1024, 64),
        random,
      ),
    );
  return generator.generateKeyPair();
}

Uint8List _pkcs1(RSAPrivateKey key) {
  final p = key.p!;
  final q = key.q!;
  final d = key.privateExponent!;
  return ASN1Sequence(
    elements: [
      ASN1Integer(BigInt.zero),
      ASN1Integer(key.modulus),
      ASN1Integer(key.publicExponent),
      ASN1Integer(d),
      ASN1Integer(p),
      ASN1Integer(q),
      ASN1Integer(d % (p - BigInt.one)),
      ASN1Integer(d % (q - BigInt.one)),
      ASN1Integer(q.modInverse(p)),
    ],
  ).encode();
}

Uint8List _pkcs8(RSAPrivateKey key) => ASN1Sequence(
  elements: [
    ASN1Integer(BigInt.zero),
    ASN1Sequence(
      elements: [
        ASN1ObjectIdentifier.fromIdentifierString('1.2.840.113549.1.1.1'),
        ASN1Null(),
      ],
    ),
    ASN1OctetString(octets: _pkcs1(key)),
  ],
).encode();

String _pem(String label, Uint8List der) {
  final body = base64Encode(der);
  final lines = [
    for (var i = 0; i < body.length; i += 64)
      body.substring(i, i + 64 > body.length ? body.length : i + 64),
  ];
  return '-----BEGIN $label-----\n${lines.join('\n')}\n-----END $label-----\n';
}
