import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/export.dart';

import 'vertex_credential.dart';

const _sha256DigestInfoPrefix = '0609608648016503040201';

/// 服务账号的 JWT bearer 断言（RFC 7523），用于向令牌端点换取访问令牌。
class VertexJwtAssertionSigner {
  VertexJwtAssertionSigner(this.credential)
    : _privateKey = parseRsaPrivateKeyPem(credential.privateKeyPem);

  static const lifetime = Duration(hours: 1);

  final VertexServiceAccountCredential credential;
  final RSAPrivateKey _privateKey;

  String sign({required DateTime issuedAt, required String scope}) {
    final iat = issuedAt.toUtc().millisecondsSinceEpoch ~/ 1000;
    final header = {
      'alg': 'RS256',
      'typ': 'JWT',
      if (credential.privateKeyId case final kid?) 'kid': kid,
    };
    final claims = {
      'iss': credential.clientEmail,
      'scope': scope,
      'aud': credential.tokenUri.toString(),
      'iat': iat,
      'exp': iat + lifetime.inSeconds,
    };
    final signingInput =
        '${_base64UrlJson(header)}.${_base64UrlJson(claims)}';
    final signer = RSASigner(SHA256Digest(), _sha256DigestInfoPrefix)
      ..init(true, PrivateKeyParameter<RSAPrivateKey>(_privateKey));
    final signature = signer.generateSignature(
      Uint8List.fromList(utf8.encode(signingInput)),
    );
    return '$signingInput.${_base64Url(signature.bytes)}';
  }
}

/// 支持 PKCS#8（服务账号 JSON 的格式）与 PKCS#1 两种 PEM。
RSAPrivateKey parseRsaPrivateKeyPem(String pem) {
  final normalized = pem.replaceAll(r'\n', '\n');
  final match = RegExp(
    r'-----BEGIN (RSA )?PRIVATE KEY-----([\s\S]*?)-----END (RSA )?PRIVATE KEY-----',
  ).firstMatch(normalized);
  if (match == null) {
    throw const VertexCredentialFormatException(
      'private_key is not a PEM encoded RSA key',
    );
  }
  final Uint8List der;
  try {
    der = base64Decode(match.group(2)!.replaceAll(RegExp(r'\s'), ''));
  } on FormatException {
    throw const VertexCredentialFormatException('private_key is not base64');
  }
  try {
    final pkcs1 = match.group(1) != null ? der : _unwrapPkcs8(der);
    return _parsePkcs1(pkcs1);
  } on VertexCredentialFormatException {
    rethrow;
  } on Object {
    throw const VertexCredentialFormatException(
      'private_key is not a valid RSA key',
    );
  }
}

Uint8List _unwrapPkcs8(Uint8List der) {
  final sequence = ASN1Parser(der).nextObject() as ASN1Sequence;
  final elements = sequence.elements!;
  final algorithm = (elements[1] as ASN1Sequence).elements!.first;
  final oid = (algorithm as ASN1ObjectIdentifier).objectIdentifierAsString;
  if (oid != '1.2.840.113549.1.1.1') {
    throw const VertexCredentialFormatException(
      'private_key is not an RSA key',
    );
  }
  return (elements[2] as ASN1OctetString).octets!;
}

RSAPrivateKey _parsePkcs1(Uint8List der) {
  final elements = (ASN1Parser(der).nextObject() as ASN1Sequence).elements!;
  BigInt integerAt(int index) => (elements[index] as ASN1Integer).integer!;
  return RSAPrivateKey(integerAt(1), integerAt(3), integerAt(4), integerAt(5));
}

String _base64UrlJson(Map<String, Object> value) =>
    _base64Url(utf8.encode(jsonEncode(value)));

String _base64Url(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');
