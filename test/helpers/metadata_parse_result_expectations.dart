import 'package:flutter_test/flutter_test.dart';
import 'package:nai_launcher/data/services/metadata/unified_metadata_parser.dart';

/// 断言两次解析的结果字段一致；parseTime 每次都不同，不参与比较。
void expectSameParseResult(
  MetadataParseResult? actual,
  MetadataParseResult expected,
) {
  expect(actual, isNotNull);
  expect(actual!.success, expected.success);
  expect(actual.sourceFormat, expected.sourceFormat);
  expect(actual.rawData, expected.rawData);
  expect(actual.triedParsers, expected.triedParsers);
  expect(actual.errorMessage, expected.errorMessage);
  expect(actual.metadata, expected.metadata);
  expect(actual.bytesRead, expected.bytesRead);
}
