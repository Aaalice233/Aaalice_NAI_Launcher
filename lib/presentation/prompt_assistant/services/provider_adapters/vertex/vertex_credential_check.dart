import 'vertex_credential.dart';
import 'vertex_jwt_assertion.dart';

/// 保存前的完整校验：在 [VertexCredential.parse] 之外再解析服务账号私钥。
VertexCredential checkVertexCredential(String raw) {
  final credential = VertexCredential.parse(raw);
  if (credential is VertexServiceAccountCredential) {
    parseRsaPrivateKeyPem(credential.privateKeyPem);
  }
  return credential;
}
