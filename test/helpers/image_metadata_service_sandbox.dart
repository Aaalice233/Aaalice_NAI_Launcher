import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nai_launcher/data/services/image_metadata_service.dart';
import 'package:nai_launcher/data/services/metadata/metadata_parse_executor.dart';

class MockMetadataParseExecutor extends Mock implements MetadataParseExecutor {}

/// 每个用例在独立临时目录里初始化 [ImageMetadataService] 的 Hive 缓存，结束后恢复默认执行器并清空。
///
/// 返回的函数在 setUp 之后才能取到当前用例的目录。
Directory Function() useImageMetadataServiceSandbox() {
  late Directory directory;

  setUpAll(() => registerFallbackValue(Uint8List(0)));

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('metadata-service-');
    Hive.init(directory.path);
    await ImageMetadataService().initialize();
    ImageMetadataService().resetStatistics();
  });

  tearDown(() async {
    ImageMetadataService()
      ..debugSetParseExecutorForTesting(null)
      ..clearMemoryCache();
    await Hive.close();
    await directory.delete(recursive: true);
  });

  return () => directory;
}

/// 换上 mock 执行器；[useImageMetadataServiceSandbox] 的 tearDown 会换回默认执行器。
MockMetadataParseExecutor mockImageMetadataParseExecutor() {
  final executor = MockMetadataParseExecutor();
  ImageMetadataService().debugSetParseExecutorForTesting(executor);
  return executor;
}
