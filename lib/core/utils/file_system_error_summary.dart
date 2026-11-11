import 'dart:io';

// 文件系统异常文本含本机路径，日志只保留类型与系统错误码。
String fileSystemErrorSummary(Object error) {
  if (error is! FileSystemException) return '${error.runtimeType}';
  final code = error.osError?.errorCode;
  if (code == null || code == OSError.noErrorCode) return 'FileSystemException';
  return 'FileSystemException(errno: $code)';
}
