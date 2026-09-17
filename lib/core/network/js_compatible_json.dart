import 'dart:convert';

import 'package:dio/dio.dart';

/// JavaScript `Number` 保持整数精度的上界（2^53）。
const int _jsMaxSafeIntegerBound = 9007199254740992;

/// 按浏览器 `JSON.stringify` 的数值写法编码。
String encodeJsCompatibleJson(Object? value) =>
    jsonEncode(toJsCompatibleValue(value));

/// 把整数值的 double 换成 int，其余节点原样保留。
///
/// JS 没有整数/浮点之分，`1.0` 会写成 `1`；Dart 默认写成 `1.0`，请求体与官网
/// 逐字节比对时会差出这一位。
Object? toJsCompatibleValue(Object? value) {
  if (value is double) return _toJsNumber(value);
  if (value is Map) {
    final normalized = <Object?, Object?>{};
    value.forEach((key, item) => normalized[key] = toJsCompatibleValue(item));
    return normalized;
  }
  if (value is List) {
    return value.map(toJsCompatibleValue).toList(growable: false);
  }
  return value;
}

num _toJsNumber(double value) {
  if (!value.isFinite) return value;
  if (value != value.truncateToDouble()) return value;
  if (value.abs() >= _jsMaxSafeIntegerBound) return value;
  return value.toInt();
}

/// 让 Dio 的纯 JSON 请求体也走 [encodeJsCompatibleJson]。
class JsCompatibleJsonTransformer extends BackgroundTransformer {
  JsCompatibleJsonTransformer() {
    jsonEncodeCallback = encodeJsCompatibleJson;
  }
}
