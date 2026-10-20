import 'package:sqflite_common_ffi/sqflite_ffi.dart';

// sqflite 异常文本带 SQL 与全部参数，日志只留类型与 result code；
// 保留 DatabaseException 字样，data_source_cache_provider 按它判断重试。
String databaseErrorSummary(Object error) {
  if (error is! DatabaseException) return '${error.runtimeType}';
  return 'DatabaseException(resultCode: ${error.getResultCode()})';
}
