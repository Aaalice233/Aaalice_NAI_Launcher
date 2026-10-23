/// 安全存储暂时无法访问；调用方不得把它当作"没有数据"去补写或清理
class SecureStorageUnavailableException implements Exception {
  const SecureStorageUnavailableException(this.step, {this.osErrorCode});

  final SecureStorageStep step;
  final int? osErrorCode;

  // 不携带路径或原始异常文本：文件路径含系统用户名，会随日志导出外泄
  @override
  String toString() {
    final code = osErrorCode;
    final detail = code == null
        ? ''
        : ', os error 0x${code.toUnsigned(32).toRadixString(16)}';
    return 'SecureStorageUnavailableException(${step.name}$detail)';
  }
}

enum SecureStorageStep {
  readFile,
  writeFile,
  replaceFile,
  deleteFile,
  quarantineFile,
  encrypt,
  decrypt,
}
