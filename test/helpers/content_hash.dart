import 'package:crypto/crypto.dart';

/// 图像内容哈希的期望值，与 FileHashCalculator 记录的 SHA-256 十六进制串一致。
String contentHashOf(List<int> bytes) => sha256.convert(bytes).toString();
